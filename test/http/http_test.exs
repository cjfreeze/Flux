defmodule Flux.HTTPTest do
  use ExUnit.Case
  alias Flux.{HTTP, Conn}
  alias Flux.Support.Conn, as: ConnSupport

  describe "read_request_body/4 with transfer_encoding: identity" do
    setup do
      conn = ConnSupport.tcp_transport_conn(transfer_coding: "identity", content_length: 11)

      ConnSupport.set_test_buffer(conn, "socket body")
      {:ok, conn: conn}
    end

    test "reads body from buffer before socket", %{conn: conn} do
      buffer = "buffer body"

      conn = %{
        conn
        | req_buffer: buffer,
          content_length: conn.content_length + byte_size(buffer)
      }

      assert {:more, "buffer", %Conn{}} = HTTP.read_request_body(conn, 6, 2, 1000)
    end

    test "reads body from both buffer and socket if they are both present", %{conn: conn} do
      buffer = "buffer and "

      conn = %{
        conn
        | req_buffer: buffer,
          content_length: conn.content_length + byte_size(buffer)
      }

      assert {:ok, "buffer and socket body", %Conn{}} = HTTP.read_request_body(conn, 22, 22, 1000)
    end

    test "reads body from socket", %{conn: conn} do
      assert {:ok, "socket body", %Conn{}} = HTTP.read_request_body(conn, 22, 22, 1000)
    end

    test "reads multiple partial bodies from socket", %{conn: conn} do
      # iF you don't rebind conn this test will fail because the conn keeps track of how much expected content is left to read.
      assert {:more, "socket", %Conn{} = conn} = HTTP.read_request_body(conn, 6, 6, 1000)
      assert {:more, " ", %Conn{} = conn} = HTTP.read_request_body(conn, 1, 1, 1000)
      assert {:ok, "body", %Conn{} = conn} = HTTP.read_request_body(conn, 4, 4, 1000)
    end

    test "reads multiple partial bodies from buffer and socket", %{conn: conn} do
      buffer = "buffer and "

      conn = %{
        conn
        | req_buffer: buffer,
          content_length: conn.content_length + byte_size(buffer)
      }

      assert {:more, "buffer ", %Conn{} = conn} = HTTP.read_request_body(conn, 7, 7, 1000)
      assert {:more, "and socket ", %Conn{} = conn} = HTTP.read_request_body(conn, 11, 11, 1000)
      assert {:ok, "body", %Conn{} = conn} = HTTP.read_request_body(conn, 4, 4, 1000)
    end
  end

  describe "read_request_body/4 with transfer_encoding: chunked" do
    # Most of this is tested already in test/http/chunked_test.exs, so only a few
    # tests are required here

    setup do
      {:ok, conn: ConnSupport.tcp_transport_conn(transfer_coding: "chunked")}
    end

    test "Everything works as expected through ", %{conn: conn} do
      chunked_body =
        "3;asdf=zxcv\r\nhi \r\nF\r\nfifteen charsss\r\n0\r\ntrailer:part\r\nanother:trailer\r\n\r\n"

      assert {conn, full_body} =
               chunked_body
               |> String.to_charlist()
               |> Enum.reduce({conn, ""}, fn char, {conn, buffer} ->
                 ConnSupport.set_test_buffer(
                   conn,
                   <<char>>
                 )

                 assert {status, conn, chunk} = HTTP.read_request_body(conn, 1, 1, 1000)
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
