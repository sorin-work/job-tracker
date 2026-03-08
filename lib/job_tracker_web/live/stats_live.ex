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
      />
      <.stat_card
        id="stat-response-rate"
        title="Response rate"
        value={Format.percent(@summary.response_rate)}
      />
      <.stat_card
        id="stat-response-time"
        title="Time to first response"
        value={
          if @summary.average_days_to_response,
            do: "#{@summary.average_days_to_response} days",
            else: "—"
        }
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
    </div>
    """
  end
end
