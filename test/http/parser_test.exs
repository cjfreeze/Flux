defmodule Flux.ParserTest do
  use ExUnit.Case

  alias Flux.HTTP.Parser
  alias Flux.Conn

  describe "parse/2" do
    @valid_methods ~w(OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT)

    test "Successfully parses all methods for HTTP/1.1 requests" do
      for method <- @valid_methods do
        atomized_method =
          method
          |> String.to_existing_atom()

        data =
          method
          |> request("/", [], "some_body")

        state =
          %Conn{}
          |> Parser.parse(data)

        request = "#{method} / HTTP/1.1\r\n\r\nsome_body\n"

        assert %Conn{
                 keep_alive: false,
                 method: ^atomized_method,
                 request: ^request,
                 req_body: "some_body\n",
                 resp_headers: [],
                 transport: nil,
                 uri: ["/"],
                 version: :"HTTP/1.1"
               } = state
      end
    end
  end

  defp request(method, path, headers, body) do
    """
    #{method} #{path} HTTP/1.1\r
    #{
      for header <- headers do
        header <> "\r\n"
      end
    }\r
    #{body}
    """
  end
end
