defmodule Flux.Websocket.FrameTest do
  use ExUnit.Case
  alias Flux.Websocket.Frame

  describe "Frame.build_frame/2" do
    @opcodes [
      continue: 0x0,
      text: 0x1,
      binary: 0x2,
      close: 0x8,
      ping: 0x9,
      pong: 0xA
    ]
    test "builds the correct frames for all opcodes" do
      for({atom, integer} <- @opcodes) do
        frame =
          atom
          |> Frame.build_frame("payload")
          |> IO.iodata_to_binary()
        assert <<_::4, ^integer::4, _::bitstring>> = frame
      end
    end

    test "does not mask frames" do
      frame = frame_fixture("payload")
      # 0::1 tests that the frame bit is 0, indicating an unmasked payload
      # 7::7 is not relevent to the test, but we need to match on the length
      # to then match the payload to ensure it is not masked, and we might
      # as well match on what the length should be.
      assert <<_::8, 0::1, 7::7, "payload">> = frame
    end

    test "properly determines payload length" do
      short_binary_frame = frame_fixture(gen_binary_payload(10))
      medium_binary_frame = frame_fixture(gen_binary_payload(300))
      long_binary_frame = frame_fixture(gen_binary_payload(65537))
      short_iodata_frame = frame_fixture(gen_iodata_payload(10))
      medium_iodata_frame = frame_fixture(gen_iodata_payload(300))
      long_iodata_frame = frame_fixture(gen_iodata_payload(65537))

      assert <<_::9, 10::7, _::bitstring>> = short_binary_frame
      assert <<_::9, 10::7, _::bitstring>> = short_iodata_frame

      assert <<_::9, 126::7, 300::16, _::bitstring>> = medium_binary_frame
      assert <<_::9, 126::7, 300::16, _::bitstring>> = medium_iodata_frame

      assert <<_::9, 127::7, 65537::64, _::bitstring>> = long_binary_frame
      assert <<_::9, 127::7, 65537::64, _::bitstring>> = long_iodata_frame
    end

    test "builds frames to iodata and accepts iodata payloads" do
      frame = Frame.build_frame(:text, ["payload"])
      assert is_list(frame)
      assert String.contains?(IO.iodata_to_binary(frame), "payload")
    end
  end

  defp frame_fixture(payload) do
    :text
    |> Frame.build_frame(payload)
    |> IO.iodata_to_binary()
  end

  defp gen_binary_payload(length) do
    Enum.reduce(1..length, "", &("#{<<&1::8>>}#{&2}"))
  end

  defp gen_iodata_payload(length) do
    Enum.reduce(1..length, [], &([<<&1::8>> | &2]))
  end
end