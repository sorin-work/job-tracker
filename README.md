# job-tracker

A job search tracker for people who are applying to more places than they can
keep in their head. Every application moves through a pipeline, from a posting
you bookmarked to an offer you accepted (or a polite rejection), and the app
keeps the details, the dates and what you need to do next.

## Features

- **Pipeline board**: wishlist, applied, screening, interviewing, offer, and
  accepted / rejected / withdrawn. Drag cards between columns.
- **Table view** with search, status and tag filters, sorting and pagination.
- **Applications**: company, role, location, work mode, source, priority, salary
  range, the job posting URL and a snapshot of the job description.
- **Timeline** of status changes for each application.
- **Companies** with their applications.
- **Accounts** with email confirmation and password reset.

## Stack

- Elixir 1.18 / OTP 27, Phoenix 1.7 with LiveView and Tailwind
- PostgreSQL with Ecto migrations
- Authentication generated with `phx.gen.auth`
- ExUnit and Phoenix.LiveViewTest, Credo for linting

## Running with Docker

Not yet, see below for running it locally.

## Running locally

You need Elixir 1.17 or newer and PostgreSQL. The dev and test configs connect
to `localhost` with `postgres` / `postgres`; set `DB_HOST` to use another host.

```bash
mix setup               # deps, database, migrations, assets
mix phx.server          # http://localhost:4000
```

## Tests and lint

```bash
mix test
mix lint                # format check and credo --strict
```

## License

MIT, see [LICENSE](LICENSE).
