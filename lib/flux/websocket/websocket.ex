defmodule Flux.Websocket do
  require Logger
  alias Flux.Websocket
  alias Flux.Websocket.{Sec, Parser, Response}
  alias Flux.HTTP.Response, as: HTTPResponse

  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn, {handler, state}) do
    transport.setopts(socket, active: :once)
    {success, _, _} = conn.transport.messages()
    Agent.update(__MODULE__, fn _ -> socket end)
    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn, {handler, state})
      info ->
        handler.handle_info(info, conn, state)
      # TODO detect remote close and invoke handler.terminate
    end
    |> return(handler)
  end

  defp handle_in({_socket, data}, conn, {handler, state}) do
    data
    |> Parser.parse()
    |> dispatch(conn, {handler, state})
  end

  defp dispatch(%{opcode: :ping}, conn, {handler, state}) do
    Logger.info("Received ping")
    conn
    |> Response.build_pong_frame()
    |> Response.send()
    {:ok, conn, {handler, state}}
  end

  defp dispatch(%{opcode: :pong}, conn, {handler, state}) do
    Logger.info("Received pong")
    {:ok, conn, {handler, state}}
  end

  defp dispatch(%{payload: payload, opcode: opcode}, conn, {handler, state}) do
    Logger.info("Recieved payload #{inspect payload}")
    handler.handle_frame(opcode, payload, conn, state)
  end

  defp return({:ok, conn, state}, handler) do
    receive_loop(conn, {handler, state})
  end

  defp return(_, _) do
    # terminate() # TODO
    :stop
  end

  def upgrade(%Flux.Conn{} = http_conn, handler, args) do
    Agent.start_link(fn -> http_conn.socket end, name: __MODULE__)
    # TODO Figure out what I was thinking here
    case handler.init(http_conn, args) do
      {:ok, state} -> do_upgrade(http_conn, {handler, state})
      :error -> fail(http_conn)
    end
  end

  defp do_upgrade(http_conn, {handler, state}) do
    struct(Websocket.Conn, Map.from_struct(http_conn))
    |> Map.put(:ws_protocol, get_ws_protocol(http_conn))
    |> Sec.sign(http_conn)
    |> handshake(http_conn)
    |> receive_loop({handler, state})
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
        :ok
    after
      0 -> :ok
    end

    conn
  end

  def fail(http_conn) do
    http_conn
    |> Map.put(:status, 403)
    |> Map.put(:resp_type, :raw)
    |> HTTPResponse.build()
    |> HTTPResponse.send_response(http_conn)
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
