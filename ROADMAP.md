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
