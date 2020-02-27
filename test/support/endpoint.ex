defmodule Flux.Test.Endpoint do
  alias Flux.HTTP

  def handle_request(conn, _opts) do
    do_handle(conn)
  end

  defp do_handle(%{method: :post, uri: "/status"} = conn) do
    {:ok, status, conn} = HTTP.read_request_body(conn, 1000, 1000, 1000)
    HTTP.send_response(conn, String.to_integer(status), [], "")
  end

  defp do_handle(%{method: :post, uri: "/file"} = conn) do
    {:ok, file, conn} = HTTP.read_request_body(conn, 1000, 1000, 1000)
    HTTP.send_file(conn, 200, [], file)
  end

  defp do_handle(%{method: :post, uri: "/file_offset"} = conn) do
    {:ok, term, conn} = HTTP.read_request_body(conn, 1000, 1000, 1000)
    {file, offset} = :erlang.binary_to_term(term)
    HTTP.send_file(conn, 200, [], file, offset)
  end

  defp do_handle(%{method: :post, uri: "/file_offset_length"} = conn) do
    {:ok, term, conn} = HTTP.read_request_body(conn, 1000, 1000, 1000)
    {file, offset, length} = :erlang.binary_to_term(term)
    HTTP.send_file(conn, 200, [], file, offset, length)
  end

  defp do_handle(%{method: :post} = conn) do
    {:ok, body, conn} = HTTP.read_request_body(conn, 1000, 1000, 1000)
    HTTP.send_response(conn, 200, [], body)
  end

  defp do_handle(conn) do
    HTTP.send_response(conn, 200, [], "test")
  end
end
