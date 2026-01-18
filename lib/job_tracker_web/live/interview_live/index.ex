defmodule JobTrackerWeb.InterviewLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Interviews
  alias JobTracker.Interviews.Interview

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    {:ok,
     socket
     |> assign(:page_title, "Interviews")
     |> assign(:upcoming, Interviews.list_upcoming(user))
     |> assign(:past, Interviews.list_past(user))}
  end

  attr :interviews, :list, required: true
  attr :current_user, :map, required: true
  attr :id, :string, required: true

  defp interview_list(assigns) do
    ~H"""
    <ul id={@id} class="mt-3 divide-y divide-zinc-100 rounded-lg border border-zinc-200 bg-white">
      <li :for={interview <- @interviews} id={"#{@id}-#{interview.id}"} class="p-4">
        <div class="flex flex-wrap items-start justify-between gap-2">
          <div>
            <.link
              navigate={~p"/applications/#{interview.job_application}"}
              class="font-medium text-zinc-900 hover:underline"
            >
              {Interview.kind_label(interview.kind)} · {interview.job_application.company.name}
            </.link>
            <p class="text-sm text-zinc-600">{interview.job_application.title}</p>
          </div>
          <div class="text-right text-sm">
            <p class="font-medium text-zinc-800">
              {Format.datetime(interview.scheduled_at, @current_user)}
            </p>
            <p class="text-zinc-500">
              {interview.duration_minutes} min · {Format.label(interview.outcome)}
            </p>
          </div>
        </div>
        <p :if={interview.location} class="mt-1 text-sm text-zinc-500">{interview.location}</p>
        <p
          :if={interview.prep_notes}
          class="mt-2 line-clamp-3 whitespace-pre-line text-sm text-zinc-700"
        >
          {interview.prep_notes}
        </p>
      </li>
    </ul>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Interviews
      <:subtitle>Schedule interviews from an application's page.</:subtitle>
    </.header>

    <h2 class="mt-8 text-sm font-semibold text-zinc-900">Upcoming</h2>
    <.empty_state :if={@upcoming == []} class="mt-3">No interviews scheduled.</.empty_state>
    <.interview_list
      :if={@upcoming != []}
      id="upcoming"
      interviews={@upcoming}
      current_user={@current_user}
    />

    <h2 class="mt-10 text-sm font-semibold text-zinc-900">Past</h2>
    <.empty_state :if={@past == []} class="mt-3">Nothing here yet.</.empty_state>
    <.interview_list :if={@past != []} id="past" interviews={@past} current_user={@current_user} />
    """
  end
end
