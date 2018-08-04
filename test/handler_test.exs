defmodule Flux.HandlerTest do
  use ExUnit.Case
  alias Flux.Handler

  test "child_spec/3 returns a child spec" do
    assert {Flux.Supervisor, {Flux.Supervisor, :start_link, [_ | _]}, :permanent, 5000, :worker,
            [Flux.Supervisor]} = Handler.child_spec(:http, nil, [])
  end
end
