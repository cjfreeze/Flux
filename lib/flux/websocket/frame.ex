defmodule Flux.Websocket.Frame do
  defstruct fin: false,
            reserved: %{},
            opcode: nil,
            mask?: false,
            payload_length: nil,
            mask: nil,
            payload: nil
  
  opcodes = [
    continue: 0x0,
    text: 0x1,
    binary: 0x2,
    close: 0x8,
    ping: 0x9,
    pong: 0xA
  ]

  for {atom, code} <- opcodes do
    def opcode_to_atom(unquote(code)), do: unquote(atom)
  end

  def opcode_to_atom(code) when code in 0x3..0x7 or code in 0xB..0xF, do: :reserved
  def opcode_to_atom(_), do: :error

  for {atom, code} <- opcodes do
    def opcode_from_atom(unquote(atom)), do: unquote(code)
  end
  def opcode_from_atom(_), do: :error
end