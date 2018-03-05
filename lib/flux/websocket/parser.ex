defmodule Flux.Websocket.Parser do
  import Bitwise

  alias Flux.Websocket.Frame

  def parse(data) do
    # TODO add support for partial frames
    %Frame{}
    |> Map.put(:data, data)
    |> parse_frame()
    |> parse_extended_payload_length()
    |> parse_masking_key()
    |> parse_payload()
    |> maybe_parse_close_code()
    |> Map.delete(data: data)
  end

  defp parse_frame(
         %{
           data:
             <<fin::1, rsv1::1, rsv2::1, rsv3::1, opcode::4, mask::1, payload_len::7,
               rest::bitstring>>
         } = frame
       ) do
    reserved = %{
      rsv1: rsv1,
      rsv2: rsv2,
      rsv3: rsv3
    }

    %{
      frame
      | fin: fin == 1,
        reserved: reserved,
        opcode: Frame.opcode_to_atom(opcode),
        mask?: mask == 1,
        payload_length: payload_len,
        data: rest
    }
  end

  defp parse_extended_payload_length(
         %{payload_length: 126, data: <<ext_payload_len::16, rest::bitstring>>} = frame
       ) do
    %{frame | payload_length: ext_payload_len, data: rest}
  end

  defp parse_extended_payload_length(
         %{payload_length: 127, data: <<ext_payload_len::64, rest::bitstring>>} = frame
       ) do
    %{frame | payload_length: ext_payload_len, data: rest}
  end

  defp parse_extended_payload_length(frame), do: frame

  defp parse_masking_key(%{mask?: false} = frame), do: frame

  defp parse_masking_key(%{mask?: true, data: <<mask::32, rest::bitstring>>} = frame) do
    %{frame | mask: mask, data: rest}
  end

  defp parse_payload(%{payload_length: payload_length, data: data, mask: mask} = frame) do
    payload = do_parse_payload(data, divide_mask(<<mask::32>>), payload_length, 0, "")
    %{frame | payload: payload, data: data}
  end

  def do_parse_payload(_, _, length_and_index, length_and_index, buffer), do: buffer

  def do_parse_payload(<<octet::8, rest::bitstring>>, mask, length, index, buffer) do
    decoded_octet = decode_octet(octet, mask, index)
    do_parse_payload(rest, mask, length, index + 1, <<buffer::bitstring, decoded_octet::8>>)
  end

  defp maybe_parse_close_code(%{opcode: :close, payload: <<close_code::16, payload::bitstring>>} = frame) do
    %{frame | close_code: close_code, payload: payload}
  end
  defp maybe_parse_close_code(frame), do: frame

  def decode_octet(octet, nil, _), do: octet

  def decode_octet(octet, mask, index) do
    mask_octet = elem(mask, rem(index, 4))
    octet ^^^ mask_octet
  end

  defp divide_mask(<<octet_0::8, octet_1::8, octet_2::8, octet_3::8>>) do
    {octet_0, octet_1, octet_2, octet_3}
  end

  defp divide_mask(_), do: nil
end
