defmodule Flux.HTTP.ChunkedTest do
  use ExUnit.Case
  alias Flux.HTTP.Chunked
  alias Flux.Support.{Conn}

  describe "read_chunked/4" do
    setup do
      {:ok, conn: Conn.tcp_transport_conn()}
    end

    test "reads a chunk from the socket", %{conn: conn} do
      Conn.set_test_buffer(conn, "2\r\nhi\r\n0\r\n\r\n")
      assert {:ok, %Flux.Conn{}, "hi"} = Chunked.read_chunked(conn, 1000, 1000, 1000)
    end

    test "reads multiple chunks from the socket", %{conn: conn} do
      Conn.set_test_buffer(conn, "3\r\nhi \r\nF\r\nsixteen charsss\r\n0\r\n\r\n")

      assert {:ok, %Flux.Conn{}, "hi sixteen charsss"} = Chunked.read_chunked(conn, 50, 50, 1000)
    end

    test "ignores header extensions", %{conn: conn} do
      Conn.set_test_buffer(
        conn,
        "3;asdf=zxcv\r\nhi \r\nF;thiswill=beignored\r\nfifteen charsss\r\n0;ending=extensions;multiple=extensions\r\n\r\n"
      )

      assert {:ok, %Flux.Conn{}, "hi fifteen charsss"} =
               Chunked.read_chunked(conn, 1000, 1000, 1000)
    end

    test "Can read even if received one octet at a time", %{conn: conn} do
      assert {conn, full_body} =
               "3;asdf=zxcv\r\nhi \r\nF;thiswill=beignored\r\nfifteen charsss\r\n0;ending=extensions;multiple=extensions\r\n\r\n"
               |> String.to_charlist()
               |> Enum.reduce({conn, ""}, fn char, {conn, buffer} ->
                 Conn.set_test_buffer(
                   conn,
                   <<char>>
                 )

                 assert {status, conn, chunk} = Chunked.read_chunked(conn, 1, 1, 1000)
                 assert status in [:more, :ok]
                 assert byte_size(chunk) in [0, 1]
                 #  IO.inspect(chunk, label: "chunk")
                 {conn, buffer <> chunk}
               end)

      assert "hi fifteen charsss" = full_body
    end

    test "Reads trailers", %{conn: conn} do
      Conn.set_test_buffer(conn, "2\r\nhi\r\n0\r\nkey:val\r\n\r\n")

      assert {:ok, %Flux.Conn{req_headers: [{"key", "val"}]}, "hi"} =
               Chunked.read_chunked(conn, 1000, 1000, 1000)
    end

    test "Reads trailers while ingoring extensions", %{conn: conn} do
      Conn.set_test_buffer(conn, "2\r\nhi\r\n0;some=extension\r\nkey:val\r\n\r\n")

      assert {:ok, %Flux.Conn{req_headers: [{"key", "val"}]}, "hi"} =
               Chunked.read_chunked(conn, 1000, 1000, 1000)
    end

    test "Reads trailers even if received one octet at a time", %{conn: conn} do
      chunked_body =
        "3;asdf=zxcv\r\nhi \r\nF\r\nfifteen charsss\r\n0\r\ntrailer:part\r\nanother:trailer\r\n\r\n"

      assert {conn, full_body} =
               chunked_body
               |> String.to_charlist()
               |> Enum.reduce({conn, ""}, fn char, {conn, buffer} ->
                 Conn.set_test_buffer(
                   conn,
                   <<char>>
                 )

                 assert {status, conn, chunk} = Chunked.read_chunked(conn, 1, 1, 1000)
                 assert status in [:more, :ok]
                 assert byte_size(chunk) in [0, 1]
                 {conn, buffer <> chunk}
               end)

      assert "hi fifteen charsss" = full_body

      assert conn.req_headers == [
               {"another", "trailer"},
               {"trailer", "part"}
             ]
    end
  end
end
