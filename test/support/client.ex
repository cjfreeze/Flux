defmodule Flux.Test.Client do
  def request(method \\ :get, path \\ "localhost:4567", body \\ "", headers \\ [], options \\ []) do
    HTTPoison.request(method, path, body, headers, options)
  end
end
