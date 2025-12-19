defmodule JobTrackerWeb.Format do
  @moduledoc """
  Formatting of dates, times and money for the templates.
  """

  alias JobTracker.TimeZones

  def date(nil), do: "—"
  def date(%Date{} = date), do: Calendar.strftime(date, "%b %-d, %Y")

  def short_date(nil), do: "—"
  def short_date(%Date{} = date), do: Calendar.strftime(date, "%b %-d")

  @doc """
  A UTC datetime shown in the user's time zone, e.g. "Tue, Mar 3 · 2:30 PM".
  """
  def datetime(nil, _user), do: "—"

  def datetime(%DateTime{} = datetime, user) do
    datetime |> TimeZones.to_local(user) |> Calendar.strftime("%a, %b %-d · %-I:%M %p")
  end

  def time(%DateTime{} = datetime, user) do
    datetime |> TimeZones.to_local(user) |> Calendar.strftime("%-I:%M %p")
  end

  def local_date(%DateTime{} = datetime, user) do
    datetime |> TimeZones.to_local(user) |> DateTime.to_date() |> date()
  end

  @doc """
  A salary range in a compact form: "$120k – $140k", "from €60k", "up to £80k".
  """
  def salary(nil, nil, _currency), do: nil
  def salary(min, nil, currency), do: "from " <> money(min, currency)
  def salary(nil, max, currency), do: "up to " <> money(max, currency)
  def salary(same, same, currency), do: money(same, currency)
  def salary(min, max, currency), do: money(min, currency) <> " – " <> money(max, currency)

  @symbols %{
    "USD" => "$",
    "EUR" => "€",
    "GBP" => "£",
    "CAD" => "CA$",
    "AUD" => "A$",
    "JPY" => "¥",
    "INR" => "₹"
  }

  def money(amount, currency) do
    number =
      cond do
        amount >= 1_000_000 -> trim_decimal(amount / 1_000_000) <> "M"
        amount >= 1_000 -> trim_decimal(amount / 1_000) <> "k"
        true -> Integer.to_string(amount)
      end

    case Map.fetch(@symbols, currency) do
      {:ok, symbol} -> symbol <> number
      :error -> number <> " " <> currency
    end
  end

  defp trim_decimal(value) do
    rounded = Float.round(value, 1)

    if rounded == Float.round(rounded),
      do: rounded |> trunc() |> Integer.to_string(),
      else: Float.to_string(rounded)
  end

  def label(nil), do: "—"
  def label(value) when is_atom(value), do: value |> Atom.to_string() |> label()

  def label(value) when is_binary(value),
    do: value |> String.replace("_", " ") |> String.capitalize()
end
