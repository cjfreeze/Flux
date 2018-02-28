defmodule Flux.Websocket do
  require Logger
  alias Flux.Websocket.{Conn, Sec, Parser, Opcode, Response}
  alias Flux.HTTP.Response, as: HTTPResponse

  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn) do
    transport.setopts(socket, active: :once)
    {success, _, _} = conn.transport.messages()
    IO.puts("\n\nwaiting for websocket requests\n\n")
    Agent.update(__MODULE__, fn _ -> socket end)
    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn)
    end
    |> receive_loop()
  end

  defp handle_in({_socket, data}, conn) do
    conn
    |> Parser.parse(data)
    |> dispatch()
  end

  defp handle_in(msg, conn) do
    Logger.warn("Unhandled websocket in: #{msg}")
    conn
  end

  defp dispatch(%{opcode: unquote(Opcode.from_atom(:ping))} = conn) do
    Logger.info("Received ping")
    conn
    |> Response.build_pong_frame()
    |> Response.send()
  end

  defp dispatch(%{opcode: unquote(Opcode.from_atom(:pong))} = conn) do
    Logger.info("Received pong")
    conn
  end

  def upgrade(conn) do
    Agent.start_link(fn -> conn.socket end, name: __MODULE__)
    struct(Conn, Map.from_struct(conn))
    |> Map.put(:ws_protocol, get_ws_protocol(conn))
    |> Sec.sign(conn)
    |> handshake(conn)
    |> receive_loop()
  end

  defp get_ws_protocol(%{req_headers: req_headers}),
    do: List.keyfind(req_headers, "sec-websocket-protocol", 0, "")

  def handshake(conn, http_conn) do
    http_conn
    |> put_handshake_headers(conn)
    |> Map.put(:status, 101)
    |> Map.put(:resp_type, :raw)
    |> HTTPResponse.build()
    |> HTTPResponse.send_response(http_conn)

    receive do
      other ->
        IO.inspect(other, label: "flush")
        :ok
    after
      0 -> :ok
    end

    conn
  end

  defp put_handshake_headers(%{resp_headers: resp_headers} = http_conn, conn) do
    headers = [
      {"sec-websocket-accept", conn.ws_accept},
      {"connection", "upgrade"},
      {"upgrade", "websocket"} | resp_headers
    ]

    %{http_conn | resp_headers: headers}
  end
end
