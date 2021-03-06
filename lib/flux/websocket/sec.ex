defmodule Flux.Websocket.Sec do
  @guid "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

  def sign(conn, http_conn) do
    ws_accept =
      http_conn.req_headers
      |> Enum.find_value(&do_find/1)
      |> do_sign()

    %{conn | ws_accept: ws_accept}
  end

  def do_find({key, val}) do
    if String.downcase(key) == "sec-websocket-key" do
      val
    else
      false
    end
  end

  defp do_sign(nil), do: throw "Expected the header sec-websocket-key to be present in the conn, but could not find it."
  defp do_sign(key) do
    :crypto.hash(:sha, key <> @guid)
    |> Base.encode64()
  end
end
