defmodule Flux.Date do
  def now, do: format(DateTime.utc_now())

  def format(date) do
    [
      "Date: ",
      day_of_week(date),
      ", ",
      ljust(date.day),
      " ",
      month_to_string(date.month),
      " ",
      "#{date.year}",
      " ",
      ljust(date.hour),
      ":",
      ljust(date.minute),
      ":",
      ljust(date.second),
      " GMT"
    ]
  end

  defp day_of_week(date) do
    date
    |> Date.day_of_week()
    |> day_to_string()
  end

  days_of_week = [
    {1, "Mon"},
    {2, "Tue"},
    {3, "Wed"},
    {4, "Thu"},
    {5, "Fri"},
    {6, "Sat"},
    {7, "Sun"}
  ]

  for {num, day} <- days_of_week do
    defp day_to_string(unquote(num)), do: unquote(day)
  end

  months = [
    {1, "Jan"},
    {2, "Feb"},
    {3, "Mar"},
    {4, "Apr"},
    {5, "May"},
    {6, "Jun"},
    {7, "Jul"},
    {8, "Aug"},
    {9, "Sep"},
    {10, "Oct"},
    {11, "Nov"},
    {12, "Dec"}
  ]

  for {num, month} <- months do
    defp month_to_string(unquote(num)), do: unquote(month)
  end

  defp ljust(num) when is_integer(num), do: ljust("#{num}")

  defp ljust(<<digit::binary-size(1)>>) do
    ["0", digit]
  end

  defp ljust(digit) do
    digit
  end
end
