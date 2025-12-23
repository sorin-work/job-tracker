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

    test "creates and attaches tags from a comma separated list", %{user: user} do
      existing = tag_fixture(user, name: "remote")

      application = application_fixture(user, tag_names: "remote, fintech")
      application = Pipeline.get_application!(user, application.id)

      assert Enum.map(application.tags, & &1.name) == ["fintech", "remote"]
      assert Enum.any?(application.tags, &(&1.id == existing.id))
      assert length(Pipeline.list_tags(user)) == 2
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

    test "keeps tags when tag names are not part of the update", %{user: user} do
      application = application_fixture(user, tag_names: "remote")
      application = Pipeline.get_application!(user, application.id)

      {:ok, _} = Pipeline.update_application(user, application, %{title: "Renamed"})
      assert [%{name: "remote"}] = Pipeline.get_application!(user, application.id).tags
    end

    test "replaces tags", %{user: user} do
      application = application_fixture(user, tag_names: "remote")
      application = Pipeline.get_application!(user, application.id)

      {:ok, _} = Pipeline.update_application(user, application, %{tag_names: "onsite"})
      assert [%{name: "onsite"}] = Pipeline.get_application!(user, application.id).tags
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

  describe "search_applications/2" do
    test "filters by status, open/closed, tag and text", %{user: user} do
      acme = company_fixture(user, name: "Acme")

      a =
        application_fixture(user,
          title: "Backend Engineer",
          status: :applied,
          company_id: acme.id
        )

      b =
        application_fixture(user,
          title: "Frontend Engineer",
          status: :rejected,
          tag_names: "remote"
        )

      _other = application_fixture(user_fixture(), title: "Backend Engineer")

      ids = fn params ->
        Pipeline.search_applications(user, params).entries |> Enum.map(& &1.id)
      end

      assert ids.(%{"status" => "applied"}) == [a.id]
      assert ids.(%{"status" => "closed"}) == [b.id]
      assert ids.(%{"status" => "open"}) == [a.id]
      assert ids.(%{"q" => "backend"}) == [a.id]
      assert ids.(%{"q" => "acme"}) == [a.id]
      assert ids.(%{"tag" => to_string(hd(Pipeline.list_tags(user)).id)}) == [b.id]
      assert length(ids.(%{"status" => "bogus"})) == 2
    end

    test "sorts by the given field", %{user: user} do
      b = application_fixture(user, title: "b role", salary_max: 100)
      a = application_fixture(user, title: "A role", salary_max: 300)
      c = application_fixture(user, title: "c role")

      ids = fn params ->
        Pipeline.search_applications(user, params).entries |> Enum.map(& &1.id)
      end

      assert ids.(%{"sort" => "title", "dir" => "asc"}) == [a.id, b.id, c.id]
      assert ids.(%{"sort" => "title", "dir" => "desc"}) == [c.id, b.id, a.id]
      assert ids.(%{"sort" => "salary", "dir" => "desc"}) == [a.id, b.id, c.id]
      assert ids.(%{"sort" => "status"}) |> length() == 3
      assert ids.(%{"sort" => "company", "q" => "role"}) |> length() == 3
    end

    test "paginates", %{user: user} do
      company = company_fixture(user)
      for _ <- 1..27, do: application_fixture(user, company_id: company.id)

      first = Pipeline.search_applications(user, %{})
      assert length(first.entries) == 25
      assert first.total == 27
      assert first.total_pages == 2

      second = Pipeline.search_applications(user, %{"page" => "2"})
      assert length(second.entries) == 2

      assert Pipeline.search_applications(user, %{"page" => "x"}).page == 1
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

  describe "tags" do
    test "list_tags/1 counts usage", %{user: user} do
      application_fixture(user, tag_names: "remote, fintech")
      application_fixture(user, tag_names: "remote")

      assert [%{name: "fintech", usage_count: 1}, %{name: "remote", usage_count: 2}] =
               Pipeline.list_tags(user)
    end

    test "update_tag/2 renames and recolors", %{user: user} do
      tag = tag_fixture(user, name: "remote")
      assert {:ok, tag} = Pipeline.update_tag(tag, %{name: "remote ok", color: "pink"})
      assert tag.name == "remote ok"
      assert tag.color == "pink"
    end

    test "tag names are unique per user", %{user: user} do
      tag_fixture(user, name: "remote")
      assert {:error, changeset} = Pipeline.create_tag(user, %{name: "Remote", color: "sky"})
      assert %{name: [_]} = errors_on(changeset)
    end

    test "delete_tag/1 removes it from applications", %{user: user} do
      application = application_fixture(user, tag_names: "remote")
      [tag] = Pipeline.list_tags(user)

      assert {:ok, _} = Pipeline.delete_tag(tag)
      assert Pipeline.get_application!(user, application.id).tags == []
    end
  end
end
