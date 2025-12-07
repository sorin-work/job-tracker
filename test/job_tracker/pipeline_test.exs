defmodule JobTracker.PipelineTest do
  use JobTracker.DataCase, async: true

  import JobTracker.AccountsFixtures
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.{JobApplication, StatusChange}

  setup do
    %{user: user_fixture()}
  end

  defp history(application) do
    Repo.all(
      from s in StatusChange,
        where: s.job_application_id == ^application.id,
        order_by: s.id,
        select: {s.from_status, s.to_status}
    )
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
      assert history(application) == [{nil, :wishlist}]
    end

    test "creates the company from a typed name", %{user: user} do
      assert {:ok, application} =
               Pipeline.create_application(user, %{
                 title: "Engineer",
                 company_name: "Brand New Co"
               })

      assert application.company.name == "Brand New Co"
    end

    test "reuses an existing company when the typed name matches", %{user: user} do
      company = company_fixture(user, name: "Acme")

      assert {:ok, application} =
               Pipeline.create_application(user, %{title: "Engineer", company_name: "acme"})

      assert application.company_id == company.id
    end

    test "fills in the application date when created as applied", %{user: user} do
      application = application_fixture(user, status: :applied)
      assert application.applied_on == Date.utc_today()
    end

    test "puts new applications at the end of their column", %{user: user} do
      first = application_fixture(user)
      second = application_fixture(user)
      assert second.position == first.position + 1
    end
  end

  describe "update_application/3" do
    test "records a status change", %{user: user} do
      application = application_fixture(user)

      assert {:ok, updated} = Pipeline.update_application(user, application, %{status: "applied"})
      assert updated.status == :applied
      assert updated.applied_on == Date.utc_today()
      assert history(application) == [{nil, :wishlist}, {:wishlist, :applied}]
    end

    test "does not record anything when the status stays the same", %{user: user} do
      application = application_fixture(user)
      assert {:ok, _} = Pipeline.update_application(user, application, %{title: "Renamed"})
      assert history(application) == [{nil, :wishlist}]
    end

    test "returns errors", %{user: user} do
      application = application_fixture(user)

      assert {:error, changeset} = Pipeline.update_application(user, application, %{title: ""})
      assert %{title: [_]} = errors_on(changeset)
    end
  end

  describe "change_status/4" do
    test "moves the application and keeps the note in the history", %{user: user} do
      application = application_fixture(user, status: :applied)

      assert {:ok, application} =
               Pipeline.change_status(user, application, :screening, "Recruiter called")

      assert application.status == :screening

      assert %StatusChange{note: "Recruiter called", from_status: :applied} =
               Repo.one(from s in StatusChange, where: s.to_status == :screening)
    end

    test "is a no-op for the current status", %{user: user} do
      application = application_fixture(user)
      assert {:ok, _} = Pipeline.change_status(user, application, "wishlist")
      assert history(application) == [{nil, :wishlist}]
    end
  end

  test "timeline/1 lists status changes newest first", %{user: user} do
    application = application_fixture(user)
    {:ok, application} = Pipeline.change_status(user, application, :applied)

    application = Pipeline.get_application!(user, application.id)

    assert [%{type: :status, to: :applied}, %{type: :status, to: :wishlist}] =
             Pipeline.timeline(application)
  end

  test "delete_application/1 removes it with its history", %{user: user} do
    application = application_fixture(user)
    assert {:ok, _} = Pipeline.delete_application(application)
    assert Repo.aggregate(StatusChange, :count) == 0
  end
end
