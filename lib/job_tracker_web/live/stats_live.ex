defmodule JobTrackerWeb.StatsLive do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline.Status
  alias JobTracker.Stats

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Stats")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, :summary, Stats.summary(socket.assigns.current_user))}
  end

  defp bar_width(_count, 0), do: 0
  defp bar_width(count, max), do: round(count * 100 / max)

  defp max_weekly(weekly), do: weekly |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end)

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Stats
      <:subtitle>How your search is going.</:subtitle>
    </.header>

    <div class="mt-6 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
      <.stat_card id="stat-total" title="Applications tracked" value={@summary.total} />
      <.stat_card
        id="stat-submitted"
        title="Submitted"
        value={@summary.submitted}
        hint="Moved past the wishlist"
      />
      <.stat_card
        id="stat-response-rate"
        title="Response rate"
        value={Format.percent(@summary.response_rate)}
        hint="Got a reply, a screen or a rejection"
      />
      <.stat_card
        id="stat-response-time"
        title="Time to first response"
        value={
          if @summary.average_days_to_response,
            do: "#{@summary.average_days_to_response} days",
            else: "—"
        }
        hint="Average from applying"
      />
    </div>

    <div class="mt-6 grid gap-6 lg:grid-cols-2">
      <.panel id="funnel" title="Funnel">
        <.empty_state :if={@summary.submitted == 0}>
          Submit an application to see the funnel.
        </.empty_state>
        <ul :if={@summary.submitted > 0} class="space-y-3">
          <li :for={row <- @summary.funnel} id={"funnel-#{row.status}"}>
            <div class="flex items-baseline justify-between text-sm">
              <span class="font-medium text-zinc-800">{Status.label(row.status)}</span>
              <span class="text-zinc-600">
                {row.count}
                <span :if={row.from_previous} class="ml-2 text-xs text-zinc-500">
                  {Format.percent(row.from_previous)} of previous
                </span>
              </span>
            </div>
            <div class="mt-1 h-2 rounded-full bg-zinc-100">
              <div class="h-2 rounded-full bg-brand" style={"width: #{row.from_applied || 0}%"} />
            </div>
          </li>
        </ul>
      </.panel>

      <.panel id="weekly" title="Applications per week">
        <div class="flex h-40 items-end gap-1" role="img" aria-label="Applications submitted per week">
          <div
            :for={week <- @summary.weekly}
            class="group flex h-full flex-1 flex-col items-center justify-end gap-1"
            title={"Week of #{Format.short_date(week.week)}: #{week.count}"}
          >
            <span class="text-[10px] text-zinc-500">{if week.count > 0, do: week.count}</span>
            <div
              class="w-full rounded-t bg-sky-400 group-hover:bg-sky-500"
              style={"height: #{bar_width(week.count, max_weekly(@summary.weekly))}%; min-height: #{if week.count > 0, do: 2, else: 0}px"}
            />
          </div>
        </div>
        <div class="mt-1 flex gap-1 text-[10px] text-zinc-400">
          <span :for={week <- @summary.weekly} class="flex-1 truncate text-center">
            {Calendar.strftime(week.week, "%-m/%-d")}
          </span>
        </div>
      </.panel>

      <.panel id="sources" title="By source">
        <.empty_state :if={@summary.by_source == []}>No submitted applications yet.</.empty_state>
        <table :if={@summary.by_source != []} class="w-full text-sm">
          <thead class="text-left text-xs text-zinc-500">
            <tr>
              <th class="pb-2 font-medium">Source</th>
              <th class="pb-2 text-right font-medium">Applications</th>
              <th class="pb-2 text-right font-medium">Response rate</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-zinc-100">
            <tr :for={row <- @summary.by_source}>
              <td class="py-1.5">
                {if row.source, do: Format.label(row.source), else: "Not specified"}
              </td>
              <td class="py-1.5 text-right">{row.count}</td>
              <td class="py-1.5 text-right">{Format.percent(row.response_rate)}</td>
            </tr>
          </tbody>
        </table>
      </.panel>

      <.panel id="outcomes" title="Outcomes">
        <dl class="grid grid-cols-3 gap-4 text-center">
          <div :for={status <- Status.closed()}>
            <dt><.status_badge status={status} /></dt>
            <dd class="mt-2 text-2xl font-semibold text-zinc-900">{@summary.outcomes[status]}</dd>
          </div>
        </dl>
      </.panel>
    </div>
    """
  end
end
