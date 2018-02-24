defmodule Flux.HTTP.Macros do
  defmacro defm(function_def, matches, do: logic) do
    for match <- matches do
      updated_def =
        Macro.postwalk(function_def, fn f ->
          if f == :__MATCH__, do: match, else: f
        end)

      quote do
        defp unquote(updated_def), do: unquote(logic)
      end
    end
  end
end
