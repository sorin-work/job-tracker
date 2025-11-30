defmodule JobTracker.PipelineTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.JobApplication

  setup do
    %{user: user_fixture()}
  end

  describe "create_application/2" do
    test "creates an application and records the first status", %{user: user} do
      company = company_fixture(user)

      assert {:ok, %JobApplication{} = application} =
               Pipeline.create_application(user, %{
                 title: "Backend Engineer",
                 company_id: company.id
               })

      assert application.status == :wishlist
      assert application.applied_on == nil
    end

    test "creates the company from a typed name", %{user: user} do
      assert {:ok, application} =
               Pipeline.create_application(user, %{
                 title: "Engineer",
                 company_name: "Brand New Co"
               })

      assert application.company.name == "Brand New Co"
    end

    test "fills in the application date when created as applied", %{user: user} do
      application = application_fixture(user, status: :applied)
      assert application.applied_on == Date.utc_today()
    end
  end

  describe "update_application/3" do
    test "returns errors", %{user: user} do
      application = application_fixture(user)

      assert {:error, changeset} = Pipeline.update_application(user, application, %{title: ""})
      assert %{title: [_]} = errors_on(changeset)
    end
  end

  test "delete_application/1 removes it", %{user: user} do
    application = application_fixture(user)
    assert {:ok, _} = Pipeline.delete_application(application)
    assert_raise Ecto.NoResultsError, fn -> Pipeline.get_application!(user, application.id) end
  end
end
