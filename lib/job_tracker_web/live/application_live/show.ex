defmodule JobTrackerWeb.ApplicationLive.Show do
  use JobTrackerWeb, :live_view

  alias JobTracker.Contacts
  alias JobTracker.Interviews
  alias JobTracker.Interviews.Interview
  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.Status

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    application = Pipeline.get_application!(socket.assigns.current_user, id)

    {:noreply,
     socket
     |> assign_application(application)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp assign_application(socket, application) do
    user = socket.assigns.current_user

    socket
    |> assign(:application, application)
    |> assign(:timeline, Pipeline.timeline(application))
    |> assign(:contacts, Contacts.list_contacts(user, company_id: application.company_id))
    |> assign(:status_form, to_form(%{"status" => application.status, "note" => ""}, as: :status))
  end

  defp apply_action(socket, :show, _params) do
    assign(socket, :page_title, socket.assigns.application.title)
  end

  defp apply_action(socket, :edit, _params) do
    assign(socket, :page_title, "Edit #{socket.assigns.application.title}")
  end

  defp apply_action(socket, :new_interview, _params) do
    socket
    |> assign(:page_title, "Schedule interview")
    |> assign(:interview, %Interview{})
  end

  defp apply_action(socket, :edit_interview, %{"interview_id" => interview_id}) do
    interview = Interviews.get_interview!(socket.assigns.current_user, interview_id)

    if interview.job_application_id != socket.assigns.application.id do
      raise Ecto.NoResultsError, queryable: Interview
    end

    socket
    |> assign(:page_title, "Edit interview")
    |> assign(:interview, interview)
  end

  @impl true
  def handle_event("change_status", %{"status" => %{"status" => status} = params}, socket) do
    %{current_user: user, application: application} = socket.assigns

    case Pipeline.change_status(user, application, status, blank_to_nil(params["note"])) do
      {:ok, _application} ->
        {:noreply,
         socket
         |> put_flash(:info, "Moved to #{Status.label(status)}")
         |> reload()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not change the status")}
    end
  end

  def handle_event("delete_interview", %{"id" => id}, socket) do
    interview = Interviews.get_interview!(socket.assigns.current_user, id)
    {:ok, _} = Interviews.delete_interview(interview)
    {:noreply, socket |> put_flash(:info, "Interview removed") |> reload()}
  end

  def handle_event("delete", _params, socket) do
    {:ok, _} = Pipeline.delete_application(socket.assigns.application)

    {:noreply,
     socket
     |> put_flash(:info, "Application deleted")
     |> push_navigate(to: ~p"/applications")}
  end

  @impl true
  def handle_info({_component, {:saved, _record}}, socket) do
    {:noreply, reload(socket)}
  end

  defp reload(socket) do
    application =
      Pipeline.get_application!(socket.assigns.current_user, socket.assigns.application.id)

    assign_application(socket, application)
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/applications"}>All applications</.back>

    <.header class="mt-6">
      {@application.title}
      <:subtitle>
        <.link
          navigate={~p"/companies/#{@application.company}"}
          class="font-medium text-zinc-700 hover:underline"
        >
          {@application.company.name}
        </.link>
        <span :if={@application.location}>· {@application.location}</span>
        <span :if={@application.work_mode}>· {Format.label(@application.work_mode)}</span>
      </:subtitle>
      <:actions>
        <.link patch={~p"/applications/#{@application}/edit"}>
          <.button>Edit</.button>
        </.link>
      </:actions>
    </.header>

    <div class="mt-3 flex flex-wrap items-center gap-3">
      <.status_badge status={@application.status} />
      <.priority priority={@application.priority} />
      <.tag_list tags={@application.tags} />
    </div>

    <div class="mt-8 grid gap-6 lg:grid-cols-3">
      <div class="space-y-6 lg:col-span-2">
        <.panel title="Details">
          <dl class="grid gap-4 text-sm sm:grid-cols-2">
            <div>
              <dt class="text-zinc-500">Applied on</dt>
              <dd class="mt-0.5 text-zinc-900">{Format.date(@application.applied_on)}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Salary</dt>
              <dd class="mt-0.5 text-zinc-900">
                {Format.salary(
                  @application.salary_min,
                  @application.salary_max,
                  @application.salary_currency
                ) ||
                  "Not listed"}
              </dd>
            </div>
            <div>
              <dt class="text-zinc-500">Source</dt>
              <dd class="mt-0.5 text-zinc-900">{Format.label(@application.source)}</dd>
            </div>
            <div>
              <dt class="text-zinc-500">Job posting</dt>
              <dd class="mt-0.5 truncate">
                <a
                  :if={@application.posting_url}
                  href={@application.posting_url}
                  target="_blank"
                  rel="noopener noreferrer"
                  class="text-brand hover:underline"
                >
                  {URI.parse(@application.posting_url).host}
                  <.icon name="hero-arrow-top-right-on-square-mini" class="h-4 w-4" />
                </a>
                <span :if={!@application.posting_url} class="text-zinc-900">—</span>
              </dd>
            </div>
          </dl>
          <div :if={@application.notes} class="mt-4 border-t border-zinc-100 pt-4">
            <p class="text-sm text-zinc-500">Notes</p>
            <p class="mt-1 whitespace-pre-line text-sm text-zinc-800">{@application.notes}</p>
          </div>
          <details
            :if={@application.description}
            id="description"
            class="mt-4 border-t border-zinc-100 pt-4"
          >
            <summary class="cursor-pointer text-sm font-medium text-zinc-700">
              Job description snapshot
            </summary>
            <p class="mt-2 whitespace-pre-line text-sm leading-6 text-zinc-700">
              {@application.description}
            </p>
          </details>
        </.panel>

        <.panel id="interviews" title="Interviews">
          <:actions>
            <.link
              patch={~p"/applications/#{@application}/interviews/new"}
              class="font-medium text-brand"
            >
              Schedule interview
            </.link>
          </:actions>
          <.empty_state :if={@application.interviews == []}>No interviews yet.</.empty_state>
          <ul class="divide-y divide-zinc-100">
            <li
              :for={interview <- @application.interviews}
              id={"interview-#{interview.id}"}
              class="py-3 first:pt-0 last:pb-0"
            >
              <div class="flex items-start justify-between gap-4">
                <div>
                  <p class="font-medium text-zinc-900">
                    {Interview.kind_label(interview.kind)}
                    <span class="ml-2 text-xs font-normal text-zinc-500">
                      {Format.label(interview.outcome)}
                    </span>
                  </p>
                  <p class="text-sm text-zinc-600">
                    {Format.datetime(interview.scheduled_at, @current_user)} · {interview.duration_minutes} min
                    <span :if={interview.interviewers}>· {interview.interviewers}</span>
                  </p>
                  <p :if={interview.location} class="text-sm text-zinc-500">{interview.location}</p>
                </div>
                <div class="flex shrink-0 gap-3 text-sm">
                  <.link
                    patch={~p"/applications/#{@application}/interviews/#{interview}/edit"}
                    class="font-medium text-zinc-600 hover:text-zinc-900"
                  >
                    Edit
                  </.link>
                  <.link
                    phx-click="delete_interview"
                    phx-value-id={interview.id}
                    data-confirm="Remove this interview?"
                    class="font-medium text-zinc-600 hover:text-red-600"
                  >
                    Remove
                  </.link>
                </div>
              </div>
              <p
                :if={interview.prep_notes}
                class="mt-2 whitespace-pre-line rounded bg-amber-50 p-2 text-sm text-zinc-700"
              >
                {interview.prep_notes}
              </p>
              <p :if={interview.feedback} class="mt-2 whitespace-pre-line text-sm text-zinc-600">
                {interview.feedback}
              </p>
            </li>
          </ul>
        </.panel>

        <.panel id="timeline" title="Timeline">
          <ol class="relative space-y-4 border-l border-zinc-200 pl-5">
            <li :for={event <- @timeline} class="text-sm">
              <span class="absolute -left-1.5 mt-1.5 h-3 w-3 rounded-full border-2 border-white bg-zinc-300" />
              <p class="text-xs text-zinc-500">{Format.datetime(event.at, @current_user)}</p>
              <%= case event.type do %>
                <% :status -> %>
                  <p :if={is_nil(event.from)} class="text-zinc-800">
                    Added as <.status_badge status={event.to} />
                  </p>
                  <p :if={event.from} class="text-zinc-800">
                    <.status_badge status={event.from} /> → <.status_badge status={event.to} />
                  </p>
                <% :interview -> %>
                  <p class="text-zinc-800">
                    {Interview.kind_label(event.interview.kind)} interview
                    <span class="text-zinc-500">({Format.label(event.interview.outcome)})</span>
                  </p>
              <% end %>
            </li>
          </ol>
        </.panel>
      </div>

      <div class="space-y-6">
        <.panel title="Status">
          <.form for={@status_form} id="status-form" phx-submit="change_status" class="space-y-3">
            <.input
              field={@status_form[:status]}
              type="select"
              label="Move to"
              options={Status.options()}
            />
            <.input
              field={@status_form[:note]}
              type="text"
              label="Note (optional)"
              placeholder="What happened?"
            />
            <.button class="w-full" phx-disable-with="Saving...">Update status</.button>
          </.form>
        </.panel>

        <.panel title={"People at #{@application.company.name}"}>
          <:actions>
            <.link
              navigate={~p"/contacts/new?company_id=#{@application.company_id}"}
              class="font-medium text-brand"
            >
              Add
            </.link>
          </:actions>
          <.empty_state :if={@contacts == []}>No contacts at this company yet.</.empty_state>
          <ul class="space-y-3 text-sm">
            <li :for={contact <- @contacts}>
              <p class="font-medium text-zinc-900">{contact.name}</p>
              <p :if={contact.title} class="text-zinc-500">{contact.title}</p>
              <a
                :if={contact.email}
                href={"mailto:#{contact.email}"}
                class="text-brand hover:underline"
              >
                {contact.email}
              </a>
            </li>
          </ul>
        </.panel>

        <button
          type="button"
          phx-click="delete"
          data-confirm="Delete this application?"
          class="text-sm font-medium text-red-600 hover:text-red-800"
        >
          Delete application
        </button>
      </div>
    </div>

    <.modal
      :if={@live_action == :edit}
      id="application-modal"
      show
      on_cancel={JS.patch(~p"/applications/#{@application}")}
    >
      <.live_component
        module={JobTrackerWeb.ApplicationLive.FormComponent}
        id={@application.id}
        title="Edit application"
        action={:edit}
        application={@application}
        current_user={@current_user}
        patch={~p"/applications/#{@application}"}
      />
    </.modal>

    <.modal
      :if={@live_action in [:new_interview, :edit_interview]}
      id="interview-modal"
      show
      on_cancel={JS.patch(~p"/applications/#{@application}")}
    >
      <.live_component
        module={JobTrackerWeb.InterviewLive.FormComponent}
        id={@interview.id || :new}
        title={if @live_action == :new_interview, do: "Schedule interview", else: "Edit interview"}
        action={@live_action}
        interview={@interview}
        application={@application}
        current_user={@current_user}
        patch={~p"/applications/#{@application}"}
      />
    </.modal>
    """
  end
end
