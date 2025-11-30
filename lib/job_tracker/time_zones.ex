defmodule JobTracker.TimeZones do
  @moduledoc """
  Helpers for working with the user's time zone.

  Times are stored in UTC. Anything the user sees or types, like interview
  times or what counts as "today" for reminders, goes through these functions.
  """

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
end
