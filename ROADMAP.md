# Roadmap

Things I might add to job-tracker. The app covers a whole job search today
(pipeline, board, table, interviews, reminders, contacts, stats), so nothing
here is promised or scheduled. These are ideas, written down with enough detail
that I (or anyone else) can pick one up later without starting from zero. Items
may change, move between groups or be dropped.

What the app does today is in the [README](README.md) and the
[CHANGELOG](CHANGELOG.md).

- **Next**: small or well understood. I would start with these.
- **Later**: worth doing, but bigger or waiting on a decision.
- **Maybe**: not sure yet that they are worth the extra complexity.

Sizes are rough: **S** is an evening or two, **M** a few evenings up to a
couple of weekends, **L** several weeks of spare time.

Each item is meant to fit in one pull request and to be covered by the test
suite. There are two levels of tests and no browser tests: context tests under
`test/job_tracker` call the contexts against PostgreSQL (through the SQL
sandbox), and LiveView tests under `test/job_tracker_web/live` drive the pages
with `Phoenix.LiveViewTest`. So rules worth testing belong in a context under
`lib/job_tracker`, and plain arithmetic in a pure module like
`Stats.Calculations`, not inside a LiveView. Most items add columns, and each
brings its own migration under `priv/repo/migrations`. The only JavaScript is
the board hook in `assets/js/hooks/board.js`, and it has no tests. File names
below are relative to `lib/` unless they start with `priv/`, `test/`,
`assets/`, `config/` or `rel/`.

When an item ships, its Overview row says **Shipped** in the Group column, its
section moves under a `## Shipped` heading at the end with one paragraph on
what was built and what was left out, and the same pull request updates the
README, any notes it touches and an `## Unreleased` entry at the top of
`CHANGELOG.md`.

"Depends on" lists real prerequisites only. Items that merely touch the same
file are not listed there; the bigger overlaps are mentioned in the items.

## Overview

| #   | Item                                           | Group | Area          | Size | Depends on |
| --- | ---------------------------------------------- | ----- | ------------- | ---- | ---------- |
| 1   | Long status notes no longer fail               | Next  | pipeline      | S    | -          |
| 2   | Real email delivery                            | Next  | ops           | S    | -          |
| 3   | Rate limits on login and reset                 | Next  | security      | S    | -          |
| 4   | Scheduled backups                              | Next  | ops           | S    | -          |
| 5   | Backdated and corrected status changes         | Next  | pipeline      | M    | -          |
| 6   | Keyboard and screen reader access to the board | Later | ui            | M    | -          |
| 7   | Security headers and HTTPS settings            | Later | security      | S    | -          |
| 8   | Account deletion and a full export             | Later | accounts      | M    | -          |
| 9   | CSV import                                     | Later | import/export | M    | -          |
| 10  | More filters and saved views in the table      | Later | table         | S    | -          |
| 11  | Bulk actions in the table                      | Later | table         | M    | -          |
| 12  | Full text search                               | Later | search        | M    | -          |
| 13  | Duplicate warning when adding an application   | Later | pipeline      | S    | -          |
| 14  | Ghosted applications                           | Later | pipeline      | S    | -          |
| 15  | Archive and a board cutoff you can set         | Later | board         | S    | -          |
| 16  | Calendar feed for interviews and reminders     | Later | interviews    | M    | -          |
| 17  | Email digest of what is due                    | Later | reminders     | M    | 2          |
| 18  | Contacts linked to applications and interviews | Later | contacts      | M    | -          |
| 19  | Contact interaction log                        | Later | contacts      | M    | 18         |
| 20  | Offer details and comparison                   | Later | offers        | M    | -          |
| 21  | Salary periods and currencies                  | Later | pipeline      | S    | -          |
| 22  | Resume and cover letter versions               | Later | documents     | M    | -          |
| 23  | Save a posting from the browser                | Later | pipeline      | S    | -          |
| 24  | Time in stage and better stats periods         | Later | stats         | M    | -          |
| 25  | Live updates across tabs                       | Later | ui            | S    | -          |
| 26  | Sessions list and log out everywhere           | Later | accounts      | S    | -          |
| 27  | Two-factor authentication                      | Later | security      | M    | 26         |
| 28  | Metrics and an admin dashboard                 | Later | ops           | M    | -          |
| 29  | Upgrade and rollback notes                     | Later | ops           | S    | 4          |
| 30  | Board and stats at a few thousand applications | Later | performance   | M    | -          |
| 31  | Board on a phone                               | Later | ui            | M    | 6          |
| 32  | Fetch the job description from the posting     | Maybe | pipeline      | M    | -          |
| 33  | Interview prep checklists                      | Maybe | interviews    | M    | -          |
| 34  | Read-only share link for a mentor              | Maybe | sharing       | M    | -          |
| 35  | Custom stages                                  | Maybe | pipeline      | L    | -          |
| 36  | Several searches in one account                | Maybe | pipeline      | L    | -          |
| 37  | Browser tests for drag and drop                | Maybe | tests         | M    | -          |

