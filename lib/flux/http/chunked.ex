defmodule Flux.HTTP.Chunked do
  @hexdigits ~w(1 2 3 4 5 6 7 8 9 0 a b c d e f A B C D E F)
  def read_chunked(
        %{content_length: cl, req_state: :chunk} = conn,
        length,
        read_length,
        read_timeout
      )
      when not is_nil(cl) do
    read_chunk(conn, cl, length, read_length, read_timeout, [])
  end

  def read_chunked(
        %{content_length: cl, req_state: :cr_chunk} = conn,
        length,
        read_length,
        read_timeout
      )
      when not is_nil(cl) do
    case read_clrf(conn, length, read_timeout) do
      {:ok, length} ->
        read_chunk(conn, cl, length, read_length, read_timeout, [])

      {:error, :zero_length_cr} ->
        {:more, conn, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(
        %{content_length: cl, req_state: :ext} = conn,
        length,
        read_length,
        read_timeout
      )
      when not is_nil(cl) do
    case ignore_chunk_extensions(conn, length, read_timeout) do
      {:ok, length} ->
        read_chunk(conn, cl, length, read_length, read_timeout, [])

      {:error, :zero_length_ext} ->
        {:more, conn, ""}

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_chunk}, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(%{req_state: :chunk_end} = conn, length, read_length, read_timeout) do
    read_chunk_ending(conn, length, read_length, read_timeout, [])
  end

  def read_chunked(%{req_state: :cr_size} = conn, length, read_length, read_timeout) do
    case read_clrf(conn, length, read_timeout) do
      {:ok, length} ->
        read_chunk_size(conn, length, read_length, read_timeout, [])

      {:error, :zero_length_cr} ->
        {:more, conn, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(%{req_state: :ext_end} = conn, length, _, read_timeout) do
    case ignore_chunk_extensions(conn, length, read_timeout) do
      {:ok, length} ->
        read_trailer(conn, length, read_timeout, [])

      {:error, :zero_length_ext} ->
        {:more, conn, ""}

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_end}, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(%{req_state: :cr_end} = conn, length, _, read_timeout) do
    case read_clrf(conn, length, read_timeout) do
      {:ok, length} ->
        read_trailer(conn, length, read_timeout, [])

      {:error, :zero_length_cr} ->
        {:more, conn, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(%{req_state: :cr_trailer} = conn, length, _, read_timeout) do
    case read_clrf(conn, length, read_timeout) do
      {:ok, _} ->
        {:ok, conn, ""}

      {:error, :zero_length_cr} ->
        {:more, conn, ""}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_chunked(%{req_state: {:trailer_key, key_buffer}} = conn, length, _, read_timeout) do
    read_trailer_key(conn, length, read_timeout, [], key_buffer)
  end

  def read_chunked(
        %{req_state: {:trailer_value, {key_buffer, key_value}}} = conn,
        length,
        _,
        read_timeout
      ) do
    read_trailer_value(conn, length, read_timeout, [], key_buffer, key_value)
  end

  def read_chunked(
        %{req_state: {:cr_trailer_value, {key_buffer, key_value}}} = conn,
        length,
        _,
        read_timeout
      ) do
    do_read_trailer_value({:ok, "\r"}, conn, length, read_timeout, [], key_buffer, key_value)
  end

  def read_chunked(%{content_length: cl} = conn, length, read_length, read_timeout)
      when not is_nil(cl) do
    read_chunk(conn, cl, length, read_length, read_timeout, [])
  end

  def read_chunked(conn, length, read_length, read_timeout) do
    read_chunk_size(conn, length, read_length, read_timeout, [])
  end

  defp read_chunk_size(conn, 0, _, _, buffer) do
    # nil state means start at the beginning, which would be reading chunk size
    {:more, %{conn | req_state: nil, content_length: nil}, IO.iodata_to_binary(buffer)}
  end

  defp read_chunk_size(conn, l, rl, timeout, buffer) do
    conn
    |> read_octet(timeout)
    |> parse_chunk_size(conn, l - 1, rl, timeout, buffer)
  end

  defp parse_chunk_size({:error, _} = error, _conn, _l, _, _timeout, _buffer), do: error

  defp parse_chunk_size({:ok, "0"}, conn, l, _rl, timeout, buffer) do
    case ignore_chunk_extensions(conn, l, timeout) do
      {:ok, _} ->
        read_trailer(conn, l, timeout, buffer)

      {:error, :zero_length_ext} ->
        {:more, %{conn | req_state: :ext_end, content_length: nil}, IO.iodata_to_binary(buffer)}

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_end, content_length: nil}, IO.iodata_to_binary(buffer)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_chunk_size({:ok, hexdigit}, conn, l, rl, timeout, buffer)
       when hexdigit in @hexdigits do
    {chunk_size, ""} = Integer.parse(hexdigit, 16)

    case ignore_chunk_extensions(conn, l, timeout) do
      {:ok, length} ->
        read_chunk(conn, chunk_size, length, rl, timeout, buffer)

      {:error, :zero_length_ext} ->
        {:more, %{conn | req_state: :ext, content_length: chunk_size},
         IO.iodata_to_binary(buffer)}

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_chunk, content_length: chunk_size},
         IO.iodata_to_binary(buffer)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp read_chunk(conn, 0, l, rl, timeout, buffer) do
    read_chunk_ending(conn, l, rl, timeout, buffer)
  end

  defp read_chunk(conn, chunk_size, 0, _, _, buffer) do
    {:more, %{conn | content_length: chunk_size, req_state: :chunk}, IO.iodata_to_binary(buffer)}
  end

  defp read_chunk(conn, chunk_size, l, rl, timeout, buffer) do
    case read_socket(conn, chunk_size, l, rl, timeout) do
      {:ok, chunk, read} ->
        read_chunk(conn, chunk_size - read, l - read, rl, timeout, [buffer | chunk])

      {:error, _} = error ->
        error
    end
  end

  defp read_chunk_ending(conn, 0, _, _, buffer) do
    {:more, %{conn | req_state: :chunk_end, content_length: nil}, IO.iodata_to_binary(buffer)}
  end

  defp read_chunk_ending(conn, l, rl, timeout, buffer) do
    conn
    |> read_clrf(l, timeout)
    |> case do
      {:ok, length} ->
        read_chunk_size(conn, length, rl, timeout, buffer)

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_size, content_length: nil}, IO.iodata_to_binary(buffer)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ignore_chunk_extensions(_, 0, _), do: {:error, :zero_length_ext}

  defp ignore_chunk_extensions(conn, l, timeout) do
    conn
    |> read_octet(timeout)
    |> do_ignore_chunk_extensions(conn, l - 1, timeout)
  end

  defp do_ignore_chunk_extensions({:error, _} = error, _conn, _l, _timeout), do: error

  defp do_ignore_chunk_extensions({:ok, "\r"}, conn, l, timeout) do
    read_clrf(conn, l, timeout)
  end

  defp do_ignore_chunk_extensions({:ok, _}, conn, l, timeout) do
    ignore_chunk_extensions(conn, l, timeout)
  end

  def read_clrf(_, 0, _), do: {:error, :zero_length_cr}

  def read_clrf(conn, l, timeout) do
    case read_octet(conn, timeout) do
      {:ok, "\r"} -> read_clrf(conn, l - 1, timeout)
      {:ok, "\n"} -> {:ok, l - 1}
      {:ok, _} -> {:error, :missing_carriage_return}
      {:error, _} = error -> error
    end
  end

  defp read_trailer(conn, l, timeout, buffer) do
    read_trailer_key(conn, l, timeout, buffer)
  end

  defp read_trailer_key(conn, l, timeout, buffer, key_buffer \\ [])

  defp read_trailer_key(conn, 0, _, buffer, key_buffer) do
    {:more, %{conn | req_state: {:trailer_key, key_buffer}}, IO.iodata_to_binary(buffer)}
  end

  defp read_trailer_key(conn, l, timeout, buffer, key_buffer) do
    conn
    |> read_octet(timeout)
    |> do_read_trailer_key(conn, l - 1, timeout, buffer, key_buffer)
  end

  defp do_read_trailer_key({:error, _} = error, _, _, _, _, _), do: error

  defp do_read_trailer_key({:ok, "\r"}, conn, l, timeout, buffer, _key_buffer) do
    case read_clrf(conn, l, timeout) do
      {:ok, _} ->
        {:ok, %{conn | req_state: nil, content_length: nil}, IO.iodata_to_binary(buffer)}

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: :cr_trailer, content_length: nil},
         IO.iodata_to_binary(buffer)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_read_trailer_key({:ok, ":"}, conn, l, timeout, buffer, key_buffer) do
    read_trailer_value(conn, l, timeout, buffer, key_buffer)
  end

  defp do_read_trailer_key({:ok, octet}, conn, l, timeout, buffer, key_buffer) do
    read_trailer_key(conn, l, timeout, buffer, [key_buffer | octet])
  end

  defp read_trailer_value(conn, l, timeout, buffer, key_buffer, value_buffer \\ [])

  defp read_trailer_value(conn, 0, _, buffer, key_buffer, value_buffer) do
    {:more, %{conn | req_state: {:trailer_value, {key_buffer, value_buffer}}},
     IO.iodata_to_binary(buffer)}
  end

  defp read_trailer_value(conn, l, timeout, buffer, key_buffer, value_buffer) do
    conn
    |> read_octet(timeout)
    |> do_read_trailer_value(conn, l - 1, timeout, buffer, key_buffer, value_buffer)
  end

  defp do_read_trailer_value({:error, _} = error, _, _, _, _, _, _), do: error

  defp do_read_trailer_value({:ok, "\r"}, conn, l, timeout, buffer, key_buffer, value_buffer) do
    case read_clrf(conn, l, timeout) do
      {:ok, length} ->
        handle_complete_trailer(conn, length, timeout, buffer, key_buffer, value_buffer)

      {:error, :zero_length_cr} ->
        {:more, %{conn | req_state: {:cr_trailer_value, {key_buffer, value_buffer}}},
         IO.iodata_to_binary(buffer)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_read_trailer_value({:ok, octet}, conn, l, timeout, buffer, key_buffer, value_buffer) do
    read_trailer_value(conn, l, timeout, buffer, key_buffer, [value_buffer | octet])
  end

  defp handle_complete_trailer(conn, l, timeout, buffer, key_buffer, value_buffer) do
    key = IO.iodata_to_binary(key_buffer)
    value = IO.iodata_to_binary(value_buffer)
    # Processing is optional so will not process for now until the Header module is better
    read_trailer(%{conn | req_headers: [{key, value} | conn.req_headers]}, l, timeout, buffer)

    # TODO MUST ignore trailers with transfer-encoding/Content-length keys
  end

  defp read_octet(conn, timeout) do
    do_read(conn, 1, timeout)
  end

  defp read_socket(conn, chunk_size, l, rl, timeout) do
    read_amount = determine_read_amount(chunk_size, l, rl)

    case do_read(conn, read_amount, timeout) do
      {:ok, packet} -> {:ok, packet, read_amount}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_read(conn, read_amount, timeout) do
    conn.transport.read(conn.socket, read_amount, timeout)
  end

  defp determine_read_amount(content_length, l, rl) do
    [content_length, l, rl] |> Enum.min()
  end
end
