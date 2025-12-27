defmodule JobTracker.Pipeline.Tag do
  @moduledoc """
  A label for grouping applications, unique per user regardless of case.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @colors ~w(zinc red amber emerald sky indigo violet pink)

  schema "tags" do
    field :name, :string
    field :color, :string, default: "zinc"
    field :usage_count, :integer, virtual: true, default: 0

    belongs_to :user, JobTracker.Accounts.User

    many_to_many :job_applications, JobTracker.Pipeline.JobApplication,
      join_through: "job_application_tags"

    timestamps(type: :utc_datetime)
  end

  def colors, do: @colors

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :color])
    |> update_change(:name, &normalize_name/1)
    |> validate_required([:name, :color])
    |> validate_length(:name, max: 30)
    |> validate_format(:name, ~r/^[^,]+$/, message: "can't contain commas")
    |> validate_inclusion(:color, @colors)
    |> unique_constraint(:name,
      name: :tags_user_id_name_index,
      message: "you already have a tag with this name"
    )
  end

  @doc """
  Lowercases a tag name and collapses whitespace, so "Remote " and "remote"
  end up as the same tag.
  """
  def normalize_name(name) when is_binary(name) do
    name
    |> String.trim()
    |> String.downcase()
    |> String.replace(~r/\s+/, " ")
  end

  def normalize_name(name), do: name

  @doc """
  Splits a comma separated list of tag names, dropping blanks and duplicates.
  """
  def parse_names(nil), do: []

  def parse_names(text) when is_binary(text) do
    text
    |> String.split(",")
    |> Enum.map(&normalize_name/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end
end
