defmodule JobTracker.TimeZones do
  @moduledoc """
  Helpers for working with the user's time zone.

  Times are stored in UTC. Anything the user sees or types, like interview
  times or what counts as "today" for reminders, goes through these functions.
  """

  alias JobTracker.Accounts.User

  @common ~w(
    Etc/UTC
    America/Los_Angeles
    America/Denver
    America/Chicago
    America/New_York
    America/Toronto
    America/Sao_Paulo
    Europe/London
    Europe/Dublin
    Europe/Lisbon
    Europe/Madrid
    Europe/Paris
    Europe/Berlin
    Europe/Amsterdam
    Europe/Warsaw
    Europe/Bucharest
    Europe/Athens
    Europe/Kyiv
    Asia/Dubai
    Asia/Kolkata
    Asia/Singapore
    Asia/Tokyo
    Australia/Sydney
    Pacific/Auckland
  )

  @doc """
  Time zones offered in the settings form, the common ones first.
  """
  def options do
    common = Enum.map(@common, &{label(&1), &1})
    rest = for zone <- Tzdata.zone_list(), zone not in @common, do: {label(zone), zone}
    common ++ [[key: "──────────", value: "", disabled: true] | rest]
  end

  defp label("Etc/UTC"), do: "UTC"
  defp label(zone), do: String.replace(zone, "_", " ")

  def zone(%User{time_zone: zone}) when is_binary(zone), do: zone
  def zone(_), do: "Etc/UTC"

  @doc """
  The current date where the user is.
  """
  def today(user), do: user |> now() |> DateTime.to_date()

  def now(user) do
    case DateTime.now(zone(user)) do
      {:ok, now} -> now
      {:error, _} -> DateTime.utc_now()
    end
  end

  @doc """
  Shifts a UTC datetime into the user's zone.
  """
  def to_local(nil, _user), do: nil

  def to_local(%DateTime{} = datetime, user) do
    case DateTime.shift_zone(datetime, zone(user)) do
      {:ok, local} -> local
      {:error, _} -> datetime
    end
  end

  @doc """
  Interprets a wall-clock time in the given zone and returns it in UTC.

  Times that fall in a daylight saving gap are moved forward to the first valid
  time, ambiguous times (the hour that repeats in autumn) use the earlier one.
  """
  def from_local(%NaiveDateTime{} = naive, zone) do
    result =
      case DateTime.from_naive(naive, zone) do
        {:ok, datetime} -> datetime
        {:ambiguous, first, _second} -> first
        {:gap, _before, just_after} -> just_after
        {:error, _} -> DateTime.from_naive!(naive, "Etc/UTC")
      end

    result |> DateTime.shift_zone!("Etc/UTC") |> DateTime.truncate(:second)
  end

  @doc """
  Monday of the week the date falls in.
  """
  def week_start(%Date{} = date), do: Date.beginning_of_week(date, :monday)
end
