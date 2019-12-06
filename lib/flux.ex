defmodule Flux do
  @moduledoc """
  Documentation for Flux.
  """

  defdelegate start_link(opts), to: Flux.Supervisor
  defdelegate child_spec(opts), to: Flux.Supervisor
end
