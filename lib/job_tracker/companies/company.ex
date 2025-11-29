defmodule JobTracker.Companies.Company do
  @moduledoc """
  A company the user applies to.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :website, :string
    field :industry, :string
    field :location, :string
    field :notes, :string

    belongs_to :user, JobTracker.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :website, :industry, :location, :notes])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> validate_length(:industry, max: 80)
    |> validate_length(:location, max: 120)
    |> validate_format(:website, ~r/^https?:\/\/[^\s\/]+\.[^\s]+$/,
      message: "must be a valid URL"
    )
    |> unique_constraint(:name,
      name: :companies_user_id_name_index,
      message: "you already have a company with this name"
    )
  end
end