## Next

### 1. Long status notes no longer fail

The status panel on the application page has a free text "Note (optional)"
field with no length limit in the form. `Pipeline.change_status/4` hands the
note to `record_status_change/4`, which inserts a bare `%StatusChange{}` struct
with `repo.insert/1`, so the `validate_length(:note, max: 255)` in
`StatusChange.changeset/2` never runs. The column is a `varchar(255)`
(`add :note, :string`), so a note of 256 characters fails at the database
instead of in a changeset, and the user gets an error instead of a message on
the field. Notes like "Recruiter called, said the team is reorganising, will
come back in two weeks, salary band is..." reach that length easily.

- Migration: change `status_changes.note` to `:text`. A note is the only
  free text on the timeline, and there is no reason to cap it at 255.
- Build the row through `StatusChange.changeset/2` in `record_status_change/4`
  and in `insert_application/3`, with a generous limit (say 2,000
  characters), so a too long note comes back as `{:error, changeset}`.
- `ApplicationLive.Show`: keep the typed note on error and show the message
  under the field instead of the generic "Could not change the status" flash.
  Turn the input into a small textarea with `maxlength`.
- Tricky: the board move path calls `record_status_change/4` too, without a
  note. It must keep working unchanged.
- Tests: in `test/job_tracker/pipeline_test.exs`, a 1,000 character note is
  stored and a 2,001 character one is refused; in
  `test/job_tracker_web/live/application_live_test.exs`, the error shows on
  the form and the status is unchanged.

### 2. Real email delivery

In production `config/runtime.exs` sets the mailer to `Swoosh.Adapters.Logger`.
Confirmation links, password resets and email changes are written to the log
and never sent. On the Docker setup that means a user who forgets their
password has to ask whoever runs the server to read `docker compose logs`.

- Read `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`,
  `SMTP_TLS` (`always`, `if_available`, `never`) and `MAIL_FROM` in
  `config/runtime.exs`. When `SMTP_HOST` is set, use `Swoosh.Adapters.SMTP`
  (adds `gen_smtp`); otherwise keep the logger, as today.
- `Accounts.UserNotifier` sends from the hard coded `contact@example.com`. Take
  the address from config.
- Compose: add a `mailpit` service with its web UI on `MAILPIT_UI_PORT`
  (pick a default that no sibling repo on the same machine uses) and point the
  app at it by default, so the confirmation flow can be tried locally without
  a real relay.
- README: the new variables in the configuration table, and how to use a real
  relay.
- Tricky: Swoosh delivers inside the LiveView process today. With a real relay
  a slow server blocks the registration form. `Task.Supervisor` with a short
  timeout is enough; a job queue is not needed yet (but see 17).
- Tests: the notifier tests already use `Swoosh.Adapters.Test`. Add one that
  checks the from address comes from config. The SMTP adapter itself is not
  tested.

### 3. Rate limits on login and reset

`UserSessionController.create/3` checks the password as often as it is asked.
Bcrypt makes each guess slow but does not stop a script, and the password
reset and confirmation forms send an email on every submit. Nothing in the app
limits any of it.

