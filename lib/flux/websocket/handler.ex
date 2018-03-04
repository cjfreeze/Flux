defmodule Flux.Websocket.Handler do
  alias Flux.Websocket.{Frame, Conn}

  @type context :: {module, any}

  @callback init(Flux.Conn.t(), any) :: {:ok, any} | :error
  @callback handle_frame(Frame.opcode(), binary, Conn.t(), context) :: {:ok, Conn.t(), context}
  @callback handle_info(any, Conn.t(), context) :: {:ok, Conn.t(), context}
  @callback handle_terminate(atom, Conn.t(), context) :: {:ok, Conn.t(), context}
end
