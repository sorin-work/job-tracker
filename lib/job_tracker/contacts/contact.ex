defmodule JobTracker.Contacts.Contact do
  @moduledoc """
  A person met during the search, optionally working at one of the companies.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "contacts" do
    field :name, :string
    field :title, :string
    field :email, :string
    field :phone, :string
    field :linkedin_url, :string
    field :notes, :string
    field :last_contacted_on, :date

    belongs_to :user, JobTracker.Accounts.User
    belongs_to :company, JobTracker.Companies.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :name,
      :title,
      :email,
      :phone,
      :linkedin_url,
      :notes,
      :last_contacted_on,
      :company_id
    ])
    |> validate_required([:name])
    |> validate_length(:name, max: 120)
    |> validate_length(:title, max: 120)
    |> validate_length(:email, max: 160)
    |> validate_format(:email, ~r/@/, message: "must be a valid email address")
    |> validate_format(:phone, ~r/^[0-9+()\-.\s]{5,30}$/, message: "must be a valid phone number")
    |> validate_format(:linkedin_url, ~r/^https?:\/\/[^\s\/]+\.[^\s]+$/,
      message: "must be a valid URL"
    )
    |> assoc_constraint(:company)
  end
end
