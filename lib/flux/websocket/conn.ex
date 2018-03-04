defmodule Flux.Websocket.Conn do
  defstruct parent: nil,
            ref: nil,
            socket: nil,
            transport: nil,
            opts: [],
            uri: nil,
            port: nil,
            host: nil,
            peer: nil,
            remote_ip: nil,
            ws_accept: nil,
            ws_protocol: nil

  @typedoc "The state of a connection."
  @type t :: %__MODULE__{
          parent: pid,
          ref: identifier,
          socket: pid,
          transport: atom,
          opts: keyword,
          uri: iodata,
          port: integer,
          host: binary,
          peer: {binary, integer},
          remote_ip: binary,
          ws_accept: iodata,
          ws_protocol: iodata
        }
end
