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

| Part     | Tech                                                                 |
| -------- | -------------------------------------------------------------------- |
| Language | Elixir 1.18 on OTP 27                                                |
| Web      | Phoenix 1.7, LiveView (server-rendered), Tailwind CSS, esbuild       |
| Database | PostgreSQL 17 with Ecto migrations                                   |
| Auth     | `phx.gen.auth` (bcrypt, session tokens, email confirmation)          |
| Tests    | ExUnit, Phoenix.LiveViewTest, Ecto SQL sandbox                       |
| Lint     | `mix format --check-formatted`, Credo (strict)                       |
| Ops      | `mix release`, multi-stage Dockerfile, Docker Compose, GitHub Actions |

## Running with Docker

Not yet, see below for running it locally.

## Running locally

You need Elixir 1.17 or newer and PostgreSQL. The dev and test configs connect
to `localhost` with `postgres` / `postgres`; set `DB_HOST` to use another host.

```bash
mix setup               # deps, database, migrations, assets
mix phx.server          # http://localhost:4000
```

To create the demo account locally:

```bash
SEED_DEMO=true mix run priv/repo/seeds.exs
```

## Tests and lint

```bash
mix test
mix lint                # format check and credo --strict
```

## License

MIT, see [LICENSE](LICENSE).
