defmodule JobTracker.Export do
  @moduledoc """
  CSV export of a user's applications.
  """

  alias JobTracker.Accounts.User
  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.Status

  @headers [
    "Title",
    "Company",
    "Status",
    "Applied on",
    "Location",
    "Work mode",
    "Source",
    "Salary min",
    "Salary max",
    "Currency",
    "Tags",
    "Posting URL",
    "Notes",
    "Last updated"
  ]

  @doc """
  Returns the CSV as iodata, one row per application.
  """
  def applications_csv(%User{} = user) do
    rows =
      user
      |> Pipeline.list_applications()
      |> Enum.map(fn application ->
        [
          application.title,
          application.company.name,
          Status.label(application.status),
          application.applied_on && Date.to_iso8601(application.applied_on),
          application.location,
          application.work_mode && Atom.to_string(application.work_mode),
          application.source && Atom.to_string(application.source),
          application.salary_min,
          application.salary_max,
          application.salary_currency,
          Enum.map_join(application.tags, ", ", & &1.name),
          application.posting_url,
          application.notes,
          DateTime.to_iso8601(application.updated_at)
        ]
      end)

    Enum.map([@headers | rows], &encode_row/1)
  end

  defp encode_row(fields), do: [Enum.map_intersperse(fields, ",", &encode_field/1), "\r\n"]

  @doc """
  Quotes a field when it contains a comma, a quote or a line break.
  """
  def encode_field(nil), do: ""
  def encode_field(value) when is_integer(value), do: Integer.to_string(value)

  def encode_field(value) when is_binary(value) do
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      ~s(") <> String.replace(value, ~s("), ~s("")) <> ~s(")
    else
      value
    end
  end
end
