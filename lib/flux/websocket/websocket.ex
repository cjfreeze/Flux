defmodule Flux.Websocket do
  @moduledoc """
  An implementation of the websocket server protocol defined in IETF RFC6455.
  """
  require Logger
  alias Flux.Websocket
  alias Flux.Websocket.{Frame, Sec, Parser}
  alias Flux.HTTP

  @doc false
  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn, {handler, state}) do
    transport.setopts(socket, active: :once)
    {success, _, _} = conn.transport.messages()

    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn, {handler, state})

      {:tcp_closed, _socket} ->
        {:terminate, conn, state}

      info ->
        Logger.warn("Unmatched message #{inspect(info)}")
        handle_info(info, conn, {handler, state})
    end
    |> return(handler)
  end

  defp handle_in({_socket, data}, conn, {handler, state}) do
    data
    |> Parser.parse()
    |> dispatch(conn, {handler, state})
  end

  defp handle_in(other, conn, {_handler, state}) do
    Logger.info("Recieved unmatched socket message #{inspect(other)}")
    {:ok, conn, state}
  end

  defp handle_info(info, conn, {handler, state}) do
    handler.handle_info(info, conn, state)
    {:ok, conn, state}
  end

  defp dispatch(%{opcode: :close}, conn, {handler, state}) do
    handler.handle_terminate({:remote, :close}, conn, state)
    :stop
  end

  defp dispatch(%{opcode: :ping}, conn, {handler, state}) do
    Logger.info("Received ping")

    send_frame(conn, Frame.build_frame(:pong, ""))

    {:ok, conn, {handler, state}}
  end

  defp dispatch(%{opcode: :pong}, conn, {handler, state}) do
    Logger.info("Received pong")
    {:ok, conn, {handler, state}}
  end

  defp dispatch(%{payload: payload, opcode: opcode}, conn, {handler, state}) do
    Logger.info("Recieved payload #{inspect(payload)}")
    handler.handle_frame(opcode, payload, conn, state)
  end

  defp return({:ok, conn, state}, handler) do
    receive_loop(conn, {handler, state})
  end

  defp return({:terminate, conn, state}, handler) do
    Logger.warn("Terminating due to unexpected close")
    handler.handle_terminate({:error, :closed}, conn, state)
    :stop
  end

  defp return(_, _) do
    :stop
  end

  @doc """
  Upgrades a flux http connection with the proper websocket upgrade request to
  a websocket connection. Requires a Flux.Conn as the first argument,
  a module that implements the behavior Flux.Websocket.Handler as the second
  arguemnt, and accepts any arbitrary data to be passed to the handler's
  init/2 function as the third argument. If successful, this function will hijack
  the process that called it for the line of the websocket connection.
  """
  @spec upgrade(Flux.Conn.t(), module, any) :: :ok | :error
  def upgrade(%Flux.Conn{upgrade: :websocket} = http_conn, handler, args) do
    case handler.init(http_conn, args) do
      {:ok, state} -> do_upgrade(http_conn, {handler, state})
      :error -> fail(http_conn)
    end
  end

  def upgrade(_conn, _handler, _args), do: :error

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
    |> HTTP.send_response()

    conn
  end

  defp fail(http_conn) do
    http_conn
    |> Map.put(:status, 403)
    |> Map.put(:resp_type, :raw)
    |> HTTP.send_response()
  end

  defp put_handshake_headers(%{resp_headers: resp_headers} = http_conn, conn) do
    headers = [
      {"sec-websocket-accept", conn.ws_accept},
      {"connection", "upgrade"},
      {"upgrade", "websocket"} | resp_headers
    ]

    %{http_conn | resp_headers: headers}
  end

  @doc """
  Sends a frame through the given connection. Returns the provided conn if successful.
  """
  @spec send_frame(Conn.t(), iodata) :: Conn.t()
  def send_frame(conn, frame) do
    case conn.transport.send(conn.socket, frame) do
      {:tcp_closed, socket} ->
        send(conn.pid, {:tcp_closed, socket})

      _ ->
        :ok
    end

    conn
  end
end
