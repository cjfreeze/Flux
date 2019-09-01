defmodule Flux.Conn do
  alias Flux.Conn

  defstruct parent: nil,
            ref: nil,
            socket: nil,
            transport: nil,
            handler: nil,
            opts: [],
            method: nil,
            status: 200,
            version: nil,
            uri: nil,
            query: nil,
            port: nil,
            host: nil,
            peer: nil,
            remote_ip: nil,
            req_headers: [],
            req_buffer: nil,
            keep_alive: false,
            resp_headers: [],
            resp_body: nil,
            request: nil,
            accept_encoding: %{},
            accept: %{},
            accept_charset: %{},
            accept_language: %{},
            upgrade: nil,
            transfer_coding: nil,
            content_length: nil,
            resp_type: :normal,
            private: %{}

  @typedoc "The state of a connection."
  @type t :: %__MODULE__{
          parent: pid,
          ref: identifier,
          socket: pid,
          transport: atom,
          handler: atom,
          opts: keyword,
          method: atom,
          status: integer,
          version: atom,
          uri: iodata,
          port: integer,
          host: binary,
          peer: {binary, integer},
          remote_ip: binary,
          req_headers: keyword,
          keep_alive: boolean,
          resp_headers: [{iodata, iodata}],
          resp_body: iodata,
          request: iodata,
          req_buffer: iodata,
          accept_encoding: %{coding => qvalue},
          accept: %{mimetype => qvalue},
          accept_charset: %{charset => qvalue},
          accept_language: %{language => qvalue},
          upgrade: atom,
          transfer_coding: atom,
          content_length: integer,
          resp_type: atom,
          private: map
        }

  @type coding :: binary
  @type mimetype :: binary
  @type charset :: binary
  @type language :: binary
  @type qvalue :: float

  # TODO better status validation
  def put_status(%Flux.Conn{} = conn, status)
      when is_integer(status) and status >= 100 and status < 600 do
    %{conn | status: status}
  end

  def put_resp_headers(%Flux.Conn{} = conn, headers) do
    %{conn | resp_headers: headers ++ conn.resp_headers}
  end

  def put_resp_header(%Flux.Conn{} = conn, header) do
    %{conn | resp_headers: [header | conn.resp_headers]}
  end

  def put_resp_body(%Flux.Conn{} = conn, body) when is_list(body) or is_binary(body) do
    %{conn | resp_body: body}
  end

  @doc false
  def keep_alive_conn(%Flux.Conn{} = conn) do
    %__MODULE__{
      parent: conn.parent,
      ref: conn.ref,
      socket: conn.socket,
      transport: conn.transport,
      opts: conn.opts,
      port: conn.port,
      remote_ip: conn.remote_ip,
      peer: conn.peer,
      keep_alive: conn.keep_alive
    }
  end

  @default_read_opts %{
    length: 8_000_000,
    read_length: 1_000_000,
    read_timeout: 15_000
  }

  def read_body(%Flux.Conn{req_buffer: body} = conn, opts) do
    body
    |> do_read_body(Enum.into(opts, @default_read_opts))
    |> return_read_body(conn)
  end

  defp do_read_body("", _), do: {"", ""}

  defp do_read_body(body, %{read_length: read_length, length: length}) do
    read_amount = if read_length < length, do: read_length, else: length
    String.split_at(body, read_amount)
  end

  defp do_read_body(_, _), do: :error

  defp return_read_body({body, ""}, conn), do: {:ok, body, conn}
  defp return_read_body({body, rest}, conn), do: {:more, body, %{conn | req_body: rest}}
  defp return_read_body(:error, conn), do: {:error, conn}

  def put_private(%Conn{private: private} = conn, key, val) do
    %{conn | private: Map.put(private, key, val)}
  end

  def get_private(%Conn{private: private}, key) do
    Map.get(private, key)
  end
end
