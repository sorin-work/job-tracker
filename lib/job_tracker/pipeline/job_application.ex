defmodule JobTracker.Pipeline.JobApplication do
  @moduledoc """
  A job application: the role, the company and where it is in the pipeline.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias JobTracker.Pipeline.Status

  @work_modes [:onsite, :hybrid, :remote]
  @sources [:linkedin, :company_site, :referral, :recruiter, :job_board, :other]

  schema "job_applications" do
    field :title, :string
    field :status, Ecto.Enum, values: Status.all(), default: :wishlist
    field :location, :string
    field :work_mode, Ecto.Enum, values: @work_modes
    field :source, Ecto.Enum, values: @sources
    field :priority, :integer, default: 2
    field :posting_url, :string
    field :description, :string
    field :applied_on, :date
    field :salary_min, :integer
    field :salary_max, :integer
    field :salary_currency, :string, default: "USD"
    field :notes, :string
    field :position, :integer, default: 0

    field :company_name, :string, virtual: true

    belongs_to :user, JobTracker.Accounts.User
    belongs_to :company, JobTracker.Companies.Company

    has_many :status_changes, JobTracker.Pipeline.StatusChange,
      preload_order: [desc: :changed_at, desc: :id]

    timestamps(type: :utc_datetime)
  end

  def work_modes, do: @work_modes
  def sources, do: @sources

  @doc false
  def changeset(application, attrs) do
    application
    |> cast(attrs, [
      :title,
      :company_id,
      :company_name,
      :status,
      :location,
      :work_mode,
      :source,
      :priority,
      :posting_url,
      :description,
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
    |> validate_length(:description, max: 50_000)
    |> validate_inclusion(:priority, 1..3)
    |> validate_format(:posting_url, ~r/^https?:\/\/[^\s\/]+\.[^\s]+$/,
      message: "must be a valid URL"
    )
    |> validate_format(:salary_currency, ~r/^[A-Z]{3}$/,
      message: "must be a 3 letter code like USD"
    )
    |> validate_number(:salary_min, greater_than_or_equal_to: 0)
    |> validate_number(:salary_max, greater_than_or_equal_to: 0)
    |> validate_salary_range()
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

  defp validate_salary_range(changeset) do
    min = get_field(changeset, :salary_min)
    max = get_field(changeset, :salary_max)

    if min && max && min > max do
      add_error(changeset, :salary_max, "must be greater than or equal to the minimum")
    else
      changeset
    end
  end

  @doc """
  Changeset used when an application is dragged on the board.
  """
  def move_changeset(application, status, position) do
    change(application, status: status, position: position)
  end
end
