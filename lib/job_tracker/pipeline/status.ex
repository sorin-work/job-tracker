defmodule JobTracker.Pipeline.Status do
  @moduledoc """
  The stages an application moves through.

  The first five are in the order an application normally progresses. The last
  three close an application: it was accepted, rejected or withdrawn.
  """

  @statuses [
    :wishlist,
    :applied,
    :screening,
    :interviewing,
    :offer,
    :accepted,
    :rejected,
    :withdrawn
  ]
  @progression [:wishlist, :applied, :screening, :interviewing, :offer, :accepted]
  @closed [:accepted, :rejected, :withdrawn]

  @labels %{
    wishlist: "Wishlist",
    applied: "Applied",
    screening: "Screening",
    interviewing: "Interviewing",
    offer: "Offer",
    accepted: "Accepted",
    rejected: "Rejected",
    withdrawn: "Withdrawn"
  }

  def all, do: @statuses
  def progression, do: @progression
  def closed, do: @closed
  def open, do: @statuses -- @closed

  def closed?(status), do: status in @closed

  def label(status) when is_binary(status), do: status |> cast!() |> label()
  def label(status), do: Map.fetch!(@labels, status)

  def options, do: Enum.map(@statuses, &{label(&1), &1})

  @doc """
  Position of a status along the normal progression, or nil for rejected and
  withdrawn which can happen at any point.
  """
  def rank(status), do: Enum.find_index(@progression, &(&1 == status))

  @doc """
  Casts a string from a form or a JS hook to a status atom, without creating
  new atoms.
  """
  def cast(value) when is_atom(value) and value in @statuses, do: {:ok, value}

  def cast(value) when is_binary(value) do
    case Enum.find(@statuses, &(Atom.to_string(&1) == value)) do
      nil -> :error
      status -> {:ok, status}
    end
  end

  def cast(_value), do: :error

  def cast!(value) do
    case cast(value) do
      {:ok, status} -> status
      :error -> raise ArgumentError, "unknown status: #{inspect(value)}"
    end
  end
end