- A small `JobTrackerWeb.RateLimit` on an ETS table owned by a GenServer in
  the supervision tree, with fixed windows: for example 10 failed logins per
  email per 15 minutes and 30 per IP, and 3 reset or confirmation emails per
  address per hour. The Hammer library would do the same; ETS keeps the
  dependency list short and the app runs as one node.
- Over the limit, login shows the same "Invalid email or password" text plus
  a "try again in a few minutes" line, so it does not tell whether the address
  exists. Reset and confirmation keep their "if your email is in our system"
  message and just do not send.
- Tricky: behind a reverse proxy every request comes from the proxy's IP.
  Read `X-Forwarded-For` only when a `TRUSTED_PROXIES` setting says so, and
  say in the README that the per IP limit is off otherwise.
- Tricky: the window state is lost on restart, which is fine for this.
- Tests: the limiter as a unit (window rolls over, keys are separate) and one
  controller test that the 11th failed login is refused even with the right
  password.

### 4. Scheduled backups

The whole search lives in the `db-data` volume. `docker compose down -v`, as
the README suggests for starting over, deletes it with no copy anywhere, and
there is no documented way to back up or restore.

- A `backup` service in `docker-compose.yml` using the same `postgres:17-alpine`
  image, running `pg_dump --format=custom` on a schedule (a shell loop with
  `sleep` is enough, no cron image) into a `./backups` bind mount, keeping
  the last 14 by default (`BACKUP_KEEP`, `BACKUP_INTERVAL_HOURS`).
- A `scripts/restore.sh` that stops the app, restores a chosen dump with
  `pg_restore --clean --if-exists` and starts the app again.
- README: a Backups section, and a warning next to `docker compose down -v`.
- Tricky: a dump taken while a migration runs. The entrypoint runs migrations
  before the server starts; the backup service can wait for the app's
  healthcheck before its first run.
- Undecided: whether to also offer a per user export (item 8) as the answer
  for people running it only for themselves. They solve different problems; I
  would do both.
- Tests: none in ExUnit. A CI step that starts the compose stack, takes one
  dump and restores it into a fresh database would be the real test; it can
  run in the existing `docker` job.

### 5. Backdated and corrected status changes

Every status change is stamped `DateTime.utc_now/1`. People rarely update the
tracker the moment something happens: "rejected last Tuesday" is entered
today, and an application found in an old spreadsheet is created as applied
with today as its history. The stats are built entirely from `status_changes`
(`Stats.histories/2`), so "average time to first response" and the weekly
chart are off by however late the user was. A wrong drag on the board also
leaves a permanent entry: moving a card to Offer by mistake and back counts it
as an offer in the funnel forever.

