defmodule Flux.Application do
  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # {Flux.Handler, [scheme: :http, endpoint: nil, otp_app: :flux]}
    ]

    opts = [strategy: :one_for_one, name: Flux.Application]
    Supervisor.start_link(children, opts)
  end
end
