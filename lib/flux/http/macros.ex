defmodule Flux.HTTP.Macros do
  defmacro defmatch(function_def, do: logic) do
    for match <- ["\r\n", "\n", "\r"] do
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
