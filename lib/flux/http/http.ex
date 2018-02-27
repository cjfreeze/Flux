defmodule Flux.HTTP do
  @moduledoc """
  Documentation for Flux.HTTP.
  """
  require Logger
  alias Flux.Conn
  alias Flux.HTTP.Parser
  alias Flux.Websocket

  @spec init(pid, identifier, pid, atom, keyword) :: atom
  def init(parent_pid, ref, socket, transport, opts) do
    {:ok, {ip, port} = peer} = :inet.peername(socket)

    %Conn{
      parent: parent_pid,
      ref: ref,
      socket: socket,
      transport: transport,
      opts: opts,
      port: port,
      remote_ip: ip,
      peer: peer
    }
    |> receive_loop()
  end

  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn) do
    transport.setopts(socket, active: :once)
    {success, _, _} = conn.transport.messages()

    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn)
      other -> IO.inspect other
    end
    |> receive_loop()
  end

  defp handle_in({_socket, data}, conn) do
    conn
    |> Parser.parse(data)
    |> maybe_upgrade()
    |> call_endpoint()
    |> return()
  end

  defp handle_in(msg, conn) do
    Logger.warn("Unhandled in: #{msg}")
    conn
  end

  defp maybe_upgrade(%Conn{upgrade: :websocket} = conn), do: Websocket.upgrade(conn)

  defp maybe_upgrade(conn), do: conn

  defp call_endpoint(%Conn{opts: %{endpoint: nil}} = conn), do: conn
  defp call_endpoint(%Conn{opts: %{endpoint: endpoint}} = conn) do
    Flux.Adapters.Plug.upgrade(conn, endpoint)
  end

  defp call_endpoint(conn), do: conn

  defp return({:ok, _, %{keep_alive: true} = conn}), do: Conn.keep_alive_conn(conn)

  defp return(_), do: :stop
end
