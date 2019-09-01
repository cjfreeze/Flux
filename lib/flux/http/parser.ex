defmodule Flux.HTTP.Parser do
  alias Flux.Conn

  @supported_versions ~w(HTTP/1.1)

  @spec parse(Flux.HTTP.state(), String.t()) :: Flux.state()

  def parse(state, data, acc \\ [])

  def parse(%Conn{method: nil} = state, data, nil) do
    optimistic_parse_method(data, state)
  end

  def parse(%Conn{method: nil} = state, data, acc) do
    parse_method(data, state, acc)
  end

  def parse(%Conn{uri: nil} = state, data, acc) do
    parse_uri(data, state, acc)
  end

  def parse(%Conn{query: nil} = state, data, acc) do
    parse_query(data, state, acc)
  end

  def parse(%Conn{version: nil} = state, data, acc) do
    parse_version(data, state, acc)
  end

  def parse(%Conn{req_buffer: nil} = state, data, acc) do
    parse_headers(data, state, acc)
  end

  defp optimistic_parse_method(<<"GET ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :get})
  end

  defp optimistic_parse_method(<<"HEAD ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :head})
  end

  defp optimistic_parse_method(<<"POST ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :post})
  end

  defp optimistic_parse_method(<<"OPTIONS ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :options})
  end

  defp optimistic_parse_method(<<"PUT ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :put})
  end

  defp optimistic_parse_method(<<"DELETE ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :delete})
  end

  defp optimistic_parse_method(<<"TRACE ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :trace})
  end

  defp optimistic_parse_method(<<"CONNECT ", rest::binary>>, %Conn{} = state) do
    parse_uri(rest, %{state | method: :connect})
  end

  defp optimistic_parse_method(data, %Conn{} = state) do
    parse_method(data, state)
  end

  defp parse_method(data, state, acc \\ [])

  defp parse_method("", %Conn{} = state, acc) do
    {:incomplete, state, acc}
  end

  defp parse_method(<<" ", rest::binary>>, %Conn{} = state, acc) do
    acc
    |> IO.iodata_to_binary()
    |> atomize_method()
    |> case do
      {:ok, method} ->
        parse_uri(rest, %{state | method: method})

      {:error, :unsupported_method} ->
        {:error, {:unsupported_method, IO.iodata_to_binary(acc), state}}
    end
  end

  defp parse_method(<<head::binary-size(1), rest::binary>>, %Conn{} = state, acc) do
    parse_method(rest, state, [acc | head])
  end

  method_enumeration = [
    get: "GET",
    head: "HEAD",
    post: "POST",
    options: "OPTIONS",
    put: "PUT",
    delete: "DELETE",
    trace: "TRACE",
    connect: "CONNECT"
  ]

  for {atom, method} <- method_enumeration do
    defp atomize_method(unquote(method)), do: {:ok, unquote(atom)}
  end

  defp atomize_method(_) do
    {:error, :unsupported_method}
  end

  defp parse_uri(data, state, acc \\ [])

  defp parse_uri("", %Conn{} = state, acc) do
    {:incomplete, state, acc}
  end

  defp parse_uri(<<" ", rest::binary>>, %Conn{} = state, acc),
    do: parse_version(rest, %{state | uri: IO.iodata_to_binary(acc), query: ""})

  defp parse_uri(<<"?", rest::binary>>, %Conn{} = state, acc),
    do: parse_query(rest, %{state | uri: IO.iodata_to_binary(acc)})

  defp parse_uri(<<head::binary-size(1), rest::binary>>, %Conn{} = state, acc),
    do: parse_uri(rest, state, [acc | head])

  defp parse_query(data, state, acc \\ [])

  defp parse_query("", %Conn{} = state, acc) do
    {:incomplete, state, acc}
  end

  defp parse_query(<<" ", rest::binary>>, %Conn{} = state, acc),
    do: parse_version(rest, %{state | query: IO.iodata_to_binary(acc)})

  defp parse_query(<<head::binary-size(1), rest::binary>>, %Conn{} = state, acc),
    do: parse_query(rest, state, [acc | head])

  # TODO specifically look for the pattern HTTP/ in parsing
  defp parse_version(data, state, acc \\ [])

  defp parse_version("", %Conn{} = state, acc) do
    {:incomplete, state, acc}
  end

  defp parse_version(<<"\n", rest::binary>>, %Conn{} = state, [acc | "\r"]) do
    handle_version(rest, IO.iodata_to_binary(acc), state)
  end

  defp parse_version(<<head::binary-size(1), rest::binary>>, %Conn{} = state, acc) do
    parse_version(rest, state, [acc | head])
  end

  defp handle_version(data, version, state) when version in @supported_versions do
    parse_headers(data, %{state | version: version})
  end

  defp handle_version(_, version, state) do
    {:error, {:unsupported_version, version, state}}
  end

  defp parse_headers(data, state, acc \\ {[], nil, nil})

  defp parse_headers(<<"\r\n", rest::binary>>, state, {header_acc, nil, nil}) do
    handle_complete_headers(rest, state, header_acc)
  end

  defp parse_headers(<<"\n", rest::binary>>, state, {header_acc, [_ | "\r"], nil}) do
    handle_complete_headers(rest, state, header_acc)
  end

  defp parse_headers("", state, acc) do
    {:incomplete, state, acc}
  end

  defp parse_headers(data, state, {header_acc, nil, nil}) do
    parse_header_key(data, state, header_acc, [])
  end

  defp parse_headers(data, state, {header_acc, key_acc, nil}) do
    parse_header_key(data, state, header_acc, key_acc)
  end

  defp parse_headers(data, state, {header_acc, key_acc, []}) do
    trim_header_value(data, state, header_acc, key_acc)
  end

  defp parse_headers(data, state, {header_acc, key_acc, val_acc}) do
    parse_header_value(data, state, header_acc, key_acc, val_acc)
  end

  defp parse_header_key(<<"\n", rest::binary>>, state, {header_acc, _key_acc, nil}, [_ | "\r"]) do
    handle_complete_headers(rest, state, header_acc)
  end

  defp parse_header_key(<<":", rest::binary>>, %Conn{} = state, header_acc, key_acc) do
    trim_header_value(rest, state, header_acc, key_acc)
  end

  defp parse_header_key("", %Conn{} = state, header_acc, key_acc) do
    {:incomplete, state, {header_acc, key_acc, nil}}
  end

  defp parse_header_key(
         <<head::binary-size(1), rest::binary>>,
         %Conn{} = state,
         header_acc,
         key_acc
       ) do
    parse_header_key(rest, state, header_acc, [key_acc | head])
  end

  def trim_header_value("", state, header_acc, key_acc) do
    {:incomplete, state, {header_acc, key_acc, []}}
  end

  def trim_header_value(<<" ", rest::binary>>, state, header_acc, key_acc) do
    trim_header_value(rest, state, header_acc, key_acc)
  end

  def trim_header_value(data, state, header_acc, key_acc) do
    parse_header_value(data, state, header_acc, key_acc, [])
  end

  defp parse_header_value(<<"\r\n", rest::binary>>, %Conn{} = state, header_acc, key_acc, val_acc) do
    handle_complete_header(rest, state, header_acc, key_acc, val_acc)
  end

  defp parse_header_value(<<"\n", rest::binary>>, %Conn{} = state, header_acc, key_acc, [
         val_acc | "\r"
       ]) do
    handle_complete_header(rest, state, header_acc, key_acc, val_acc)
  end

  defp parse_header_value("", %Conn{} = state, header_acc, key_acc, val_acc) do
    {:incomplete, state, {header_acc, key_acc, val_acc}}
  end

  defp parse_header_value(
         <<head::binary-size(1), rest::binary>>,
         %Conn{} = state,
         header_acc,
         key_acc,
         val_acc
       ) do
    parse_header_value(rest, state, header_acc, key_acc, [val_acc | head])
  end

  defp handle_complete_header(data, state, header_acc, key_acc, val_acc) do
    key = IO.iodata_to_binary(key_acc)
    val = IO.iodata_to_binary(val_acc)
    # Move this into a callback variable passed in from Flux.HTTP that defaults to Headers
    # Flux.HTTP.Headers.handle_header(state, downcased_key, downcased_val)
    # TODO metaprogram all possible downcase possibilites in headers
    parse_headers(data, state, {[{key, val} | header_acc], nil, nil})
  end

  defp handle_complete_headers(data, state, header_acc) do
    %{state | req_headers: header_acc, req_buffer: data}
  end
end
