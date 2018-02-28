defmodule Flux.Websocket.Opcode do
  opcodes = [
    continue: 0x0,
    text: 0x1,
    binary: 0x2,
    close: 0x8,
    ping: 0x9,
    pong: 0xA
  ]

  for {atom, code} <- opcodes do
    def to_atom(unquote(code)), do: unquote(atom)
  end

  def to_atom(code) when code in 0x3..0x7 or code in 0xB..0xF, do: :reserved
  def to_atom(_), do: :error

  for {atom, code} <- opcodes do
    def from_atom(unquote(atom)), do: unquote(code)
  end
  def from_atom(_), do: :error
end
