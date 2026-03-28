defmodule JobTracker.Demo do
  @moduledoc """
  Demo account with a few months of realistic job search data.

  Dates are relative to the day the seed runs, so the dashboard always has
  something due today, a couple of overdue follow-ups and interviews coming up.
  """

  import Ecto.Query, warn: false

  alias JobTracker.Accounts
  alias JobTracker.Companies.Company
  alias JobTracker.Contacts.Contact
  alias JobTracker.Interviews.Interview
  alias JobTracker.Pipeline.{JobApplication, StatusChange, Tag}
  alias JobTracker.Reminders.Reminder
  alias JobTracker.Repo

  @email "demo@example.com"
  @password "demo-password"

  def email, do: @email
  def password, do: @password

  @companies [
    {"Northwind Labs", "https://northwind-labs.example.com", "Developer tools", "Remote (EU)"},
    {"Brightloop", "https://brightloop.example.com", "Fintech", "London"},
    {"Cobalt Health", "https://cobalthealth.example.com", "Healthcare", "Boston"},
    {"Harbor & Pine", "https://harborpine.example.com", "E-commerce", "Portland"},
    {"Quillstack", "https://quillstack.example.com", "Developer tools", "Remote (US)"},
    {"Meridian Freight", "https://meridianfreight.example.com", "Logistics", "Chicago"},
    {"Lumen Analytics", "https://lumenanalytics.example.com", "Data", "New York"},
    {"Saltwater Games", "https://saltwatergames.example.com", "Gaming", "Seattle"},
    {"Tandem Bank", "https://tandembank.example.com", "Fintech", "New York"},
    {"Fernway", "https://fernway.example.com", "Travel", "Remote"},
    {"Orbital Robotics", "https://orbitalrobotics.example.com", "Hardware", "Pittsburgh"},
    {"Kettle & Co", "https://kettleco.example.com", "Food delivery", "Austin"},
    {"Parcelpoint", "https://parcelpoint.example.com", "Logistics", "Remote (US)"},
    {"Greenfield Energy", "https://greenfieldenergy.example.com", "Energy", "Denver"},
    {"Atlas Learning", "https://atlaslearning.example.com", "Education", "Remote"},
    {"Redwood Security", "https://redwoodsecurity.example.com", "Security", "San Francisco"},
    {"Mosaic Media", "https://mosaicmedia.example.com", "Media", "Los Angeles"},
    {"Ledgerline", "https://ledgerline.example.com", "Fintech", "Toronto"},
    {"Plainsight", "https://plainsight.example.com", "Data", "Remote (US)"},
    {"Upstream Bio", "https://upstreambio.example.com", "Biotech", "San Diego"},
    {"Wavelength Audio", "https://wavelengthaudio.example.com", "Consumer", "Brooklyn"},
    {"Civic Stack", "https://civicstack.example.com", "Government tech", "Washington, DC"}
  ]

  @tags [
    {"remote", "emerald"},
    {"fintech", "indigo"},
    {"dream job", "pink"},
    {"referral", "amber"},
    {"startup", "violet"},
    {"backend", "sky"}
  ]

  # {company, title, path of statuses, days ago it was added, source, work mode, salary, tags}
  @applications [
    {"Northwind Labs", "Senior Backend Engineer",
     [:wishlist, :applied, :screening, :interviewing, :offer], 62, :referral, :remote,
     {150_000, 175_000}, ["remote", "backend", "referral", "dream job"]},
    {"Brightloop", "Platform Engineer", [:applied, :screening, :interviewing], 41, :linkedin,
     :hybrid, {120_000, 140_000}, ["fintech", "backend"]},
    {"Cobalt Health", "Software Engineer II", [:applied, :rejected], 75, :company_site, :onsite,
     {115_000, 130_000}, []},
    {"Harbor & Pine", "Full Stack Developer", [:applied], 9, :job_board, :remote,
     {100_000, 120_000}, ["remote"]},
    {"Quillstack", "Staff Engineer, Developer Experience", [:wishlist], 3, :linkedin, :remote,
     {180_000, 210_000}, ["remote", "dream job"]},
    {"Meridian Freight", "Backend Engineer", [:applied, :screening, :rejected], 54, :recruiter,
     :hybrid, {110_000, 125_000}, ["backend"]},
    {"Lumen Analytics", "Data Platform Engineer", [:applied, :screening, :interviewing], 33,
     :linkedin, :hybrid, {135_000, 155_000}, ["backend"]},
    {"Saltwater Games", "Gameplay Services Engineer", [:applied, :withdrawn], 70, :company_site,
     :onsite, nil, []},
    {"Tandem Bank", "Senior Software Engineer, Payments",
     [:applied, :screening, :interviewing, :rejected], 58, :recruiter, :hybrid,
     {160_000, 185_000}, ["fintech", "backend"]},
    {"Fernway", "Product Engineer", [:applied, :screening], 18, :referral, :remote,
     {125_000, 140_000}, ["remote", "startup", "referral"]},
    {"Orbital Robotics", "Software Engineer, Fleet", [:applied], 27, :job_board, :onsite, nil,
     []},
    {"Kettle & Co", "Backend Engineer", [:applied, :rejected], 47, :linkedin, :remote,
     {105_000, 120_000}, ["remote", "startup"]},
    {"Parcelpoint", "Senior Elixir Developer", [:applied, :screening, :interviewing], 22,
     :linkedin, :remote, {140_000, 160_000}, ["remote", "backend"]},
    {"Greenfield Energy", "Software Engineer", [:applied], 13, :company_site, :hybrid,
     {110_000, 130_000}, []},
    {"Atlas Learning", "Full Stack Engineer",
     [:applied, :screening, :interviewing, :offer, :accepted], 95, :referral, :remote,
     {120_000, 135_000}, ["remote", "referral"]},
    {"Redwood Security", "Backend Engineer, Detection", [:applied], 1, :linkedin, :hybrid,
     {150_000, 170_000}, ["backend"]},
    {"Mosaic Media", "Software Engineer, Video", [:wishlist], 11, :job_board, :onsite, nil, []},
    {"Ledgerline", "Senior Developer", [:applied, :screening, :withdrawn], 39, :recruiter,
     :remote, {130_000, 150_000}, ["fintech", "remote"]},
    {"Plainsight", "Analytics Engineer", [:applied, :rejected], 29, :job_board, :remote, nil,
     ["remote"]},
    {"Upstream Bio", "Software Engineer, Lab Systems", [:applied], 20, :company_site, :onsite,
     {125_000, 145_000}, []},
    {"Wavelength Audio", "Backend Developer", [:wishlist], 1, :other, :hybrid, nil, ["startup"]},
    {"Civic Stack", "Senior Software Engineer", [:applied, :screening], 15, :linkedin, :remote,
     {140_000, 155_000}, ["remote", "backend"]},
    {"Brightloop", "Senior Backend Engineer, Ledger", [:wishlist], 4, :linkedin, :hybrid,
     {140_000, 160_000}, ["fintech", "backend"]},
    {"Northwind Labs", "Engineering Manager", [:applied, :rejected], 88, :company_site, :remote,
     {170_000, 190_000}, ["remote"]},
    {"Lumen Analytics", "Backend Engineer, Ingestion", [:applied, :rejected], 81, :linkedin,
     :hybrid, {120_000, 140_000}, ["backend"]},
    {"Fernway", "Backend Engineer", [:applied, :rejected], 99, :job_board, :remote, nil,
     ["remote"]},
    {"Parcelpoint", "Software Engineer, Routing", [:applied], 104, :job_board, :remote, nil,
     ["remote"]},
    {"Kettle & Co", "Platform Engineer", [:applied, :screening, :rejected], 66, :recruiter,
     :remote, {115_000, 130_000}, ["remote"]},
    {"Tandem Bank", "Software Engineer, Fraud", [:applied], 36, :linkedin, :hybrid,
     {130_000, 150_000}, ["fintech"]},
    {"Quillstack", "Senior Software Engineer", [:applied, :screening, :interviewing, :rejected],
     84, :referral, :remote, {150_000, 170_000}, ["remote", "referral"]},
    {"Greenfield Energy", "Data Engineer", [:applied, :withdrawn], 50, :linkedin, :hybrid, nil,
     []},
    {"Civic Stack", "Backend Engineer", [:applied, :rejected], 92, :company_site, :remote, nil,
     ["remote"]},
    {"Harbor & Pine", "Senior Platform Engineer", [:applied, :screening], 7, :recruiter, :remote,
     {135_000, 150_000}, ["remote", "backend"]},
    {"Redwood Security", "Site Reliability Engineer", [:applied], 44, :job_board, :onsite, nil,
     []}
  ]

  @contacts [
    {"Northwind Labs", "Priya Raman", "Engineering Manager", "priya@northwind-labs.example.com",
     4},
    {"Northwind Labs", "Tom Becker", "Recruiter", "tom.becker@northwind-labs.example.com", 12},
    {"Brightloop", "Sofia Marin", "Technical Recruiter", "sofia@brightloop.example.com", 6},
    {"Lumen Analytics", "Daniel Okafor", "Senior Data Engineer",
     "d.okafor@lumenanalytics.example.com", 20},
    {"Tandem Bank", "Rachel Kim", "Talent Partner", "rachel.kim@tandembank.example.com", 30},
    {"Fernway", "Marcus Lee", "Staff Engineer", "marcus@fernway.example.com", 16},
    {"Parcelpoint", "Hannah Weiss", "Head of Engineering", "hannah@parcelpoint.example.com", 9},
    {"Atlas Learning", "Ines Duarte", "VP Engineering", "ines@atlaslearning.example.com", 40},
    {"Civic Stack", "Kofi Mensah", "Recruiting Coordinator", "kofi@civicstack.example.com", 13},
    {"Harbor & Pine", "Elena Petrova", "Recruiter", "elena@harborpine.example.com", 5},
    {"Quillstack", "Jonas Albers", "Engineering Lead", "jonas@quillstack.example.com", 60},
    {nil, "Alex Rivera", "Former colleague", "alex.rivera@example.com", 25},
    {nil, "Maya Chen", "Career coach", "maya.chen@example.com", 10}
  ]

  @doc """
  Creates the demo user and its data. Returns `{:error, :exists}` if the demo
  user is already there.
  """
  def seed do
    if Accounts.get_user_by_email(@email) do
      {:error, :exists}
    else
      Repo.transaction(fn -> seed_data() end)
    end
  end

  defp seed_data do
    {:ok, user} = Accounts.register_user(%{email: @email, password: @password})

    user =
      user
      |> Ecto.Changeset.change(
        confirmed_at: DateTime.utc_now(:second),
        time_zone: "America/New_York",
        weekly_goal: 5,
        follow_up_days: 7
      )
      |> Repo.update!()

    today = JobTracker.TimeZones.today(user)
    companies = insert_companies(user)
    tags = insert_tags(user)
    applications = insert_applications(user, companies, tags, today)
    insert_contacts(user, companies, today)
    insert_interviews(applications, today)
    insert_reminders(user, applications, today)
    user
  end

  defp insert_companies(user) do
    Map.new(@companies, fn {name, website, industry, location} ->
      company =
        Repo.insert!(%Company{
          user_id: user.id,
          name: name,
          website: website,
          industry: industry,
          location: location
        })

      {name, company}
    end)
  end

  defp insert_tags(user) do
    Map.new(@tags, fn {name, color} ->
      {name, Repo.insert!(%Tag{user_id: user.id, name: name, color: color})}
    end)
  end

  defp insert_applications(user, companies, tags, today) do
    @applications
    |> Enum.with_index()
    |> Enum.map(fn {{company, title, path, days_ago, source, mode, salary, tag_names}, index} ->
      company = Map.fetch!(companies, company)
      added_on = Date.add(today, -days_ago)
      {salary_min, salary_max} = salary || {nil, nil}
      steps = step_dates(path, added_on, today, index)
      status = List.last(path)
      updated_at = steps |> List.last() |> elem(1)

      application =
        Repo.insert!(%JobApplication{
          user_id: user.id,
          company_id: company.id,
          title: title,
          status: status,
          location: company.location,
          work_mode: mode,
          source: source,
          priority: priority(tag_names),
          posting_url: "#{company.website}/careers/#{slug(title)}",
          description: description(title, company),
          applied_on:
            if(:applied in path,
              do: Date.add(added_on, if(hd(path) == :wishlist, do: 2, else: 0))
            ),
          salary_min: salary_min,
          salary_max: salary_max,
          salary_currency: "USD",
          notes: notes(status),
          position: index,
          tags: Enum.map(tag_names, &Map.fetch!(tags, &1)),
          inserted_at: at(added_on, 19),
          updated_at: updated_at
        })

      steps
      |> Enum.with_index()
      |> Enum.each(fn {{to_status, changed_at}, i} ->
        Repo.insert!(%StatusChange{
          job_application_id: application.id,
          from_status: if(i > 0, do: steps |> Enum.at(i - 1) |> elem(0)),
          to_status: to_status,
          changed_at: changed_at,
          note: step_note(to_status),
          inserted_at: changed_at
        })
      end)

      %{application | company: company}
    end)
  end

  # Spreads the steps of a path between the day it was added and today, a bit
  # unevenly so the timeline doesn't look generated.
  defp step_dates([first | rest], added_on, today, index) do
    span = max(Date.diff(today, added_on) - 1, length(rest))
    gap = if rest == [], do: 0, else: div(span, length(rest) + 1)

    rest
    |> Enum.with_index(1)
    |> Enum.map(fn {status, i} ->
      jitter = rem(index * 7 + i * 3, max(div(gap, 3), 1))
      date = Date.add(added_on, min(i * gap + jitter, span))
      {status, at(date, 9 + rem(index + i, 9))}
    end)
    |> then(&[{first, at(added_on, 19)} | &1])
  end

  defp at(date, hour), do: DateTime.new!(date, Time.new!(hour, rem(hour * 7, 60), 0), "Etc/UTC")

  defp priority(tags) do
    cond do
      "dream job" in tags -> 3
      "referral" in tags -> 3
      tags == [] -> 1
      true -> 2
    end
  end

  defp slug(title) do
    title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end

  defp step_note(:screening), do: "Recruiter reached out by email"
  defp step_note(:rejected), do: "Polite rejection email"
  defp step_note(:offer), do: "Verbal offer, written offer to follow"
  defp step_note(:withdrawn), do: "Role no longer a fit"
  defp step_note(_), do: nil

  defp notes(:offer),
    do: "Negotiate start date and signing bonus. Ask about the on-call rotation."

  defp notes(:interviewing),
    do: "Team uses Elixir and Postgres. Ask about how projects get prioritized."

  defp notes(:rejected), do: "They went with someone with more domain experience."

  defp notes(:wishlist),
    do: "Wait for the new year headcount, the hiring manager posted about it."

  defp notes(_), do: nil

  defp description(title, company) do
    """
    #{company.name} is hiring a #{title} to join a small product team.

    What you'll do
    - Design, build and run services used by thousands of customers every day
    - Work closely with product and design to ship in small increments
    - Take part in code review, incident reviews and an on-call rotation shared across the team
    - Mentor other engineers and help shape how the team works

    What we're looking for
    - Several years of experience building web applications in production
    - Comfortable with relational databases and writing SQL by hand
    - Clear written communication, we work asynchronously across time zones
    - Experience with #{if company.industry == "Fintech", do: "payments or ledgers", else: "distributed systems"} is a plus

    Benefits include a learning budget, flexible hours and 25 days of paid time off.
    """
  end

  defp insert_contacts(user, companies, today) do
    Enum.each(@contacts, fn {company, name, title, email, days_ago} ->
      Repo.insert!(%Contact{
        user_id: user.id,
        company_id: company && Map.fetch!(companies, company).id,
        name: name,
        title: title,
        email: email,
        linkedin_url: "https://www.linkedin.com/in/#{slug(name)}",
        last_contacted_on: Date.add(today, -days_ago),
        notes: if(title =~ "Recruiter", do: "Prefers email over LinkedIn messages.")
      })
    end)
  end

  defp insert_interviews(applications, today) do
    by_title = Map.new(applications, &{{&1.company.name, &1.title}, &1})

    [
      {{"Northwind Labs", "Senior Backend Engineer"}, -40, 15, :phone_screen, :passed, 30},
      {{"Northwind Labs", "Senior Backend Engineer"}, -30, 16, :technical, :passed, 90},
      {{"Northwind Labs", "Senior Backend Engineer"}, -21, 14, :system_design, :passed, 60},
      {{"Northwind Labs", "Senior Backend Engineer"}, -14, 17, :final, :passed, 45},
      {{"Brightloop", "Platform Engineer"}, -20, 13, :recruiter, :passed, 30},
      {{"Brightloop", "Platform Engineer"}, -6, 15, :technical, :passed, 60},
      {{"Brightloop", "Platform Engineer"}, 2, 14, :onsite, :pending, 180},
      {{"Lumen Analytics", "Data Platform Engineer"}, -12, 16, :phone_screen, :passed, 30},
      {{"Lumen Analytics", "Data Platform Engineer"}, 0, 18, :technical, :pending, 75},
      {{"Parcelpoint", "Senior Elixir Developer"}, -9, 15, :recruiter, :passed, 30},
      {{"Parcelpoint", "Senior Elixir Developer"}, -3, 16, :take_home, :passed, 120},
      {{"Parcelpoint", "Senior Elixir Developer"}, 4, 17, :system_design, :pending, 60},
      {{"Tandem Bank", "Senior Software Engineer, Payments"}, -35, 14, :phone_screen, :passed,
       30},
      {{"Tandem Bank", "Senior Software Engineer, Payments"}, -25, 15, :technical, :failed, 60},
      {{"Quillstack", "Senior Software Engineer"}, -60, 16, :technical, :passed, 60},
      {{"Quillstack", "Senior Software Engineer"}, -52, 18, :behavioral, :failed, 45},
      {{"Fernway", "Product Engineer"}, 6, 15, :recruiter, :pending, 30},
      {{"Civic Stack", "Senior Software Engineer"}, 1, 16, :phone_screen, :pending, 30}
    ]
    |> Enum.each(fn {key, day, hour, kind, outcome, minutes} ->
      application = Map.fetch!(by_title, key)

      Repo.insert!(%Interview{
        job_application_id: application.id,
        scheduled_at: at(Date.add(today, day), hour),
        duration_minutes: minutes,
        kind: kind,
        outcome: outcome,
        location: if(kind == :onsite, do: application.company.location, else: "Google Meet"),
        interviewers: interviewers(kind),
        prep_notes: prep_notes(kind),
        feedback: feedback(outcome)
      })
    end)
  end

  defp interviewers(:recruiter), do: "Recruiter"
  defp interviewers(:phone_screen), do: "Hiring manager"
  defp interviewers(:onsite), do: "Four engineers and the hiring manager"
  defp interviewers(_), do: "Two senior engineers"

  defp prep_notes(:technical),
    do:
      "Practice SQL window functions and a rate limiter. Bring questions about their deploy process."

  defp prep_notes(:system_design),
    do: "Review queues, idempotency keys and how to shard a busy table. Draw the diagram first."

  defp prep_notes(:behavioral),
    do: "STAR stories: the migration project, the outage, mentoring the intern."

  defp prep_notes(:onsite), do: "Print the schedule. Lunch with the team at 12:30."
  defp prep_notes(_), do: "Have salary expectations ready. Ask about team size and remote policy."

  defp feedback(:passed), do: "Went well, good conversation about trade-offs."
  defp feedback(:failed), do: "Struggled with the second question, ran out of time."
  defp feedback(_), do: nil

  defp insert_reminders(user, applications, today) do
    by_company = Map.new(applications, &{&1.company.name, &1})

    [
      {"Harbor & Pine", "Follow up on the Full Stack Developer application", -3, false},
      {"Orbital Robotics", "Email the recruiter about next steps", -1, false},
      {"Northwind Labs", "Reply to the offer with questions about equity", 0, false},
      {"Greenfield Energy", "Follow up with Greenfield Energy", 0, false},
      {"Fernway", "Send thank-you note to Marcus", 2, false},
      {"Upstream Bio", "Follow up with Upstream Bio", 5, false},
      {nil, "Update the resume with the latest project", 9, false},
      {"Brightloop", "Send thank-you email after the technical interview", -5, true},
      {"Tandem Bank", "Ask Rachel for interview feedback", -18, true},
      {"Lumen Analytics", "Confirm interview time", -10, true}
    ]
    |> Enum.each(fn {company, title, day, done?} ->
      due_on = Date.add(today, day)

      Repo.insert!(%Reminder{
        user_id: user.id,
        job_application_id: company && Map.fetch!(by_company, company).id,
        title: title,
        due_on: due_on,
        completed_at: if(done?, do: at(due_on, 15))
      })
    end)
  end
end
