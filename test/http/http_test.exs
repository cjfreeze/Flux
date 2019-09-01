defmodule Flux.HTTPTest do
  use ExUnit.Case
  alias Flux.{HTTP, Conn}
  alias Flux.Support.Transport

  describe "read_request_body/4 with transfer_encoding: identity" do
    setup do
      {:ok, listen_socket} = Transport.listen(4000, [])
      {:ok, socket} = Transport.accept(listen_socket, 0)
      body = "socket body"
      conn = %Conn{transport: Transport, socket: socket, content_length: byte_size(body)}
      Transport.put_fake_test_buffer(socket, body)
      {:ok, %{conn: conn}}
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
end
