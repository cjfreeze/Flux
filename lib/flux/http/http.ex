defmodule Flux.HTTP do
  @moduledoc """
  Documentation for Flux.HTTP.
  """
  require Logger
  alias Flux.Conn
  alias Flux.HTTP.{Parser, Response}

  @spec init(pid, identifier, pid, atom, keyword) :: atom
  def init(parent_pid, ref, socket, transport, opts) do
    with {:ok, {ip, port} = peer} <- transport.peer_name(socket) do
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
    else
      {:error, reason} ->
        # Likely not the correct transport (http trying to connect to https)
        # transport.send(socket, "500 Internal Server Error HTTP/1.1\r\n")
        {:error, reason}
    end
  end

  @doc false
  def receive_loop(:stop), do: :ok

  def receive_loop(%{transport: transport, socket: socket} = conn) do
    transport.set_opts(socket, active: :once)
    {success, closed, error} = transport.messages()

    receive do
      {^success, socket, msg} ->
        {socket, msg}
        |> handle_in(conn)

      {^closed, _socket} ->
        :stop

      {^error, _socket} ->
        :stop

      other ->
        IO.inspect(other)
    end
    |> receive_loop()
  end

  defp handle_in({_socket, data}, conn) do
    conn
    |> Parser.parse(data)
    |> call_handler()
    |> return()
  end

  defp handle_in(msg, conn) do
    Logger.warn("Unhandled in: #{msg}")
    conn
  end

  defp call_handler(%Conn{opts: %{handler: nil}} = conn), do: conn

  defp call_handler(%Conn{opts: %{handler: handler, endpoint: endpoint}} = conn) do
    handler.init(conn, endpoint)
  end

  defp call_handler(conn), do: conn

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
    with response = Response.build(conn), :ok <- conn.transport.send(conn.socket, response) do
      {:ok, nil, conn}
    else
      _ -> raise "error in send response"
    end
  end

  @doc """
  A convenience shortcut to send_response/1 that allows
  the caller to provide a path to a file and some options.
  Uses the Flux.File module to read the file. For more information,
  see send_response/1.
  """
  @spec send_file(Flux.Conn.t(), Path.t(), non_neg_integer, non_neg_integer | :all) ::
          {:ok, nil, Conn.t()} | :error
  def send_file(
        %Flux.Conn{transport: transport, socket: socket} = conn,
        file,
        offset \\ 0,
        length \\ :all
      ) do
    with {:ok, %{size: size}} <- File.stat(file),
         response =
           Response.file_response(
             conn.status,
             conn.version,
             file_content_length(size, offset, length),
             conn.resp_headers,
             conn.method
           ),
         :ok <- conn.transport.send(conn.socket, response),
         :ok <- transport.send_file(socket, file, offset, length, []) do
      {:ok, nil, conn}
    else
      {:error, reason} -> raise "Error in Flux.HTTP.send_file with reason #{reason}."
    end
  end

  defp file_content_length(size, offset, :all), do: size - offset
  defp file_content_length(_size, _offset, length), do: length
end
