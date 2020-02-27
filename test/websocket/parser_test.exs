defmodule Flux.Websocket.ParserTest do
  use ExUnit.Case
  alias Flux.Websocket.Parser
  alias WebSockex.Frame
  alias Flux.Support.Transport

  setup do
    {:ok, listen_socket} = Transport.listen(1234, [])
    {:ok, socket} = Transport.accept(listen_socket, [])
    {:ok, %{socket: socket}}
  end

  describe "parse/1" do
    # also close but done separately
    @frame_types ~w(text binary ping pong)a
    test "parses all valid frame types", %{socket: socket} do
      for frame_type <- @frame_types do
        {:ok, frame} = Frame.encode_frame({frame_type, "payload"})

        assert %{payload: "payload", opcode: ^frame_type} =
                 Parser.parse({Transport, socket}, frame)
      end

      {:ok, frame} = Frame.encode_frame({:close, 1000, "payload"})

      assert %{payload: "payload", close_code: 1000, opcode: :close} =
               Parser.parse({Transport, socket}, frame)
    end
  end
end
