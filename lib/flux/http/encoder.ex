defmodule Flux.HTTP.Encoder do
  @moduledoc """
  The module for working with codings, and encoding bodies.
  """

  @supported_codings ~w(identity gzip *)

  @doc """
  Picks a coding to use from a list
  """
  def which_coding(codings) do
    codings
    |> Enum.reduce({nil, -1}, fn {coding, q1} = f, {_, q2} = acc ->
      if q1 > q2 and coding in @supported_codings, do: f, else: acc
    end)
    |> check_q()
  end

  defp check_q({nil, -1}), do: {:ok, "identity"}
  defp check_q({_, 0}), do: {:error, 406}
  defp check_q({coding, _}), do: {:ok, coding}

  def encode(coding, body) when coding in ["identity", "*"], do: {:ok, body}
  def encode("gzip", body), do: {:ok, :zlib.gzip(body)}
  def encode(_, _), do: {:error, 406}
end
