defmodule Flux.HTTP do
  @moduledoc """
  Documentation for Flux.HTTP.
  """
  require Logger
  alias Flux.Conn
  alias Flux.HTTP.{Parser, Response, Chunked}
  @behaviour Flux.Pool.Handler

  def start_handling_process(pool, socket, transport, opts) do
    Flux.HTTP.start_link(pool, socket, transport, opts)
  end

  def start_link(pool, socket, transport, opts) do
    {:ok, spawn_link(__MODULE__, :init, [self(), pool, socket, transport, opts])}
  end

  def init(parent_pid, pool, socket, transport, opts) do
    pool.acknowlege()

    with {:ok, {ip, port} = peer} <- transport.peer_name(socket) do
      %Conn{
        parent: parent_pid,
        ref: nil,
        socket: socket,
        transport: transport,
        handler: {Keyword.get(opts, :handler), Keyword.get(opts, :handler_opts)},
        opts: opts,
        port: port,
        remote_ip: ip,
        peer: peer
      }
      |> handle_socket_once()
    else
      {:error, reason} ->
        # Likely not the correct transport (http trying to connect to https)
        {:error, reason}
    end
  end

  @doc false
  def handle_socket_once(%{transport: transport, socket: socket} = conn, state \\ nil) do
    transport.set_opts(socket, active: :once)
    {success, closed, error} = transport.messages()

    receive do
      {^success, socket, msg} ->
        handle_socket_message(msg, socket, conn, state)

      {^closed, _socket} ->
        :error

      {^error, _socket} ->
        :error

      other ->
        IO.inspect(other)
        :error
    end
  end

  defp handle_socket_message(data, _socket, conn, state) do
    conn
    |> do_parse(data, state)
    |> call_handler()
    |> case do
      %{keep_alive: true} = conn ->
        conn
        |> Conn.keep_alive_conn()
        |> handle_socket_once()

      {:incomplete, conn, acc} ->
        handle_socket_once(conn, acc)

      _conn ->
        :stop
    end
  end

  defp do_parse(conn, data, nil) do
    Parser.parse(conn, data)
  end

  defp do_parse(conn, data, acc) do
    Parser.parse(conn, data, acc)
  end

  defp call_handler({:incomplete, _, _} = state), do: state
  defp call_handler(%Conn{handler: {nil, _}} = conn), do: conn

  defp call_handler(%Conn{handler: {handler, opts}} = conn) do
    handler.handle_request(conn, opts)
  end

  defp call_handler(conn), do: conn

  @doc """
  Builds and sends an http response from the provided conn.
  Returns {:ok, sent_body, conn} if successful or :error if not.
  To manipulate what response is sent, manipulate the response fields
  of the conn.
  """
  @spec send_response(Flux.Conn.t(), integer, list, iodata) :: {:ok, iodata, Conn.t()} | :error
  def send_response(conn, status, headers, body) do
    with response = Response.response_iodata(conn, status, headers, body),
         :ok <- conn.transport.send(conn.socket, response) do
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
        status,
        headers,
        file,
        offset \\ 0,
        length \\ :all
      ) do
    with {:ok, %{size: size}} <- File.stat(file),
         response =
           Response.file_response_iodata(
             conn,
             status,
             headers,
             file_content_length(size, offset, length)
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

  @doc """
  This is my second time having to write this, thanks disk failures,
  and thanks me for forgetting to regularly git push. I hate everything.
  """
  def read_request_body(conn, length, read_length, read_timeout) do
    case conn.transfer_coding do
      "chunked" -> Chunked.read_chunked(conn, length, read_length, read_timeout)
      _ -> do_read_request_body(conn, length, read_length, read_timeout)
    end
  end

  def do_read_request_body(conn, length, read_length, read_timeout) do
    with {:ok, read_from_buffer, conn} <- read_buffer(conn, length),
         {:ok, read, conn} <-
           read_socket(conn, length, read_length, read_timeout, read_from_buffer) do
      {:ok, read, conn}
    else
      {:more, read, conn} ->
        {:more, read, conn}
    end
  end

  defp read_buffer(%{req_buffer: nil} = conn, _length), do: {:ok, "", conn}

  defp read_buffer(conn, length) do
    read_amount = if length > conn.content_length, do: conn.content_length, else: length
    {read, rest} = String.split_at(conn.req_buffer, read_amount)
    read_amount = byte_size(read)

    case byte_size(rest) do
      0 ->
        {:ok, read, %{conn | req_buffer: "", content_length: conn.content_length - read_amount}}

      _ ->
        {:more, read,
         %{conn | req_buffer: rest, content_length: conn.content_length - read_amount}}
    end
  end

  defp read_socket(%{content_length: cl} = conn, 0, _rl, _rt, buffer) when cl > 0,
    do: {:more, buffer, conn}

  defp read_socket(%{content_length: 0} = conn, _length, _rl, _rt, buffer),
    do: {:ok, buffer, conn}

  defp read_socket(%{content_length: cl} = conn, length, read_length, read_timeout, buffer) do
    read_amount = determine_read_amount(cl, length, read_length)
    new_buffer = buffer <> conn.transport.read(conn.socket, read_amount, read_timeout)
    new_conn = %{conn | content_length: cl - read_amount}

    read_socket(
      new_conn,
      length - read_amount,
      read_length,
      read_timeout,
      new_buffer
    )
  end

  defp determine_read_amount(content_length, length, read_length) do
    [content_length, length, read_length] |> Enum.min()
  end
end
