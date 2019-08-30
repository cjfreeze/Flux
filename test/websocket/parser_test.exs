defmodule Flux.Websocket.ParserTest do
  use ExUnit.Case
  alias Flux.Websocket.Parser
  alias WebSockex.Frame

  describe "parse/1" do
    @frame_types ~w(text binary ping pong)a # also close but done separately
    test "parses all valid frame types" do
      for frame_type <- @frame_types do
        {:ok, frame} = Frame.encode_frame({frame_type, "payload"})
        assert %{payload: "payload", opcode: ^frame_type}  = Parser.parse(frame)
      end
      {:ok, frame} = Frame.encode_frame({:close, 1000, "payload"})
      assert %{payload: "payload", close_code: 1000, opcode: :close} = Parser.parse(frame)
    end
  end
end