defmodule JobTracker.Pipeline.JobApplication do
  @moduledoc """
  A job application: the role, the company and where it is in the pipeline.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias JobTracker.Pipeline.Status

  schema "job_applications" do
    field :title, :string
    field :status, Ecto.Enum, values: Status.all(), default: :wishlist
    field :location, :string
    field :posting_url, :string
    field :applied_on, :date
    field :salary_min, :integer
    field :salary_max, :integer
    field :salary_currency, :string, default: "USD"
    field :notes, :string

    field :company_name, :string, virtual: true

    belongs_to :user, JobTracker.Accounts.User
    belongs_to :company, JobTracker.Companies.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(application, attrs) do
    application
    |> cast(attrs, [
      :title,
      :company_id,
      :company_name,
      :status,
      :location,
      :posting_url,
      :applied_on,
      :salary_min,
      :salary_max,
      :salary_currency,
      :notes
    ])
    |> validate_required([:title, :status, :salary_currency])
    |> validate_company()
    |> validate_length(:title, max: 160)
    |> validate_length(:location, max: 120)
    |> validate_format(:posting_url, ~r/^https?:\/\/[^\s\/]+\.[^\s]+$/,
      message: "must be a valid URL"
    )
    |> validate_format(:salary_currency, ~r/^[A-Z]{3}$/,
      message: "must be a 3 letter code like USD"
    )
    |> validate_number(:salary_min, greater_than_or_equal_to: 0)
    |> validate_number(:salary_max, greater_than_or_equal_to: 0)
    |> assoc_constraint(:company)
  end

  # An application needs a company, either picked from the list or typed in as
  # a new one. The context resolves `company_name` to a company before insert.
  defp validate_company(changeset) do
    if get_field(changeset, :company_id) || get_change(changeset, :company_name) do
      changeset
    else
      add_error(changeset, :company_id, "pick a company or type a new name")
    end
  end
end
