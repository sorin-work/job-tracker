defmodule JobTracker.PipelineFixtures do
  @moduledoc """
  Test helpers for creating applications and tags.
  """

  import JobTracker.CompaniesFixtures

  def application_fixture(user, attrs \\ %{}) do
    attrs = Map.new(attrs)

    company_id =
      Map.get_lazy(attrs, :company_id, fn ->
        if Map.has_key?(attrs, :company_name), do: nil, else: company_fixture(user).id
      end)

    {:ok, application} =
      JobTracker.Pipeline.create_application(
        user,
        Enum.into(attrs, %{
          title: "Software Engineer",
          company_id: company_id,
          status: :wishlist,
          salary_currency: "USD"
        })
      )

    application
  end
end
