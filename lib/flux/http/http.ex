defmodule Flux.HTTP do
  @moduledoc """
  Documentation for Flux.HTTP.
  """
  require Logger
  alias Flux.Conn
  alias Flux.HTTP.{Parser, Response}

  @spec init(pid, identifier, pid, atom, keyword) :: atom
  def init(parent_pid, ref, socket, transport, opts) do
    {:ok, {ip, port} = peer} = :inet.peername(socket)
    IO.inspect(transport)

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

  @doc false
  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn) do
    transport.setopts(socket, active: :once)
    {success, _, _} = conn.transport.messages()

    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn)

      {:tcp_closed, _socket} ->
        :stop

      other ->
        IO.inspect(other)
    end
    |> receive_loop()
  end

  defp handle_in({_socket, data}, conn) do
    conn
    |> Parser.parse(data)
    |> call_endpoint()
    |> return()
  end

  defp handle_in(msg, conn) do
    Logger.warn("Unhandled in: #{msg}")
    conn
  end

  @adapter Application.get_env(:flux, :plug_adapter, nil)

  defp call_endpoint(%Conn{opts: %{endpoint: nil}} = conn), do: conn

  if @adapter do
    defp call_endpoint(%Conn{opts: %{endpoint: endpoint}} = conn) do
      @adapter.upgrade(conn, endpoint)
    end
  end

  defp call_endpoint(conn), do: conn

  defp return({:ok, _, %{keep_alive: true} = conn}), do: Conn.keep_alive_conn(conn)

  defp return(_), do: :stop

  @doc """
  Builds and sends an http response from the provided conn.
  Returns {:ok, sent_body, conn} if successful or :error if not.
  To manipulate what response is sent, manipulate the response fields
  of the conn.
  """
  @spec send_response(Flux.Conn.t()) :: {:ok, iodata, Conn.t()} | :error
  def send_response(conn) do
    with response = Response.build(conn), :ok <- :gen_tcp.send(conn.socket, response) do
      {:ok, conn.resp_body, conn}
    end
  end

  @doc """
  A convenience shortcut to send_response/1 that allows
  the caller to provide a path to a file and some options.
  Uses the Flux.File module to read the file. For more information,
  see send_response/1.
  """
  @spec send_file(Flux.Conn.t(), Path.t(), non_neg_integer, non_neg_integer | :all) ::
          {:ok, iodata, Conn.t()} | :error
  def send_file(conn, file, offset \\ 0, length \\ :all) do
    with {:ok, content} <- Flux.File.read_file(file, offset, length) do
      conn
      |> Conn.put_resp_body(content)
      |> send_response()
    end
  end
end
