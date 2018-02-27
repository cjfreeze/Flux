defmodule Flux.Websocket.Parser do
  import Bitwise
  def parse(conn, data) do
    IO.inspect data
    conn
    |> Map.put(:data, data)
    |> parse_frame()
    |> parse_extended_payload_length()
    |> parse_masking_key()
    |> parse_payload()
  end

  defp parse_frame(%{data: <<fin::1, rsv1::1, rsv2::1, rsv3::1, opcode::4, mask::1, payload_len::7, rest::bitstring>>} = conn) do
    reserved = %{
      rsv1: rsv1,
      rsv2: rsv2,
      rsv3: rsv3
    }
    %{conn | fin: fin == 1, reserved: reserved, opcode: opcode, mask?: mask == 1, payload_length: payload_len, data: rest}    
  end

  defp parse_extended_payload_length(%{payload_length: 126, data: <<ext_payload_len::16, rest :: bitstring>>} = conn) do
    %{conn | payload_length: ext_payload_len, data: rest}
  end

  defp parse_extended_payload_length(%{payload_length: 127, data: <<ext_payload_len::64, rest :: bitstring>>} = conn) do
    %{conn | payload_length: ext_payload_len, data: rest}
  end

  defp parse_extended_payload_length(conn), do: conn

  defp parse_masking_key(%{mask?: false} = conn), do: conn
  defp parse_masking_key(%{mask?: true, data: <<mask::32, rest :: bitstring>>} = conn) do
    %{conn | mask: mask, data: rest}
  end

  defp parse_payload(%{payload_length: payload_length, data: data, mask: mask} = conn) do
    len = payload_length * 8
    <<payload::size(len), _rest :: bitstring>> = data
    payload = if conn.mask?, do: decode_payload(<<payload::size(len)>>, mask), else: payload
    %{conn | payload: payload, data: data}
  end

  def decode_payload(payload, mask) do
    do_decode_payload(payload, divide_mask(<<mask::32>>))
  end

  defp divide_mask(<<octet_0::8, octet_1::8, octet_2::8, octet_3::8>>) do
    {octet_0, octet_1, octet_2, octet_3}
  end

  defp do_decode_payload(<<octet::8, rest::bitstring>>, mask, index \\ 0, buffer \\ <<>>) do
    mask_octet = elem(mask, rem(index, 4))
    decoded = octet ^^^ mask_octet
    do_decode_payload(rest, mask, index + 1, <<buffer::bitstring, decoded::8>>)
  end
  defp do_decode_payload(_, _, _, result), do: result
end