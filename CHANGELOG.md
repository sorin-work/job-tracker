# Changelog

## 1.0.0 - 2026-11-08

- Updated to Phoenix LiveView 1.2 and newer Elixir and Debian base images.
- Architecture notes and a configuration reference in the README.
- Dependency updates.

## 0.4.0 - 2026-07-04

- Indexes for due reminders, interviews and application dates.
- Fixed: the applications table showed an empty page past the last one.
- Fixed: demo interviews started at odd minutes.
- Dependency updates and dependabot.

## 0.3.0 - 2026-04-12

- Stats page: funnel, response rate, time to first response, applications per
  week, results by source and outcomes, for a chosen period.
- Weekly goal on the dashboard.
- CSV export of all applications.
- Docker setup with a release, migrations on start and a health endpoint.
- Demo account with sample data (`SEED_DEMO=true`).
- Closed applications drop off the board after 30 days.
- Fixed: interviews at a time skipped by daylight saving crashed the form.
- Fixed: CSV cells starting with `=` could be run as formulas.

## 0.2.0 - 2026-03-01

- Contacts at companies.
- Interviews with prep notes, shown on the application and on their own page.
- Follow-up reminders: due today and overdue on the dashboard, a count in the
  navigation, quick dates and automatic follow-ups after applying.
- Dashboard as the start page.
- Time zone, weekly goal and follow-up preferences.
- Fixed: reminders switched days at midnight UTC instead of the user's midnight.

## 0.1.0 - 2026-01-02

- Applications with status, salary range, posting link and description.
- Companies, looked up case-insensitively when typed on the form.
- Status history and timeline.
- Drag and drop board.
- Tags.
- Applications table with search, filters, sorting and pagination.
