defmodule Flux.Test.Endpoint do
  alias Flux.{
    Conn,
    HTTP
  }

  def call(%{uri: ["/", "f", "i", "l", "e"]} = conn) do
    conn
    |> Conn.put_status(200)
    |> HTTP.send_file("#{System.tmp_dir()}/file.txt", 0, :all)
  end

  def call(%{uri: ["/", "f", "i", "l", "e", "_", "o", "f", "f", "s", "e", "t"]} = conn) do
    conn
    |> Conn.put_status(200)
    |> HTTP.send_file("#{System.tmp_dir()}/file.txt", 6, 5)
  end

  def call(%{uri: ["/", "s", "t", "a", "t", "u", "s"], req_headers: headers} = conn) do
    code =
      headers
      |> List.keyfind("x-put-status", 0)
      |> elem(1)
      |> String.to_integer()

    HTTP.send_response(conn, code, [], "")
  end

  def call(%{method: :POST, req_body: body} = conn) do
    HTTP.send_response(conn, 200, [], body)
  end

  def call(conn) do
    HTTP.send_response(conn, 200, [], "Test")
  end
end
