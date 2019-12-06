defmodule Flux.HTTP.Parser do
  alias Flux.Conn

  @supported_versions ~w(HTTP/1.1)

  @spec parse(Flux.Conn.t(), String.t()) :: Flux.Conn.t() | {:error, term}
  @spec parse(Flux.Conn.t(), String.t(), list) :: Flux.Conn.t()

  def parse(conn, data, acc \\ [])

  def parse(%Conn{method: nil} = conn, data, nil) do
    optimistic_parse_method(data, conn)
  end

  def parse(%Conn{method: nil} = conn, data, acc) do
    parse_method(data, conn, acc)
  end

  def parse(%Conn{uri: nil} = conn, data, acc) do
    parse_uri(data, conn, acc)
  end

  def parse(%Conn{query: nil} = conn, data, acc) do
    parse_query(data, conn, acc)
  end

  def parse(%Conn{version: nil} = conn, data, acc) do
    parse_version(data, conn, acc)
  end

  def parse(%Conn{req_buffer: nil} = conn, data, acc) do
    parse_headers(data, conn, acc)
  end

  defp optimistic_parse_method(<<"GET ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :get})
  end

  defp optimistic_parse_method(<<"HEAD ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :head})
  end

  defp optimistic_parse_method(<<"POST ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :post})
  end

  defp optimistic_parse_method(<<"OPTIONS ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :options})
  end

  defp optimistic_parse_method(<<"PUT ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :put})
  end

  defp optimistic_parse_method(<<"DELETE ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :delete})
  end

  defp optimistic_parse_method(<<"TRACE ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :trace})
  end

  defp optimistic_parse_method(<<"CONNECT ", rest::binary>>, %Conn{} = conn) do
    parse_uri(rest, %{conn | method: :connect})
  end

  defp optimistic_parse_method(data, %Conn{} = conn) do
    parse_method(data, conn)
  end

  defp parse_method(data, conn, acc \\ [])

  defp parse_method("", %Conn{} = conn, acc) do
    {:incomplete, conn, acc}
  end

  defp parse_method(<<" ", rest::binary>>, %Conn{} = conn, acc) do
    acc
    |> IO.iodata_to_binary()
    |> atomize_method()
    |> case do
      {:ok, method} ->
        parse_uri(rest, %{conn | method: method})

      {:error, :unsupported_method} ->
        {:error, {:unsupported_method, IO.iodata_to_binary(acc), conn}}
    end
  end

  defp parse_method(<<head::binary-size(1), rest::binary>>, %Conn{} = conn, acc) do
    parse_method(rest, conn, [acc | head])
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

  defp parse_uri(data, conn, acc \\ [])

  defp parse_uri("", %Conn{} = conn, acc) do
    {:incomplete, conn, acc}
  end

  defp parse_uri(<<" ", rest::binary>>, %Conn{} = conn, acc),
    do: parse_version(rest, %{conn | uri: IO.iodata_to_binary(acc), query: ""})

  defp parse_uri(<<"?", rest::binary>>, %Conn{} = conn, acc),
    do: parse_query(rest, %{conn | uri: IO.iodata_to_binary(acc)})

  defp parse_uri(<<head::binary-size(1), rest::binary>>, %Conn{} = conn, acc),
    do: parse_uri(rest, conn, [acc | head])

  defp parse_query(data, conn, acc \\ [])

  defp parse_query("", %Conn{} = conn, acc) do
    {:incomplete, conn, acc}
  end

  defp parse_query(<<" ", rest::binary>>, %Conn{} = conn, acc),
    do: parse_version(rest, %{conn | query: IO.iodata_to_binary(acc)})

  defp parse_query(<<head::binary-size(1), rest::binary>>, %Conn{} = conn, acc),
    do: parse_query(rest, conn, [acc | head])

  # TODO specifically look for the pattern HTTP/ in parsing
  defp parse_version(data, conn, acc \\ [])

  defp parse_version("", %Conn{} = conn, acc) do
    {:incomplete, conn, acc}
  end

  defp parse_version(<<"\n", rest::binary>>, %Conn{} = conn, [acc | "\r"]) do
    handle_version(rest, IO.iodata_to_binary(acc), conn)
  end

  defp parse_version(<<head::binary-size(1), rest::binary>>, %Conn{} = conn, acc) do
    parse_version(rest, conn, [acc | head])
  end

  defp handle_version(data, version, conn) when version in @supported_versions do
    parse_headers(data, %{conn | version: version})
  end

  defp handle_version(_, version, conn) do
    {:error, {:unsupported_version, version, conn}}
  end

  defp parse_headers(data, conn, acc \\ {[], nil, nil})

  defp parse_headers(<<"\r\n", rest::binary>>, conn, {header_acc, nil, nil}) do
    handle_complete_headers(rest, conn, header_acc)
  end

  defp parse_headers(<<"\n", rest::binary>>, conn, {header_acc, [_ | "\r"], nil}) do
    handle_complete_headers(rest, conn, header_acc)
  end

  defp parse_headers("", conn, acc) do
    {:incomplete, conn, acc}
  end

  defp parse_headers(data, conn, {header_acc, nil, nil}) do
    parse_header_key(data, conn, header_acc, [])
  end

  defp parse_headers(data, conn, {header_acc, key_acc, nil}) do
    parse_header_key(data, conn, header_acc, key_acc)
  end

  defp parse_headers(data, conn, {header_acc, key_acc, []}) do
    trim_header_value(data, conn, header_acc, key_acc)
  end

  defp parse_headers(data, conn, {header_acc, key_acc, val_acc}) do
    parse_header_value(data, conn, header_acc, key_acc, val_acc)
  end

  defp parse_header_key(<<"\n", rest::binary>>, conn, {header_acc, _key_acc, nil}, [_ | "\r"]) do
    handle_complete_headers(rest, conn, header_acc)
  end

  defp parse_header_key(<<":", rest::binary>>, %Conn{} = conn, header_acc, key_acc) do
    trim_header_value(rest, conn, header_acc, key_acc)
  end

  defp parse_header_key("", %Conn{} = conn, header_acc, key_acc) do
    {:incomplete, conn, {header_acc, key_acc, nil}}
  end

  defp parse_header_key(
         <<head::binary-size(1), rest::binary>>,
         %Conn{} = conn,
         header_acc,
         key_acc
       ) do
    parse_header_key(rest, conn, header_acc, [key_acc | head])
  end

  def trim_header_value("", conn, header_acc, key_acc) do
    {:incomplete, conn, {header_acc, key_acc, []}}
  end

  def trim_header_value(<<" ", rest::binary>>, conn, header_acc, key_acc) do
    trim_header_value(rest, conn, header_acc, key_acc)
  end

  def trim_header_value(data, conn, header_acc, key_acc) do
    parse_header_value(data, conn, header_acc, key_acc, [])
  end

  defp parse_header_value(<<"\r\n", rest::binary>>, %Conn{} = conn, header_acc, key_acc, val_acc) do
    handle_complete_header(rest, conn, header_acc, key_acc, val_acc)
  end

  defp parse_header_value(<<"\n", rest::binary>>, %Conn{} = conn, header_acc, key_acc, [
         val_acc | "\r"
       ]) do
    handle_complete_header(rest, conn, header_acc, key_acc, val_acc)
  end

  defp parse_header_value("", %Conn{} = conn, header_acc, key_acc, val_acc) do
    {:incomplete, conn, {header_acc, key_acc, val_acc}}
  end

  defp parse_header_value(
         <<head::binary-size(1), rest::binary>>,
         %Conn{} = conn,
         header_acc,
         key_acc,
         val_acc
       ) do
    parse_header_value(rest, conn, header_acc, key_acc, [val_acc | head])
  end

  defp handle_complete_header(data, conn, header_acc, key_acc, val_acc) do
    # https://hexdocs.pm/plug/Plug.Conn.html#module-request-fields
    # Downcased because in docs above, quote: "Note all headers will be downcased"
    key = IO.iodata_to_binary(key_acc) |> String.downcase()
    val = IO.iodata_to_binary(val_acc) |> String.downcase()
    # Move this into a callback variable passed in from Flux.HTTP that defaults to Headers

    parse_headers(
      data,
      Flux.HTTP.Headers.handle_header(conn, key, val),
      {[{key, val} | header_acc], nil, nil}
    )
  end

  defp handle_complete_headers(data, conn, header_acc) do
    %{conn | req_headers: header_acc, req_buffer: data}
  end
end