- The status form on the application page gets a "When" date (default today,
  in the user's time zone, not in the future, not before the previous change).
  Stored as noon of that day in the user's zone, converted to UTC, like
  interviews.
- Each status entry on the timeline gets edit (date and note) and delete. A
  new `Pipeline.update_status_change/3` and `Pipeline.delete_status_change/2`,
  both checking the application belongs to the user.
- Deleting the latest entry moves the application back to the previous
  status. Deleting the only entry is not allowed.
- `applied_on` is set the first time an application moves past the wishlist
  (`maybe_set_applied_on/3`). When that first move is backdated, `applied_on`
  should follow it, unless the user typed `applied_on` by hand.
- Tricky: `from_status` is stored on each row. Deleting a middle entry leaves
  the next row's `from_status` pointing at a status the application never
  left. Either recompute `from_status` for the following row in the same
  transaction or drop the column and derive it when reading; recomputing is
  the smaller change.
- Tricky: two entries on the same day keep their order by `id`, which the
  timeline and `Stats.histories/2` already use as the tie breaker.
- Tests: context tests for backdating, the ordering rule, delete with
  recompute and the "only entry" refusal; a `Stats.Calculations` test showing
  a backdated rejection changes the average days to response.

## Later

### 6. Keyboard and screen reader access to the board

Moving a card on the board needs a mouse: the hook uses the native HTML5 drag
events, cards are `draggable` list items with a link inside, and there is no
other way to reorder within a column. Status can be changed from the
application page, but reordering cannot be done at all without dragging.

- A "Move" button on each card (visible on focus and hover) that opens a small
  menu: the other columns, plus "Move up" and "Move down". It sends the same
  `move` event the hook sends, so the server side does not change.
- An `aria-live` region on the board that says "Moved Senior Backend Engineer
  to Interviewing, position 2 of 4" after a move.
- Columns as labelled regions, the count in the heading read as "3
  applications".
- Check colour contrast of the status badges and tag colours in
  `components/app_components.ex`, and that focus rings are visible on every
  page.
- Tests: LiveView tests that the menu sends the move and that the live region
  text is rendered.

### 7. Security headers and HTTPS settings

`put_secure_browser_headers` adds the Phoenix defaults but no
Content-Security-Policy, and the HTTPS hints in `config/runtime.exs` are
commented out. Behind a TLS proxy the app does not know it is on HTTPS, so
cookies are not marked secure.

- A CSP set in the router's `:browser` pipeline: `default-src 'self'`, the
  LiveView websocket in `connect-src`, no inline scripts (the root layout
  only loads `app.js`, so none are needed).
- `FORCE_SSL=true` turns on `force_ssl` with HSTS and
  `rewrite_on: [:x_forwarded_proto]` for the proxy case. Off by default so the
  local Docker setup on plain HTTP keeps working.
- Session and remember me cookies `secure: true` when `PHX_SCHEME` is https.
- Tests: a conn test for the CSP header.

### 8. Account deletion and a full export

There is no way to delete an account, and the only export is the applications
CSV, which leaves out the timeline, interviews, reminders, contacts and
companies.

- Settings gets "Download all my data": a zip (`:zip` from Erlang, no
  dependency) with one JSON file per table, everything scoped to the user,
  plus the existing CSV.
- Settings gets "Delete my account", asking for the current password. The
  foreign keys already cascade from `users` (`on_delete: :delete_all`) except
  `job_applications.company_id`, which is `:restrict`, so delete
  applications before companies in one transaction.
- Log out every session of the user afterwards (tokens go with the user row).
- The demo account should not be deletable on a shared demo server, or it
  should be recreated on the next start (the entrypoint already reseeds only
  when it is missing).
- Tests: the export contains every table and nothing from another user;
  delete removes everything and the email can register again.

### 9. CSV import

People usually start using a tracker in the middle of a search, with a
spreadsheet of thirty applications already sent.

- An import page: upload a CSV (`allow_upload` in LiveView), map columns to
  fields with sensible guesses from the header (the export's own headers map
  one to one), preview the first rows with errors, then import.
- Rows go through `Pipeline.create_application/2`, so companies are found or
  created by name and tags are created as typed. One transaction for the whole
  file, or nothing.
- Status from the file is created as the only history entry, dated
  `applied_on` when there is one (needs the backdating rule from 5 to be
  honest, but works without it).
- Tricky: the export prefixes cells starting with `=`, `+`, `-` or `@` with
  `'` (`Export.encode_field/1`). The import should strip that prefix again so a
  round trip is lossless.
- Tricky: dates come in many formats. Accept ISO dates and say so; anything
  else is an error on that row in the preview.
- Undecided: whether to support the exports of other trackers. Their columns
  change; the column mapping step covers them well enough.
- Tests: a parsing module that is pure (header guesses, row validation) with
  unit tests, and a LiveView test for the upload and import.

### 10. More filters and saved views in the table

The table filters by search text, status and tag only (`@filter_keys` in
`ApplicationLive.Index`). `Pipeline.search_applications/2` already accepts a
company, but the page has no control for it. Work mode, source, priority and
the applied date range are columns people want to slice by.

- Add company, work mode, source, priority and applied from/to to the filter
  form and to `search_applications/2`. Unknown values fall back to no filter,
  as today.
- "Save this view": a name and the current query string, stored in a
  `saved_views` table, listed above the table. No sharing.
- Tests: context tests for each filter; a LiveView test that a saved view
  restores the filters.

### 11. Bulk actions in the table

Closing ten stale applications as withdrawn means ten visits to ten pages.

- Checkboxes on the table rows and "select all on this page", with actions:
  change status (with one note for all), add tag, remove tag, delete.
- Each status change still writes its own `status_changes` row, so the stats
  stay right. All in one transaction.
- Tricky: the selection should survive paging or be cleared on purpose. I
  would clear it on page change and say so.
- Tests: context function for the bulk status change; LiveView test for the
  selection and confirm step.

### 12. Full text search

The search box matches the title and company name with `ILIKE`
(`filter_search/2`). Notes, the saved job description, interview prep notes
and contacts are not searched, and the description is where the useful words
are ("Kafka", "visa sponsorship").

- A generated `tsvector` column on `job_applications` over title, location,
  notes and description, with a GIN index. Company name joins in as today.
- Search results rank by `ts_rank` when there is a query and the user has not
  picked another sort.
- A global search in the navigation that also covers contacts, companies and
  interview notes, grouped by type.
- Tricky: the `simple` text configuration is the safe default for mixed
  language postings; stemming in English helps English users only.
- Tests: context tests for matches in each field and for scoping to the user.

### 13. Duplicate warning when adding an application

Applying twice to the same role happens when there are many open tabs, and
recruiters notice.

- When the form has a company and a title, or a posting URL, look for an
  existing application with the same posting URL, or the same company and a
  similar title (`lower(title)` equal after trimming, or trigram similarity if
  `pg_trgm` is added).
- Show a warning with a link to the existing one; saving is still allowed.
- Tests: context function for the matching; LiveView test for the warning.

### 14. Ghosted applications

Most applications never get an answer. Today they stay in Applied for ever,
and the response rate treats them the same as ones sent yesterday.

- A setting "Mark as ghosted after N days without a response" (off by
  default). An application in Applied with no change for N days shows a
  "No response for 34 days" badge on the board and the table, and a
  suggestion on the dashboard to withdraw it or follow up.
- Not a new status: a derived flag from `updated_at` and the last status
  change, so nothing moves without the user doing it.
- Stats: show how many applications are still waiting and exclude those
  younger than N days from the response rate denominator, as a toggle.
- Tests: pure function for the flag in `Stats.Calculations` or a small
  module; a context test for the dashboard list.

### 15. Archive and a board cutoff you can set

Closed applications drop off the board 30 days after their last change, a
number hard coded in `Pipeline.board/2`. Some people want them gone at once,
others want a month of rejections visible.

- A preference for the cutoff (0 to 365 days), next to the weekly goal.
- An explicit "Archive" action that hides any application, open or closed,
  from the board and the default table view, with "Show archived" in the
  table. An `archived_at` column.
- Tests: board query with the preference; archive and unarchive.

### 16. Calendar feed for interviews and reminders

Interviews are the one thing people need in their real calendar, and today
they have to copy them over by hand.

- A secret feed URL per user (`/calendar/<token>.ics`) serving interviews as
  events and open reminders as all day events, in iCalendar format written by
  hand (the format is small enough; no library needed).
- Settings shows the URL with "copy" and "reset". The token is stored hashed,
  like session tokens.
- A "Download .ics" button on a single interview for people who do not want a
  subscription.
- Tricky: the feed is read without a session, so the token is the only
  protection. It must be long and random and resettable.
- Tricky: UIDs must be stable across edits (`interview-<id>@<host>`) or
  calendar apps create duplicates.
- Tests: the iCalendar encoding as a pure module (escaping, line folding, UTC
  times); a controller test for the feed and a wrong token.

### 17. Email digest of what is due

Reminders exist only inside the app. If the user does not open it, a follow-up
due today is missed.

- A morning email, in the user's time zone, listing overdue and due today
  reminders and the day's interviews. Off by default, turned on in settings.
- Scheduling: Oban on the existing Postgres (no extra service), with a cron
  job every 15 minutes that sends to users whose local time just passed
  8:00 and who have something due.
- No email when nothing is due.
- Tricky: time zones. `TimeZones.today/1` is per user; the job needs "users
  for whom it is now 8:00" computed from their zones. A `last_digest_on` date
  on the user makes it safe to run late or twice.
- Tests: the selection of users as a context function with a fixed clock; the
  email content with `Swoosh.Adapters.Test`.

### 18. Contacts linked to applications and interviews

Contacts belong to a company only. The application page shows the company's
contacts, but nothing says that this recruiter is the one for this role, and
`interviews.interviewers` is a free text string.

- A join table `application_contacts` with a role (recruiter, hiring manager,
  referral, interviewer), picked on the application page.
- On the interview form, pick interviewers from the company's contacts or type
  a new name, which creates a contact. Keep the old text for existing rows.
- The contact page lists their applications and interviews.
- Tests: context tests for the links and scoping; LiveView test for picking
  an interviewer.

### 19. Contact interaction log

`contacts.last_contacted_on` is a single date typed by hand. Networking is a
big part of a job search and people want to see "talked to Ana three times,
last coffee 12 days ago, she offered a referral".

- An `interactions` table: contact, date, kind (email, call, message,
  meeting), a note, optionally an application.
- `last_contacted_on` becomes derived from the latest interaction (keep the
  column, updated in the same transaction, so sorting stays cheap).
- "Follow up in N days" on an interaction creates a reminder, like the follow
  up buttons on the application page.
- Tests: context tests for the derived date and reminder creation.

### 20. Offer details and comparison

An offer is a status today and nothing more. Deciding between two offers
needs base, bonus, equity, benefits, start date and the deadline to answer.

- An `offers` table per application: base, currency, bonus, equity (free text
  plus an optional yearly value), signing bonus, start date, decision
  deadline, notes.
- The deadline creates a reminder automatically.
- A comparison page for applications in Offer: one column per offer, rows per
  field, and a total first year value where the numbers allow it.
- Tricky: offers in different currencies. Show them side by side without
  converting (see 21).
- Tests: context tests; a pure function for the first year total.

### 21. Salary periods and currencies

Salary is a min, a max and a currency, implicitly per year. Contract and
hourly roles are common, and the table's salary sort compares 90,000 EUR with
120,000 USD as if they were the same unit.

- A `salary_period` column (year, month, day, hour), default year.
- `Format.salary/3` shows the period ("45 to 60 USD/hour").
- Sorting by salary sorts within the currency first, then by a yearly
  equivalent (hour times 2,080, day times 260, month times 12), and the column
  header says so. No exchange rates.
- Tests: the yearly equivalent as a pure function; sort order with mixed
  currencies.

### 22. Resume and cover letter versions

Which resume was sent where is the most common thing people try to remember
and cannot. Comparable trackers all have it.

- A `documents` table (name, kind: resume, cover letter, other, file path,
  content type, size) and a join to applications ("sent with this
  application").
- Files stored on disk under a `UPLOADS_DIR` volume in Compose, never inside
  `priv/static`. Served through a controller that checks ownership.
- LiveView uploads with a size limit (5 MB) and an allow list of types (PDF,
  DOCX, TXT).
- The stats page can then show response rate per resume version, which is the
  question people actually ask.
- Tricky: backups (4) must include the uploads directory.
- Tricky: deleting a document that applications point to. Keep the file, mark
  it retired, so history stays true.
- Tests: upload and download through LiveView and controller tests, someone
  else's document returns 404.

### 23. Save a posting from the browser

Adding an application means copying company, title and URL from another tab.

- `/applications/new` accepts `url`, `title` and `company` query parameters and
  prefills the form.
- A bookmarklet on the settings page that opens that URL with the current
  page's address and title (and selected text as the description). No browser
  extension to maintain.
- Tricky: the bookmarklet runs on any page, so it only reads `location.href`,
  `document.title` and the selection, and opens a new tab. Nothing is posted
  without the user pressing Save.
- Tests: LiveView test for the prefill.

### 24. Time in stage and better stats periods

The stats page answers "how many" but not "how long". It also filters the
period by `inserted_at` (`Stats.filter_since/2`), so an application added to
the wishlist in March and sent in June falls in the March period.

- Period filter on the date the application was sent (`applied_on`), with
  wishlist items counted by their creation date. Say which date is used under
  the period picker.
- Median days in each stage (applied to screening, screening to interview,
  interview to offer), from the history. Medians, because one application
  that sat for 200 days ruins an average.
- Interviews per offer and offers per hundred applications.
- Tests: all of it in `Stats.Calculations`, as pure functions.

### 25. Live updates across tabs

The board, the table and the dashboard read the database on mount and after
the user's own actions. With the board open in one tab and an application
edited in another, the board is stale until reloaded, and a drag there is
based on the old order.

- Broadcast `{:applications_changed, user_id}` on Phoenix PubSub from the
  `Pipeline` functions that write, and have the board, table and dashboard
  subscribe to the user's topic and reload.
- The navigation's due count (`Nav.assign_due_count/1`) can listen to
  reminder changes the same way.
- Tricky: broadcast after the transaction commits, not inside it.
- Tests: LiveView test with two views of the same user.

### 26. Sessions list and log out everywhere

Sessions last 60 days (`@session_validity_in_days`), and there is no way to
see them or end one from another device.

- Settings lists the user's session tokens with the time they were created and
  the last user agent and IP (two new nullable columns on `users_tokens`,
  written at login).
- "Log out this session" and "Log out everywhere else". Changing the password
  already deletes all tokens; keep that.
- Disconnect live sessions too, through the `live_socket_id` broadcast that
  `UserAuth.log_out_user/1` already uses.
- Tests: context and LiveView tests for listing and revoking.

### 27. Two-factor authentication

A job search account holds salary history, contacts and notes about people.
For anyone running this on a public server, a password alone is thin.

- TOTP with `nimble_totp`, set up from settings with a QR code (rendered as
  SVG on the server, e.g. `eqrcode`) and confirmed with one code.
- Ten one-time recovery codes, shown once, stored hashed.
- Login asks for the code after the password, on its own page, with the
  rate limit from 3.
- Tricky: the remember me cookie. Remember the second factor for the same 60
  days, tied to the session token, so revoking the session (26) revokes it.
- Tests: setup, login with code, recovery code used once, wrong code refused.

### 28. Metrics and an admin dashboard

`phoenix_live_dashboard` is a dependency but only routed in dev, and the only
production signal is `GET /health`.

- Mount LiveDashboard in production behind basic auth from
  `ADMIN_USER`/`ADMIN_PASSWORD`, off when they are not set.
- An optional `/metrics` endpoint in Prometheus format
  (`telemetry_metrics_prometheus_core`), behind a token, with request
  durations, LiveView mount times, Repo query times and counts of users and
  applications.
- `/health` could report the migration version too, so a half finished
  upgrade is visible.
- Tests: a conn test that the dashboard is refused without credentials and the
  metrics endpoint without the token.

### 29. Upgrade and rollback notes

`Release.rollback/2` exists but nothing explains when to use it, and the
CHANGELOG does not say which releases have migrations.

- A `docs/operations.md`: upgrading a Docker install (pull, take a backup,
  `docker compose up --build`, what the entrypoint does), rolling back a
  release with `bin/job_tracker eval "JobTracker.Release.rollback(...)"`, and
  restoring from a backup when a migration cannot be undone.
- From then on, CHANGELOG entries say "includes migrations" when they do.
- No code. Depends on 4 for the restore step.

### 30. Board and stats at a few thousand applications

The app is fine for a normal search of a few hundred applications. Some
people (graduates, contractors) send thousands over a year, and a few code
paths grow badly:

- `Pipeline.renumber/2` runs one `UPDATE` per card in the column on every
  move. One `UPDATE ... FROM unnest(ids, positions)` does it in one query.
- `Stats.summary/2` loads every application and every status change into
  memory and does the maths in Elixir. Fine for hundreds, slow for tens of
  thousands of changes. The funnel and response rate could move to SQL, but
  the pure `Calculations` module is the easy to test part, so first measure.
- `Pipeline.board/2` preloads tags for every open card. A board with 800
  Applied cards renders 800 cards; the column could show the first 50 with
  "show more".
- A benchmark script under `priv/repo/` that seeds 5,000 applications for one
  user, and numbers before and after in the pull request.
- Tests: the renumber still keeps positions dense and ordered (existing board
  tests cover most of it).

### 31. Board on a phone

The board is eight 16rem columns in a horizontal scroll, and HTML5 drag and
drop does not work on touch screens.

- Below a breakpoint, show one column at a time with a status picker at the
  top, and use the move menu from 6 instead of dragging.
- Check the table, application page and forms at 360px wide.
- Tests: none beyond the move menu tests from 6; this is layout.

## Maybe

### 32. Fetch the job description from the posting

Postings disappear, which is why the app keeps a description snapshot, but
the user has to paste it.

- A "Fetch" button next to the posting URL that downloads the page with Finch
  (already a dependency) and fills the description, using the
  `JobPosting` JSON-LD block when the page has one (most job boards do) and
  the readable text otherwise.
- Tricky: this makes the server fetch URLs typed by users, which is a server
  side request forgery risk on any shared install. Resolve the host first and
  refuse private, loopback and link local addresses, allow only ports 80 and
  443, follow at most three redirects with the same check, cap the size and
  time. Off unless `ALLOW_POSTING_FETCH=true`.
- Tricky: many boards block scripted requests or render with JavaScript only.
  It will work for some sites and not others; the paste box stays.
- Why maybe: the security cost is real for a feature that saves one paste.

### 33. Interview prep checklists

Prep notes are a single text field. People reuse the same preparation per
interview kind: research the company, prepare three stories, questions to
ask.

- Checklist templates per interview kind, edited in settings, copied onto a
  new interview as ticked or unticked items.
- A personal question bank (questions asked, my answer, tags) linked from
  interviews where the question came up.
- Why maybe: it overlaps with note taking apps people already use.

### 34. Read-only share link for a mentor

Career coaches and friends helping with a search ask for a view of the
pipeline.

- A revocable link that shows the board and stats, without contacts, notes or
  salaries unless the user ticks them.
- Tricky: getting the "what is hidden" choice right everywhere the data shows
  up; it touches every page component.
- Why maybe: it is a sharing model in a single user app, with privacy risks if
  any page forgets the filter.

### 35. Custom stages

The eight statuses are fixed in `Pipeline.Status`. Some searches have extra
steps (a take home stage, references, background check) or call them
differently.

- Let users rename the open stages and add stages between screening and
  offer, each mapped to one of the fixed funnel stages so the stats keep
  working.
- Tricky: statuses are an `Ecto.Enum` on two tables, the stats rely on the
  fixed progression (`Status.rank/1`), and the board columns come from
  `Status.all/0`. It is a large change for a small gain; renaming labels alone
  would be much cheaper.
- Why maybe: most people are fine with the standard stages.

### 36. Several searches in one account

A search ends with an accepted offer. Two years later the same person starts
again and wants a clean board without losing the old data.

- A `searches` table, every application belongs to one, a switcher in the
  navigation, stats per search.
- Today the archive (15) and the period filter on stats get most of the way.
- Why maybe: it adds a scope to every query in every context.

### 37. Browser tests for drag and drop

The board hook is the only JavaScript and the only thing the LiveView tests
cannot reach: they send the `move` event directly.

- Wallaby or Playwright driving a real browser through one drag, one reorder
  and one move menu action (6).
- Why maybe: a browser in CI makes it slower and flakier for a hook that
  changes rarely. A small Playwright job that only runs when
  `assets/js/hooks` changes would limit the cost.
