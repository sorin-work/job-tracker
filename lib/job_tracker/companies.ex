defmodule JobTracker.Companies do
  @moduledoc """
  Companies a user is applying to. Every function is scoped to a user.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts.User
  alias JobTracker.Companies.Company
  alias JobTracker.Pipeline.JobApplication
  alias JobTracker.Repo

  @doc """
  Lists the user's companies ordered by name, with the number of applications
  for each one in the virtual `:application_count` field.

  ## Options

    * `:search` - only companies whose name contains the given text
  """
  def list_companies(%User{id: user_id}, opts \\ []) do
    counts =
      from a in JobApplication,
        where: a.user_id == ^user_id,
        group_by: a.company_id,
        select: %{company_id: a.company_id, count: count(a.id)}

    Company
    |> where(user_id: ^user_id)
    |> filter_search(opts[:search])
    |> join(:left, [c], n in subquery(counts), on: n.company_id == c.id)
    |> order_by([c], asc: fragment("lower(?)", c.name))
    |> select([c, n], {c, coalesce(n.count, 0)})
    |> Repo.all()
    |> Enum.map(fn {company, count} -> Map.put(company, :application_count, count) end)
  end

  defp filter_search(query, search) when is_binary(search) and search != "" do
    pattern = "%" <> search <> "%"
    where(query, [c], ilike(c.name, ^pattern))
  end

  defp filter_search(query, _search), do: query

  @doc """
  Returns `{id, name}` pairs for select inputs.
  """
  def company_options(%User{id: user_id}) do
    Repo.all(
      from c in Company,
        where: c.user_id == ^user_id,
        order_by: c.name,
        select: {c.name, c.id}
    )
  end

  @doc """
  Gets one of the user's companies. Raises `Ecto.NoResultsError` if it does not
  exist or belongs to someone else.
  """
  def get_company!(%User{id: user_id}, id) do
    Repo.get_by!(Company, id: id, user_id: user_id)
  end

  @doc """
  Finds a company by name or creates it.
  """
  def find_or_create_company(%User{} = user, name) when is_binary(name) do
    name = String.trim(name)

    case Repo.get_by(Company, user_id: user.id, name: name) do
      nil -> create_company(user, %{name: name})
      company -> {:ok, company}
    end
  end

  def create_company(%User{} = user, attrs) do
    %Company{user_id: user.id}
    |> Company.changeset(attrs)
    |> Repo.insert()
  end

  def update_company(%Company{} = company, attrs) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a company. Companies that still have applications can't be deleted,
  the applications have to be moved or removed first.
  """
  def delete_company(%Company{} = company) do
    if Repo.exists?(from a in JobApplication, where: a.company_id == ^company.id) do
      {:error, :has_applications}
    else
      Repo.delete(company)
    end
  end

  def change_company(%Company{} = company, attrs \\ %{}) do
    Company.changeset(company, attrs)
  end
end
