defmodule FluxTest do
  use ExUnit.Case
  alias Flux.Test.Client

  setup_all _flux do
    start_supervised(
      {Flux,
       [
         scheme: :http,
         port: 4567,
         otp_app: :flux,
         handler: Flux.Test.Endpoint
       ]}
    )

    HTTPoison.start()
    %{flux: Flux, host: "localhost:4567"}
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

    test "responds to accept-encoding correctly", %{flux: _flux, host: host} do
      {:ok, %{body: encoded_body}} =
        Client.request(
          :get,
          host,
          "",
          [{"accept-encoding", "gzip;q=1.0, identity; q=0.5, *;q=0"}],
          []
        )

      {:ok, %{body: body}} = Client.request()
      assert :zlib.gunzip(encoded_body) == body
    end

    test "sends a file correctly", %{flux: _flux, host: host} do
      content = "Hello World!"
      file = System.tmp_dir!() <> "file.txt"
      File.write!(file, content)
      assert {:ok, %{body: body}} = Client.request(:post, "#{host}/file", file)
      assert body == content
    end

    test "sends a file with offset correctly", %{flux: _flux, host: host} do
      content = "Hello World!"
      file = System.tmp_dir!() <> "file.txt"
      File.write!(file, content)
      body = :erlang.term_to_binary({file, 5})
      assert {:ok, %{body: offset_body}} = Client.request(:post, "#{host}/file_offset", body)

      assert offset_body == "Hello W"
    end

    test "sends a file with offset and length correctly", %{host: host} do
      content = "Hello World!"
      file = System.tmp_dir!() <> "file.txt"
      File.write!(file, content)
      body = :erlang.term_to_binary({file, 4, 4})

      assert {:ok, %{body: offset_body}} =
               Client.request(:post, "#{host}/file_offset_length", body)

      assert offset_body == "o Wo"
    end

    test "handles HTTP POST correctly", %{host: host} do
      body = "flux post test body"

      assert {:ok, %{body: ^body}} = Client.request(:post, host, body)
    end

    test "handles all statuses correctly", %{host: host} do
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
                   "#{host}/status",
                   "#{status_code}"
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
