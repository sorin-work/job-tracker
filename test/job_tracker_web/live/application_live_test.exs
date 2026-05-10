defmodule JobTrackerWeb.ApplicationLiveTest do
  use JobTrackerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import JobTracker.ActivityFixtures
  import JobTracker.CompaniesFixtures
  import JobTracker.PipelineFixtures

  alias JobTracker.Pipeline

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

    test "shows a hint when there are no applications", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/applications")
      assert html =~ "Add your first application"
    end

    test "filters by search text and status", %{conn: conn, user: user} do
      application_fixture(user, title: "Backend Engineer", status: :applied)
      application_fixture(user, title: "Designer", status: :wishlist)

      {:ok, lv, _html} = live(conn, ~p"/applications")

      html = lv |> form("#filters", filters: %{q: "backend"}) |> render_change()
      assert_patch(lv, ~p"/applications?q=backend")
      assert html =~ "Backend Engineer"
      refute html =~ "Designer"

      {:ok, _lv, html} = live(conn, ~p"/applications?status=wishlist")
      assert html =~ "Designer"
      refute html =~ "Backend Engineer"
    end

    test "sorts by a column", %{conn: conn, user: user} do
      application_fixture(user, title: "Alpha role")
      application_fixture(user, title: "Zulu role")

      {:ok, lv, _html} = live(conn, ~p"/applications?sort=title&dir=asc")
      html = lv |> element("#applications") |> render()
      assert :binary.match(html, "Alpha role") < :binary.match(html, "Zulu role")
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

    test "can't see another user's application", %{conn: conn} do
      other = application_fixture(JobTracker.AccountsFixtures.user_fixture())

      assert_raise Ecto.NoResultsError, fn -> live(conn, ~p"/applications/#{other}") end
    end

    test "changes the status with a note", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}")

      html =
        lv
        |> form("#status-form", status: %{status: "screening", note: "Recruiter called"})
        |> render_submit()

      assert html =~ "Moved to Screening"
      assert lv |> element("#timeline") |> render() =~ "Recruiter called"
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

    test "schedules and edits an interview", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}/interviews/new")

      html =
        lv
        |> form("#interview-form",
          interview: %{
            local_scheduled_at: "2030-05-04T10:00",
            kind: "technical",
            prep_notes: "Review SQL"
          }
        )
        |> render_submit()

      assert_patch(lv, ~p"/applications/#{application}")
      assert html =~ "Interview saved"
      assert lv |> element("#interviews") |> render() =~ "Review SQL"

      [interview] =
        Pipeline.get_application!(application_user(application), application.id).interviews

      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}/interviews/#{interview}/edit")

      lv |> form("#interview-form", interview: %{outcome: "passed"}) |> render_submit()
      assert lv |> element("#interview-#{interview.id}") |> render() =~ "Passed"
    end

    test "removes an interview", %{conn: conn, user: user, application: application} do
      interview = interview_fixture(user, application)
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}")

      lv |> element("#interview-#{interview.id} a", "Remove") |> render_click()
      refute has_element?(lv, "#interview-#{interview.id}")
    end

    test "adds reminders and follow-ups", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}/reminders/new")

      lv
      |> form("#reminder-form", reminder: %{title: "Ask for feedback", due_on: Date.utc_today()})
      |> render_submit()

      assert lv |> element("#reminders") |> render() =~ "Ask for feedback"

      lv |> element("#reminders button", "7 days") |> render_click()
      assert lv |> element("#reminders") |> render() =~ "Follow up with"
    end

    test "completes a reminder", %{conn: conn, user: user, application: application} do
      reminder = reminder_fixture(user, job_application_id: application.id)
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}")

      lv |> element("#reminder-#{reminder.id} input") |> render_click()
      assert JobTracker.Reminders.get_reminder!(user, reminder.id).completed_at
    end

    test "deletes the application", %{conn: conn, application: application} do
      {:ok, lv, _html} = live(conn, ~p"/applications/#{application}")

      {:ok, _lv, html} =
        lv
        |> element("button", "Delete application")
        |> render_click()
        |> follow_redirect(conn, ~p"/applications")

      assert html =~ "Application deleted"
    end
  end

  defp application_user(application), do: JobTracker.Accounts.get_user!(application.user_id)
end
