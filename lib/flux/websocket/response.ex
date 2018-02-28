defmodule Flux.Websocket.Response do
  alias Flux.Websocket.Opcode

  def send(%{frame: nil} = conn), do: conn
  def send(conn) do
    :gen_tcp.send(conn.socket, conn.frame)
    conn
  end

  def build_text_frame(conn, payload) do
    %{conn | frame: build_frame(:text, payload)}
  end

  def build_ping_frame(conn) do
    %{conn | frame: build_frame(:ping, "")}
  end

  def build_pong_frame(conn) do
    %{conn | frame: build_frame(:pong, "")}
  end

  defp build_frame(type, payload) do
    code = Opcode.from_atom(type)
    len = byte_size(payload)
    length_size = integer_bit_size(len)
    <<1::1, 0::1, 0::1, 0::1, code::4, 0::1>>
    |> add_length(len, length_size)
    |> add_payload(payload)
  end

  defp integer_bit_size(int) when int > 0 do
    :math.log2(int)
  end

  defp integer_bit_size(_), do: 1

  defp add_length(frame, len, len_size) when len_size > 16 do
    <<frame::bitstring, 127::7, len::64>>
  end

  defp add_length(frame, len, len_size) when len_size > 7 do
    <<frame::bitstring, 126::7, len::16>>
  end

  defp add_length(frame, len, _) do
    <<frame::bitstring, len::7>>
  end

  defp add_payload(frame, payload) do
    <<frame::bitstring, payload::bitstring>>
  end
end