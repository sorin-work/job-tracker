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

    test "keeps a given application date", %{user: user} do
      date = Date.add(Date.utc_today(), -10)
      application = application_fixture(user, status: :applied, applied_on: date)
      assert application.applied_on == date
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

      assert {:error, changeset} =
               Pipeline.update_application(user, application, %{salary_min: 10, salary_max: 5})

      assert %{salary_max: [_]} = errors_on(changeset)
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

  describe "move_application/4" do
    test "moves a card into another column at the given index", %{user: user} do
      a = application_fixture(user, status: :applied)
      b = application_fixture(user, status: :applied)
      card = application_fixture(user)

      assert {:ok, moved} = Pipeline.move_application(user, card.id, "applied", 1)
      assert moved.status == :applied
      assert moved.applied_on == Date.utc_today()

      ids = user |> Pipeline.board() |> Map.fetch!(:applied) |> Enum.map(& &1.id)
      assert ids == [a.id, card.id, b.id]
      assert history(card) == [{nil, :wishlist}, {:wishlist, :applied}]
    end

    test "reorders within a column without recording a status change", %{user: user} do
      a = application_fixture(user)
      b = application_fixture(user)
      c = application_fixture(user)

      assert {:ok, _} = Pipeline.move_application(user, c.id, "wishlist", 0)

      ids = user |> Pipeline.board() |> Map.fetch!(:wishlist) |> Enum.map(& &1.id)
      assert ids == [c.id, a.id, b.id]
      assert history(c) == [{nil, :wishlist}]
    end

    test "clamps the index to the column size", %{user: user} do
      a = application_fixture(user, status: :applied)
      card = application_fixture(user)

      assert {:ok, _} = Pipeline.move_application(user, to_string(card.id), "applied", 99)
      ids = user |> Pipeline.board() |> Map.fetch!(:applied) |> Enum.map(& &1.id)
      assert ids == [a.id, card.id]
    end

    test "rejects unknown statuses and other users' applications", %{user: user} do
      card = application_fixture(user)
      other = application_fixture(user_fixture())

      assert {:error, :invalid_status} = Pipeline.move_application(user, card.id, "hired", 0)
      assert {:error, :not_found} = Pipeline.move_application(user, other.id, "applied", 0)
    end
  end

  describe "board/2" do
    test "has a column for every status", %{user: user} do
      board = Pipeline.board(user)
      assert Map.keys(board) |> Enum.sort() == Enum.sort(JobTracker.Pipeline.Status.all())
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
