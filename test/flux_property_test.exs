defmodule FluxPropertyTest do
  use ExUnit.Case
  use ExUnitProperties
  alias Flux.Test.Client

  setup_all _flux do
    start_supervised(
      {Flux.Handler, [scheme: :http, port: 4000, otp_app: :flux, endpoint: Flux.Test.Endpoint]}
    )

    Application.load(:stream_data)
    HTTPoison.start()
    %{flux: Flux}
  end

  describe "Flux" do
    test "handles HTTP POST correctly" do
      check all body <- StreamData.binary() do
        assert {:ok, %{body: ^body}} = Client.request(:post, "localhost:4000", body, [], [])
      end
    end

    test "returns valid content-length header with GET request", %{flux: _flux} do
      check all body <- StreamData.binary() do
        assert {:ok, %{headers: headers}} = Client.request(:post, "localhost:4000", body, [], [])

        assert {_, content_length} = List.keyfind(headers, "content-length", 0)
        assert byte_size(body) == String.to_integer(content_length)
      end
    end

    test "responds to accept-encoding correctly", %{flux: _flux} do
      check all body <- StreamData.binary() do
        {:ok, %{body: encoded_body}} =
          Client.request(
            :post,
            "localhost:4000",
            body,
            [{"accept-encoding", "gzip;q=1.0, identity; q=0.5, *;q=0"}],
            []
          )

        assert :zlib.gunzip(encoded_body) == body
      end
    end

    # Is it a good idea to property test by writing a file?
    # test "sends a file correctly", %{flux: _flux} do
    #   content = "Hello World!"
    #   assert {:ok, %{body: body}} = Client.request(:get, "localhost:4000/file", "", [], [])
    #   assert body == content

    #   assert {:ok, %{body: offset_body}} =
    #            Client.request(:get, "localhost:4000/file_offset", "", [], [])

    #   assert offset_body == String.slice(content, 6..10)

    #   assert {:ok, %{body: offset_body}} =
    #            Client.request(:get, "localhost:4000/file_offset", "", [], [])

    #   assert offset_body == String.slice(content, 6..10)
    # end

    # test "handles keep-alive correctly", %{flux: _flux} do
    #   assert {:ok, %{body: _body, headers: headers}} =
    #            Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])

    #   assert {"connection", "keep-alive"} = get_header(headers, "connection")

    #   Client.request(:get, "localhost:4000", "", [{"connection", "keep-alive"}], [])
    # end
  end
end
