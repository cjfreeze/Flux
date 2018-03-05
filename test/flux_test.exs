defmodule FluxTest do
  use ExUnit.Case
  alias Flux.Test.Client

  setup_all _flux do
    start_supervised({Flux.Handler, [:http, Flux.Test.Endpoint, [port: 4567, otp_app: :flux]]})
    %{flux: Flux}
  end

  describe "Flux" do
    test "returns valid content-length header with GET request", %{flux: _flux} do
      {:ok, %{body: body, headers: headers}} = Client.request()
      {_, content_length} = get_header(headers, "content-length")
      assert byte_size(body) == String.to_integer(content_length)
    end

    test "returns correct content-length header with HEAD request", %{flux: _flux} do
      {:ok, %{headers: headers}} = Client.request(:head)
      {:ok, %{body: body, headers: get_headers}} = Client.request()
      {_, content_length_value} = head_content_length = get_header(headers, "content-length")
      get_content_length = get_header(get_headers, "content-length")
      assert head_content_length == get_content_length
      assert byte_size(body) == String.to_integer(content_length_value)
    end

    test "responds to accept-encoding correctly", %{flux: _flux} do
      {:ok, %{body: encoded_body}} =
        Client.request(
          :get,
          "localhost:4000",
          "",
          [{"accept-encoding", "gzip;q=1.0, identity; q=0.5, *;q=0"}],
          []
        )

      {:ok, %{body: body}} = Client.request()
      assert :zlib.gunzip(encoded_body) == body
    end

    test "sends a file correctly", %{flux: _flux} do
      file = "#{System.tmp_dir()}file.txt"
      content = "Hello World!"
      File.write(file, content)
      {:ok, %{body: body}} = Client.request(:get, "localhost:4000/file", "", [], [])
      assert body == content
      {:ok, %{body: offset_body}} = Client.request(:get, "localhost:4000/file_offset", "", [], [])
      assert offset_body == String.slice(content, 6..10)
    end

    test "handles keep-alive correctly", %{flux: _flux} do
      {:ok, %{body: _body, headers: headers}} =
        Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])

      assert {"connection", "keep-alive"} = get_header(headers, "connection")

      Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])
    end
  end

  defp get_header(headers, key), do: Enum.find(headers, fn {k, _} -> k == key end)
end
