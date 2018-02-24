defmodule Flux.HandlerTest do
  use ExUnit.Case
  alias Flux.Handler

  @valid_spec {Flux, {Flux, :start_link, [:http, nil, []]}, :permanent, 5000, :worker, [Flux]}
  test "child_spec/3 returns a child spec" do
    assert @valid_spec = Handler.child_spec(:http, nil, [])
  end
end
