defmodule Flux.Websocket.Conn do
  defstruct parent: nil,
            ref: nil,
            socket: nil,
            transport: nil,
            opts: [],
            status: 200,
            version: nil,
            uri: nil,
            port: nil,
            host: nil,
            peer: nil,
            remote_ip: nil,
            ws_accept: nil,
            ws_protocol: nil,
            fin: false,
            reserved: %{},
            opcode: nil,
            mask?: false,
            payload_length: nil,
            mask: nil,
            payload: nil,
            frame: nil

  @typedoc "The state of a connection."
  @type t :: %__MODULE__{
          parent: pid,
          ref: identifier,
          socket: pid,
          transport: atom,
          opts: keyword,
          status: integer,
          version: atom,
          uri: iodata,
          port: integer,
          host: binary,
          peer: {binary, integer},
          remote_ip: binary,
          ws_accept: iodata,
          ws_protocol: iodata,
          fin: boolean,
          reserved: map,
          opcode: atom,
          mask?: boolean,
          payload_length: non_neg_integer,
          mask: non_neg_integer,
          payload: bitstring,
          frame: bitstring
        }

  @type coding :: binary
  @type mimetype :: binary
  @type charset :: binary
  @type language :: binary
  @type qvalue :: float
end
