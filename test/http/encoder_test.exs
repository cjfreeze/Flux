defmodule Flux.HTTP.EncoderTest do
  use ExUnit.Case

  alias Flux.HTTP.Encoder

  describe "which_coding/1" do
    test "picks the preferred coding" do
      assert Encoder.which_coding(%{"identity" => 0.5, "gzip" => 1.0}) == {:ok, "gzip"}
      assert Encoder.which_coding(%{"gzip" => 0.5, "identity" => 0.9, "*" => 1.0}) == {:ok, "*"}
    end

    test "defaults to identity" do
      assert Encoder.which_coding(%{}) == {:ok, "identity"}
    end
  end

  describe "encode/2" do
    test "does nothing when provided `\"identity\"`" do
      assert Encoder.encode("identity", "Flux") == {:ok, "Flux"}
    end

    test "defaults to identity" do
      assert Encoder.encode("*", "Flux") == {:ok, "Flux"}
    end

    test "encodes correctly with gzip when given `\"gzip\"`" do
      correct =
        <<31, 139, 8, 0, 0, 0, 0, 0, 0, 19, 115, 203, 41, 173, 0, 0, 4, 158, 96, 210, 4, 0, 0, 0>>

      assert Encoder.encode("gzip", "Flux") == {:ok, correct}
    end

    test "errors with 406 Not Acceptable if the coding is not supported" do
      assert Encoder.encode("unsupported", "Flux") == {:error, 406}
    end
  end
end
