defmodule JobTrackerWeb.ApplicationLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "lists the user's applications", %{conn: conn, user: user} do
      application_fixture(user, title: "Backend Engineer", tag_names: "remote")
      application_fixture(JobTracker.AccountsFixtures.user_fixture(), title: "Someone else's job")

      {:ok, _lv, html} = live(conn, ~p"/applications")

      assert html =~ "Backend Engineer"
      assert html =~ "remote"
      refute html =~ "Someone else&#39;s job"
    end

    test "creates an application with a new company", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/applications/new")

      assert lv
             |> form("#application-form", job_application: %{title: ""})
             |> render_change() =~ "can&#39;t be blank"

      {:ok, _show, html} =
        lv
        |> form("#application-form",
          job_application: %{
            title: "Staff Engineer",
            company_name: "Brand New Co",
            status: "applied",
            salary_min: "150000",
            salary_max: "170000",
            tag_names: "remote, dream job",
            description: "We are hiring a staff engineer."
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert html =~ "Application added"
      assert html =~ "Staff Engineer"
      assert html =~ "Brand New Co"
      assert html =~ "$150k – $170k"
      assert html =~ "dream job"
    end

    test "shows validation errors from the context", %{conn: conn, user: user} do
      company = company_fixture(user)
      {:ok, lv, _html} = live(conn, ~p"/applications/new")

      html =
        lv
        |> form("#application-form",
          job_application: %{
            title: "Engineer",
            company_id: company.id,
            salary_min: "10",
            salary_max: "5"
          }
        )
        |> render_submit()

      assert html =~ "must be greater than or equal to the minimum"
    end
  end

  describe "Show" do
    setup %{user: user} do
      %{application: application_fixture(user, title: "Platform Engineer", status: :applied)}
    end

    test "displays the application with its timeline", %{conn: conn, application: application} do
      {:ok, lv, html} = live(conn, ~p"/applications/#{application}")

      assert html =~ "Platform Engineer"
      assert lv |> element("#timeline") |> render() =~ "Added as"
    end

    test "changes the status with a note", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}")

      html =
        lv
        |> form("#status-form", status: %{status: "screening", note: "Recruiter called"})
        |> render_submit()

      assert html =~ "Moved to Screening"
    end

    test "edits the application", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}/edit")

      html =
        lv
        |> form("#application-form", job_application: %{title: "Senior Platform Engineer"})
        |> render_submit()

      assert_patch(lv, ~p"/applications/#{application}")
      assert html =~ "Application updated"
      assert html =~ "Senior Platform Engineer"
    end
  end
end
