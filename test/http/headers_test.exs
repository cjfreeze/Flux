defmodule Flux.HeadersTest do
  use ExUnit.Case

  alias Flux.HTTP.Headers
  alias Flux.Conn

  @codings [
    {"identity, gzip", %{"gzip" => 1.0, "identity" => 1.0}},
    {"", %{}},
    {"*", %{"*" => 1.0}},
    {"identity;q=0.5, gzip;q=1.0", %{"gzip" => 1.0, "identity" => 0.5}},
    {"gzip;q=1.0, identity; q=0.5, *;q=0", %{"*" => 0.0, "gzip" => 1.0, "identity" => 0.5}}
  ]

  @mimetypes [
    {"text/html", %{"text/html" => 1.0}},
    {"text/*;q=0.3, text/html;q=0.7, text/html;level=1, text/html;level=2;q=0.4, */*;q=0.5",
     %{
       "*/*" => 0.5,
       "text/*" => 0.3,
       "text/html" => 0.7,
       "text/html;level=1" => 1.0,
       "text/html;level=2" => 0.4
     }}
  ]

  @charsets [
    {"ISO-8859-5, unicode-1-1;q=0.8",
     %{"ISO-8859-5" => 1.0, "unicode-1-1" => 0.8, "ISO-8859-1" => 1.0}},
    {"", %{"ISO-8859-1" => 1.0}},
    {"ISO-8859-1", %{"ISO-8859-1" => 1.0}},
    {"unicode-1-1;q=0", %{"ISO-8859-1" => 1.0, "unicode-1-1" => 0.0}}
  ]

  @langauges [
    {"da, en-gb;q=0.8, en;q=0.7", %{"da" => 1.0, "en" => 0.7, "en-gb" => 0.8}},
    {"da,en-gb;q=0.8,en;q=0.7", %{"da" => 1.0, "en" => 0.7, "en-gb" => 0.8}},
    {"da,   en-gb;q=0.8,en;q=0.7   ", %{"da" => 1.0, "en" => 0.7, "en-gb" => 0.8}}
  ]

  describe "Supports the HTTP/1.1 request header" do
    test "accept" do
      for {mimetypes, parsed_mimetypes} <- @mimetypes do
        conn =
          %Conn{}
          |> Headers.handle_header("accept", mimetypes)

        assert conn.accept == parsed_mimetypes
      end
    end

    test "accept-charset" do
      for {charsets, parsed_charsets} <- @charsets do
        conn =
          %Conn{}
          |> Headers.handle_header("accept-charset", charsets)

        assert conn.accept_charset == parsed_charsets
      end
    end

    test "accept-language" do
      for {languages, parsed_languages} <- @langauges do
        conn =
          %Conn{}
          |> Headers.handle_header("accept-language", languages)

        assert conn.accept_language == parsed_languages
      end
    end

    test "accept-encoding" do
      for {coding, parsed_coding} <- @codings do
        conn =
          %Conn{}
          |> Headers.handle_header("accept-encoding", coding)

        assert conn.accept_encoding == parsed_coding
      end
    end

    test "connection" do
      conn =
        %Conn{}
        |> Headers.handle_header("connection", "keep-alive")

      assert conn.keep_alive

      conn =
        %Conn{}
        |> Headers.handle_header("connection", "close")

      refute conn.keep_alive
    end
  end
end
