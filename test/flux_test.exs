defmodule FluxTest do
  use ExUnit.Case
  alias Flux.Test.Client

  setup_all _flux do
    start_supervised(
      {Flux.Handler, [scheme: :http, port: 4567, otp_app: :flux, endpoint: Flux.Test.Endpoint]}
    )

    HTTPoison.start()
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
      content = "Hello World!"
      assert {:ok, %{body: body}} = Client.request(:get, "localhost:4000/file", "", [], [])
      assert body == content

      assert {:ok, %{body: offset_body}} =
               Client.request(:get, "localhost:4000/file_offset", "", [], [])

      assert offset_body == String.slice(content, 6..10)

      assert {:ok, %{body: offset_body}} =
               Client.request(:get, "localhost:4000/file_offset", "", [], [])

      assert offset_body == String.slice(content, 6..10)
    end

    test "handles keep-alive correctly", %{flux: _flux} do
      assert {:ok, %{body: _body, headers: headers}} =
               Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])

      assert {"connection", "keep-alive"} = get_header(headers, "connection")

      Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])
    end

    test "handles HTTP POST correctly" do
      body = "flux post test body"

      assert {:ok, %{body: ^body, headers: headers}} =
               Client.request(:post, "localhost:4000", body, [{"connection", "keep-alive"}], [])
    end

    test "handles all statuses correctly" do
      [
        100..102,
        200..208,
        226,
        300..305,
        307,
        308,
        400..418,
        421..424,
        426,
        428,
        429,
        431,
        444,
        451,
        499,
        500..508,
        510,
        511,
        599
      ]
      |> special_map(fn status_code ->
        assert {:ok, %{status_code: ^status_code} = resp} =
                 Client.request(
                   :post,
                   "localhost:4000/status",
                   "",
                   [{"x-put-status", "#{status_code}"}],
                   []
                 )
      end)
    end
  end

  defp special_map(statuses, func) when is_list(statuses),
    do: Enum.map(statuses, &special_map(&1, func))

  defp special_map(status, func) when is_integer(status), do: func.(status)

  defp special_map(range, func) do
    Enum.reduce(range, func, fn status, func ->
      func.(status)
      func
    end)
  end

  defp get_header(headers, key), do: Enum.find(headers, fn {k, _} -> k == key end)
end
