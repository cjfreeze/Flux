defmodule Flux.HTTP.ParserTest do
  use ExUnit.Case

  alias Flux.HTTP.Parser
  alias Flux.Conn

  describe "HTTP Method parsing" do
    @method_enum [
      get: "GET",
      head: "HEAD",
      post: "POST",
      options: "OPTIONS",
      put: "PUT",
      delete: "DELETE",
      trace: "TRACE",
      connect: "CONNECT"
    ]

    test "successfully parses all methods for HTTP/1.1 requests" do
      for {atomized_method, method} <- @method_enum do
        request = "#{method} / HTTP/1.1\r\n\r\n"
        assert conn = %Conn{} = Parser.parse(%Conn{}, request)

        assert %Conn{
                 method: ^atomized_method
               } = conn
      end
    end

    test "successfully parses all methods for HTTP/1.1 requests when request is fragmented" do
      for {atomized_method, method} <- @method_enum do
        request = "#{method} / HTTP/1.1\r\n\r\n"

        assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

        assert %Conn{
                 method: ^atomized_method
               } = conn
      end
    end

    test "returns incomplete if request ends in the middle of the method" do
      request = "OPT"
      assert {:incomplete, %Conn{}, iodata} = Parser.parse(%Conn{}, request)
      assert "OPT" = IO.iodata_to_binary(iodata)
    end

    test "returns error tuple if method is not supported" do
      request = "UNSUPPORTED / HTTP/1.1\r\n\r\n"

      assert {:error, {:unsupported_method, "UNSUPPORTED", %Conn{}}} =
               Parser.parse(%Conn{}, request)
    end
  end

  describe "URI and Query parsing" do
    test "successfully parses a simple URI" do
      request = "GET / HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               uri: "/"
             } = conn
    end

    test "successfully parses a simple URI when request is fragmented" do
      request = "GET / HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

      assert %Conn{
               uri: "/"
             } = conn
    end

    test "successfully parses a complex URI" do
      uri =
        "/thequickbrownfoxjumpsoverthelazydogTHEQUICKBROWNFOXJUMPSOVERTHELAZYDOG0123456789-._~:/#[]@!$&'()*+,;"

      request = "GET #{uri} HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               uri: ^uri
             } = conn
    end

    test "successfully parses a complex URI when request is fragmented" do
      uri =
        "/thequickbrownfoxjumpsoverthelazydogTHEQUICKBROWNFOXJUMPSOVERTHELAZYDOG0123456789-._~:/#[]@!$&'()*+,;"

      request = "GET #{uri} HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

      assert %Conn{
               uri: ^uri
             } = conn
    end

    test "successfully parses a query" do
      request = "GET /query?foo=bar HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               uri: "/query",
               query: "foo=bar"
             } = conn
    end

    test "successfully parses a query when request is fragmented" do
      request = "GET /query?foo=bar HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               uri: "/query",
               query: "foo=bar"
             } = conn
    end
  end

  describe "Version parsing" do
    test "successfully parses a version" do
      request = "GET / HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               version: "HTTP/1.1"
             } = conn
    end

    test "successfully parses a version when fragmented" do
      request = "GET / HTTP/1.1\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

      assert %Conn{
               version: "HTTP/1.1"
             } = conn
    end

    test "returns an error tuple when version is not supported" do
      request = "GET / HTTP/0.9\r\n\r\n"

      assert {:error, {:unsupported_version, "HTTP/0.9", %Conn{}}} =
               Parser.parse(%Conn{}, request)
    end
  end

  describe "Header parsing" do
    test "successfully parses a single header" do
      request = "GET / HTTP/1.1\r\nfoo: bar\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               req_headers: headers
             } = conn

      assert [{"foo", "bar"}] = headers
    end

    test "successfully parses a single header when fragmented" do
      request = "GET / HTTP/1.1\r\nfoo: bar\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

      assert %Conn{
               req_headers: headers
             } = conn

      assert [{"foo", "bar"}] = headers
    end

    test "successfully parses multiple headers" do
      request = "GET / HTTP/1.1\r\nfoo: bar\r\nhello: world\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               req_headers: headers
             } = conn

      assert [{"hello", "world"}, {"foo", "bar"}] = headers
    end

    test "successfully parses multiple headers when fragmented" do
      request = "GET / HTTP/1.1\r\nfoo: bar\r\nhello: world\r\n\r\n"
      assert conn = %Conn{} = parse_fragmented(%Conn{}, request)

      assert %Conn{
               req_headers: headers
             } = conn

      assert [{"hello", "world"}, {"foo", "bar"}] = headers
    end

    test "trims leading spaces off of header values" do
      request = "GET / HTTP/1.1\r\nfoo:          bar\r\n\r\n"
      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               req_headers: headers
             } = conn

      assert [{"foo", "bar"}] = headers
    end

    test "puts remaining data into request buffer for use in reading body or parsing future requests" do
      request = "GET / HTTP/1.1\r\ncontent-length: 4\r\n\r\nfoo\n"

      assert conn = %Conn{} = Parser.parse(%Conn{}, request)

      assert %Conn{
               req_headers: headers,
               req_buffer: "foo\n"
             } = conn

      assert [{"content-length", "4"}] = headers
    end
  end

  def parse_fragmented(conn, request) do
    do_parse_fragmented(request, conn)
  end

  defp do_parse_fragmented(request, conn, acc \\ [])

  defp do_parse_fragmented("", conn, acc) do
    Parser.parse(conn, "", acc)
  end

  defp do_parse_fragmented(<<head::binary-size(1), rest::binary>>, conn, acc) do
    case Parser.parse(conn, head, acc) do
      {:incomplete, conn, acc} ->
        do_parse_fragmented(rest, conn, acc)

      conn ->
        conn
    end
  end
end
