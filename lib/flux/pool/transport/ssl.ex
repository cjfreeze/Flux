defmodule Flux.Pool.Transport.SSL do
  # import Kernel, except: [send: 2]
  alias Flux.Pool.Transport
  alias Flux.Pool.Transport.SSL

  @behaviour Transport
  @default_chunk_size 8_191

  def listen(port, opts) do
    :ssl.start()
    keyfile = Keyword.fetch!(opts, :keyfile)
    certfile = Keyword.fetch!(opts, :certfile)
    File.exists?(keyfile) || raise "Keyfile does not exist"
    File.exists?(certfile) || raise "Certfile does not exist"

    opts = [
      :binary,
      keyfile: keyfile,
      certfile: certfile,
      ciphers: :ssl.cipher_suites(),
      active: false,
      packet: :raw,
      reuseaddr: true,
      backlog: 1024,
      nodelay: true
    ]

    :ssl.listen(port, opts)
  end

  def accept(socket, timeout) do
    :ssl.transport_accept(socket, timeout)
  end

  def acknowlege(socket, timeout) do
    :ssl.handshake(socket, timeout)
  end

  def send(socket, payload) do
    :ssl.send(socket, payload)
  end

  def send_file(socket, file) do
    send_file(file, socket, 0, :all, [])
  end

  def send_file(socket, file, offset, length, opts) do
    with {:ok, fd} <- File.open(file, [:raw, :read, :binary]),
         {:ok, ^offset} <- offset_file(fd, offset) do
      do_send_file(fd, socket, 0, length, opts)
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp offset_file(_, 0), do: {:ok, 0}
  defp offset_file(fd, offset), do: :file.position(fd, offset)

  defp do_send_file(fd, _socket, read, length, _opts) when read >= length, do: File.close(fd)

  defp do_send_file(fd, socket, read, length, opts) do
    chunk_size =
      if read + @default_chunk_size > length,
        do: length - read,
        else: @default_chunk_size

    fd
    |> :file.read(chunk_size)
    |> case do
      {:ok, chunk} ->
        SSL.send(socket, chunk)
        do_send_file(fd, socket, read + chunk_size, length, opts)

      :eof ->
        File.close(fd)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read(socket, length, timeout \\ 15_000) do
    :ssl.recv(socket, length, timeout)
  end

  def set_opts(socket, opts) do
    :ssl.setopts(socket, opts)
  end

  def controlling_process(socket, pid) do
    :ssl.controlling_process(socket, pid)
  end

  def messages, do: {:ssl, :ssl_closed, :ssl_error}

  def peer_name(socket), do: :ssl.peername(socket)
end
