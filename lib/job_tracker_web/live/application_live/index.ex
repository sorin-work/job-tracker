defmodule JobTrackerWeb.ApplicationLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.{JobApplication, Status}

  @filter_keys ~w(q status tag sort dir page)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tags, Pipeline.list_tags(socket.assigns.current_user))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters = Map.take(params, @filter_keys)
    result = Pipeline.search_applications(socket.assigns.current_user, filters)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:filter_form, to_form(filters, as: :filters))
     |> assign(:result, result)
     |> apply_action(socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    socket
    |> assign(:page_title, "New application")
    |> assign(:application, %JobApplication{tags: []})
  end

  defp apply_action(socket, :index) do
    socket
    |> assign(:page_title, "Applications")
    |> assign(:application, nil)
  end

  @impl true
  def handle_event("filter", %{"filters" => params}, socket) do
    filters =
      socket.assigns.filters
      |> Map.merge(Map.take(params, ~w(q status tag)))
      |> Map.delete("page")

    {:noreply, push_patch(socket, to: ~p"/applications?#{clean(filters)}")}
  end

  def handle_event("clear", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/applications")}
  end

  @impl true
  def handle_info({JobTrackerWeb.ApplicationLive.FormComponent, {:saved, _application}}, socket) do
    {:noreply, socket}
  end

  defp clean(filters), do: filters |> Enum.reject(fn {_k, v} -> v in [nil, ""] end) |> Map.new()

  defp sort_link(assigns) do
    current = assigns.filters["sort"] || "updated"
    dir = assigns.filters["dir"] || "desc"
    active? = current == assigns.field
    next_dir = if active? and dir == "desc", do: "asc", else: "desc"

    params =
      assigns.filters
      |> Map.merge(%{"sort" => assigns.field, "dir" => next_dir})
      |> Map.delete("page")

    assigns = assign(assigns, active?: active?, dir: dir, params: clean(params))

    ~H"""
    <.link
      patch={~p"/applications?#{@params}"}
      class="inline-flex items-center gap-1 hover:text-zinc-900"
    >
      {@label}
      <.icon
        :if={@active?}
        name={if @dir == "asc", do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
        class="h-4 w-4"
      />
    </.link>
    """
  end

  defp page_link(filters, page), do: ~p"/applications?#{clean(Map.put(filters, "page", page))}"

  defp filtered?(filters), do: Enum.any?(~w(q status tag), &(filters[&1] not in [nil, ""]))

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Applications
      <:subtitle>
        {@result.total} {if @result.total == 1, do: "application", else: "applications"}
      </:subtitle>
      <:actions>
        <.link
          href={~p"/export/applications.csv"}
          class="text-sm font-medium text-zinc-600 hover:text-zinc-900"
        >
          <.icon name="hero-arrow-down-tray" class="h-4 w-4" /> Export CSV
        </.link>
        <.link navigate={~p"/tags"} class="ml-4 text-sm font-medium text-zinc-600 hover:text-zinc-900">
          Manage tags
        </.link>
        <.link patch={~p"/applications/new"} class="ml-4">
          <.button>New application</.button>
        </.link>
      </:actions>
    </.header>

    <.form
      for={@filter_form}
      id="filters"
      phx-change="filter"
      phx-submit="filter"
      class="mt-6 grid gap-3 sm:grid-cols-[1fr_12rem_12rem_auto] sm:items-end"
    >
      <.input
        field={@filter_form[:q]}
        type="search"
        label="Search"
        placeholder="Title or company"
        phx-debounce="300"
      />
      <.input
        field={@filter_form[:status]}
        type="select"
        label="Status"
        prompt="Any status"
        options={[{"Open", "open"}, {"Closed", "closed"} | Status.options()]}
      />
      <.input
        field={@filter_form[:tag]}
        type="select"
        label="Tag"
        prompt="Any tag"
        options={Enum.map(@tags, &{&1.name, &1.id})}
      />
      <button
        :if={filtered?(@filters)}
        type="button"
        phx-click="clear"
        class="pb-2 text-sm font-medium text-zinc-600 hover:text-zinc-900"
      >
        Clear filters
      </button>
    </.form>

    <div :if={@result.entries == []} class="mt-8">
      <.empty_state :if={filtered?(@filters)}>No applications match these filters.</.empty_state>
      <.empty_state :if={!filtered?(@filters)}>
        Nothing here yet.
        <.link patch={~p"/applications/new"} class="font-medium text-brand">
          Add your first application
        </.link>
        or save one from a posting you liked.
      </.empty_state>
    </div>

    <div
      :if={@result.entries != []}
      class="mt-6 overflow-x-auto rounded-lg border border-zinc-200 bg-white"
    >
      <table id="applications" class="w-full min-w-[48rem] text-left text-sm">
        <thead class="border-b border-zinc-200 bg-zinc-50 text-xs font-medium uppercase tracking-wide text-zinc-500">
          <tr>
            <th class="px-4 py-2"><.sort_link field="title" label="Role" filters={@filters} /></th>
            <th class="px-4 py-2">
              <.sort_link field="company" label="Company" filters={@filters} />
            </th>
            <th class="px-4 py-2"><.sort_link field="status" label="Status" filters={@filters} /></th>
            <th class="px-4 py-2">
              <.sort_link field="applied" label="Applied" filters={@filters} />
            </th>
            <th class="px-4 py-2"><.sort_link field="salary" label="Salary" filters={@filters} /></th>
            <th class="px-4 py-2">
              <.sort_link field="priority" label="Priority" filters={@filters} />
            </th>
            <th class="px-4 py-2">
              <.sort_link field="updated" label="Updated" filters={@filters} />
            </th>
          </tr>
        </thead>
        <tbody class="divide-y divide-zinc-100">
          <tr
            :for={application <- @result.entries}
            id={"application-#{application.id}"}
            class="hover:bg-zinc-50"
          >
            <td class="px-4 py-3">
              <.link
                navigate={~p"/applications/#{application}"}
                class="font-medium text-zinc-900 hover:underline"
              >
                {application.title}
              </.link>
              <.tag_list tags={application.tags} class="mt-1" />
            </td>
            <td class="px-4 py-3 text-zinc-700">{application.company.name}</td>
            <td class="px-4 py-3"><.status_badge status={application.status} /></td>
            <td class="px-4 py-3 text-zinc-700">{Format.short_date(application.applied_on)}</td>
            <td class="px-4 py-3 text-zinc-700">
              {Format.salary(
                application.salary_min,
                application.salary_max,
                application.salary_currency
              ) || "—"}
            </td>
            <td class="px-4 py-3"><.priority priority={application.priority} /></td>
            <td class="px-4 py-3 text-zinc-500">
              {Format.local_date(application.updated_at, @current_user)}
            </td>
          </tr>
        </tbody>
      </table>
    </div>

    <nav
      :if={@result.total_pages > 1}
      class="mt-4 flex items-center justify-between text-sm"
      aria-label="Pagination"
    >
      <p class="text-zinc-500">Page {@result.page} of {@result.total_pages}</p>
      <div class="flex gap-2">
        <.link
          :if={@result.page > 1}
          patch={page_link(@filters, @result.page - 1)}
          class="rounded-lg border border-zinc-200 bg-white px-3 py-1.5 font-medium hover:bg-zinc-50"
        >
          Previous
        </.link>
        <.link
          :if={@result.page < @result.total_pages}
          patch={page_link(@filters, @result.page + 1)}
          class="rounded-lg border border-zinc-200 bg-white px-3 py-1.5 font-medium hover:bg-zinc-50"
        >
          Next
        </.link>
      </div>
    </nav>

    <.modal
      :if={@live_action == :new}
      id="application-modal"
      show
      on_cancel={JS.patch(~p"/applications?#{clean(@filters)}")}
    >
      <.live_component
        module={JobTrackerWeb.ApplicationLive.FormComponent}
        id={:new}
        title="New application"
        action={:new}
        application={@application}
        current_user={@current_user}
        patch={~p"/applications"}
      />
    </.modal>
    """
  end
end
