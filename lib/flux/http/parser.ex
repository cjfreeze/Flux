defmodule Flux.HTTP.Parser do
  require Logger
  import Flux.HTTP.Macros

  @spec parse(Flux.HTTP.state(), String.t()) :: Flux.state()
  def parse(state, data) do
    Map.put(state, :data, data)
    |> Map.put(:request, data)
    |> parse_method()
    |> parse_uri()
    |> parse_version()
    |> advance_newline()
    |> parse_headers()
    |> parse_body()
    |> Map.delete(:data)
  end

  defp parse_method(%{data: <<"GET ", rest::binary>>} = state) do
    %{state | method: :GET, data: rest}
  end

  defp parse_method(%{data: <<"HEAD ", rest::binary>>} = state) do
    %{state | method: :HEAD, data: rest}
  end

  defp parse_method(%{data: <<"POST ", rest::binary>>} = state) do
    %{state | method: :POST, data: rest}
  end

  defp parse_method(%{data: <<"OPTIONS ", rest::binary>>} = state) do
    %{state | method: :OPTIONS, data: rest}
  end

  defp parse_method(%{data: <<"PUT ", rest::binary>>} = state) do
    %{state | method: :PUT, data: rest}
  end

  defp parse_method(%{data: <<"DELETE ", rest::binary>>} = state) do
    %{state | method: :DELETE, data: rest}
  end

  defp parse_method(%{data: <<"TRACE ", rest::binary>>} = state) do
    %{state | method: :TRACE, data: rest}
  end

  defp parse_method(%{data: <<"CONNECT ", rest::binary>>} = state) do
    %{state | method: :CONNECT, data: rest}
  end

  defp parse_method(state) do
    Logger.error("Unmatched method #{inspect(state.data)}")
  end

  defp parse_uri(state, acc \\ [])

  defp parse_uri(%{data: <<" ", tail::binary>>} = state, acc),
    do: %{state | uri: Enum.reverse(acc), data: tail}

  defp parse_uri(%{data: <<head::binary-size(1), tail::binary>>} = state, acc),
    do: parse_uri(%{state | data: tail}, [head | acc])

  defp parse_uri(_, acc),
    do: Logger.error("Undexpectedly reached end of data with acc #{inspect(acc)}")

  defp parse_version(%{data: <<"HTTP/1.1", rest::binary>>} = state) do
    %{state | version: :"HTTP/1.1", data: rest}
  end

  defp parse_version(%{data: <<"HTTP/1.0", rest::binary>>} = state) do
    %{state | version: :"HTTP/1.0", data: rest}
  end

  defp parse_version(state) do
    Logger.error("Unmatched version #{inspect(state.data)}")
  end

  defm advance_newline(%{data: <<:__MATCH__, rest::binary>>} = state), [
    "\r\n",
    "\n\r",
    "\n",
    "\r"
  ] do
    %{state | data: rest}
  end

  defp advance_newline(state), do: state

  defm(
    parse_headers(%{data: <<:__MATCH__, rest::binary>>} = state),
    ["\n\r", "\r\n", "\n", "\r"],
    do: %{state | data: rest}
  )

  defp parse_headers(state) do
    state
    |> clear_newlines()
    |> parse_header_key()
  end

  defp parse_header_key(state, acc \\ "")

  defp parse_header_key(%{data: <<": ", rest::binary>>} = state, acc) do
    parse_header_value(%{state | data: rest}, acc)
  end

  defp parse_header_key(%{data: <<head::binary-size(1), tail::binary>>} = state, acc) do
    parse_header_key(%{state | data: tail}, acc <> head)
  end

  defp parse_header_value(state, key, acc \\ "")

  defm parse_header_value(
         %{data: <<:__MATCH__, rest::binary>>, req_headers: headers} = state,
         key,
         val
       ),
       ["\n\r", "\r\n", "\n", "\r"] do
    key = String.downcase(key)
    val = String.downcase(val)
    new_state = Flux.HTTP.Headers.handle_header(state, key, val)
    # Move this into a callback variable passed in from Flux.HTTP that defaults to Headers

    %{new_state | data: rest, req_headers: [{key, val} | headers]}
    |> parse_headers()
  end

  defp parse_header_value(%{data: <<head::binary-size(1), tail::binary>>} = state, key, acc),
    do: parse_header_value(%{state | data: tail}, key, acc <> head)

  defm clear_newlines(%{data: <<:__MATCH__, rest::binary>>} = state), ["\n\r", "\r\n", "\n", "\r"] do
    clear_newlines(%{state | data: rest})
  end

  defp clear_newlines(state), do: state

  def parse_body(%{data: remaining} = state) do
    Map.put(state, :req_body, remaining)
  end
end
