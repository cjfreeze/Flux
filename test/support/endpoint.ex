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

  def call(conn) do
    conn
    |> Conn.put_status(200)
    |> Conn.put_resp_body("Test")
    |> HTTP.send_response()
  end
end
