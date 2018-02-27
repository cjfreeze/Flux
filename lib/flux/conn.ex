defmodule Flux.Conn do
  defstruct parent: nil,
            ref: nil,
            socket: nil,
            transport: nil,
            opts: [],
            method: nil,
            status: 200,
            version: nil,
            uri: nil,
            port: nil,
            host: nil,
            peer: nil,
            remote_ip: nil,
            req_headers: [],
            req_body: nil,
            keep_alive: false,
            resp_headers: [],
            resp_body: nil,
            request: nil,
            accept_encoding: %{},
            accept: %{},
            accept_charset: %{},
            accept_language: %{},
            upgrade: nil,
            resp_type: :normal

  @typedoc "The state of a connection."
  @type t :: %__MODULE__{
          parent: pid,
          ref: identifier,
          socket: pid,
          transport: atom,
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
          req_body: iodata,
          accept_encoding: %{coding => qvalue},
          accept: %{mimetype => qvalue},
          accept_charset: %{charset => qvalue},
          accept_language: %{language => qvalue},
          upgrade: atom,
          resp_type: atom
        }

  @type coding :: binary
  @type mimetype :: binary
  @type charset :: binary
  @type language :: binary
  @type qvalue :: float

  def keep_alive_conn(conn) do
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
end
