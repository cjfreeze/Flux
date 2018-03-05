defmodule Flux.Websocket.Frame do
  @moduledoc """
  Convenience functions for building websocket frames.
  """
  defstruct fin: false,
            reserved: %{},
            opcode: nil,
            mask?: false,
            payload_length: nil,
            mask: nil,
            payload: nil,
            close_code: nil

  opcodes = [
    continue: 0x0,
    text: 0x1,
    binary: 0x2,
    close: 0x8,
    ping: 0x9,
    pong: 0xA
  ]

  @typedoc """
  A parsed frame recieved from a client.
  """
  @type t :: %__MODULE__{
          fin: boolean,
          reserved: map,
          opcode: atom,
          mask?: boolean,
          payload_length: non_neg_integer,
          mask: integer,
          payload: binary | iodata,
          close_code: pos_integer | nil
        }

  @typedoc """
  Atom representations of the various opcodes that are available when building a websocket frame.
  """
  @type opcode :: :continue | :text | :binary | :close | :ping | :pong

  @doc """
  Builds a server websocket frame with the given opcode and payload.
  Supports binaries and iodata as payloads.
  Because this is a server frame, it does NOT mask the payload.
  """
  @spec build_frame(opcode, iodata | binary) :: iodata
  def build_frame(type, payload) do
    [
      frame_header(type, payload),
      payload
    ]
  end

  defp frame_header(type, payload) do
    <<
      1::1,
      0::1,
      0::1,
      0::1,
      opcode_from_atom(type)::4,
      0::1,
      payload_length(payload)::bitstring
    >>
  end

  defp payload_length(payload) when is_list(payload) do
    len = IO.iodata_length(payload)
    len_size = integer_bit_size(len)
    do_payload_length(len, len_size)
  end

  defp payload_length(payload) do
    len = byte_size(payload)
    len_size = integer_bit_size(len)
    do_payload_length(len, len_size)
  end

  defp do_payload_length(len, len_size) when len_size > 16 do
    <<127::7, len::64>>
  end

  defp do_payload_length(len, len_size) when len_size > 7 do
    <<126::7, len::16>>
  end

  defp do_payload_length(len, _) do
    <<len::7>>
  end

  defp integer_bit_size(int) when int > 0 do
    :math.log2(int)
  end

  defp integer_bit_size(_), do: 1

  @doc """
  Gives the corresponding atomic representation of an opcode
  For example:
  ```
  iex(1)> opcode_to_atom(1)
  :text
  ```
  """
  @spec opcode_to_atom(non_neg_integer) :: opcode
  for {atom, code} <- opcodes do
    def opcode_to_atom(unquote(code)), do: unquote(atom)
  end

  def opcode_to_atom(code) when code in 0x3..0x7 or code in 0xB..0xF, do: :reserved
  def opcode_to_atom(_), do: :error

  @doc """
  Gives the integer that an opcode atom represents
  For example:
  ```
  iex(1)> opcode_from_atom(:text)
  1
  ```
  """
  @spec opcode_from_atom(opcode) :: non_neg_integer
  for {atom, code} <- opcodes do
    def opcode_from_atom(unquote(atom)), do: unquote(code)
  end

  def opcode_from_atom(_), do: :error
end
