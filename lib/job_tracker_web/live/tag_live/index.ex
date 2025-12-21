defmodule JobTrackerWeb.TagLive.Index do
  use JobTrackerWeb, :live_view

  alias JobTracker.Pipeline
  alias JobTracker.Pipeline.Tag

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:page_title, "Tags") |> load()}
  end

  defp load(socket), do: assign(socket, :tags, Pipeline.list_tags(socket.assigns.current_user))

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    tag = Pipeline.get_tag!(socket.assigns.current_user, id)

    {:noreply,
     socket
     |> assign(:tag, tag)
     |> assign(:form, to_form(Pipeline.change_tag(tag)))}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, assign(socket, tag: nil, form: nil)}
  end

  @impl true
  def handle_event("validate", %{"tag" => params}, socket) do
    changeset = Pipeline.change_tag(socket.assigns.tag, params)
    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"tag" => params}, socket) do
    case Pipeline.update_tag(socket.assigns.tag, params) do
      {:ok, _tag} ->
        {:noreply,
         socket
         |> put_flash(:info, "Tag updated")
         |> load()
         |> push_patch(to: ~p"/tags")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    tag = Pipeline.get_tag!(socket.assigns.current_user, id)
    {:ok, _} = Pipeline.delete_tag(tag)
    {:noreply, socket |> put_flash(:info, "Tag \"#{tag.name}\" deleted") |> load()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.back navigate={~p"/applications"}>Applications</.back>
    <.header class="mt-6">
      Tags
      <:subtitle>
        Tags are created as you type them on an application. Rename, recolor or remove them here.
      </:subtitle>
    </.header>

    <.empty_state :if={@tags == []} class="mt-6">No tags yet.</.empty_state>

    <ul
      :if={@tags != []}
      id="tags"
      class="mt-6 divide-y divide-zinc-100 rounded-lg border border-zinc-200 bg-white"
    >
      <li :for={tag <- @tags} id={"tag-#{tag.id}"} class="flex items-center justify-between gap-3 p-3">
        <div class="flex items-center gap-3">
          <.tag_pill tag={tag} />
          <.link
            navigate={~p"/applications?tag=#{tag.id}"}
            class="text-xs text-zinc-500 hover:underline"
          >
            {tag.usage_count} {if tag.usage_count == 1, do: "application", else: "applications"}
          </.link>
        </div>
        <div class="flex gap-3 text-sm font-medium">
          <.link patch={~p"/tags/#{tag}/edit"} class="text-zinc-600 hover:text-zinc-900">Edit</.link>
          <button
            phx-click="delete"
            phx-value-id={tag.id}
            data-confirm={"Delete the tag \"#{tag.name}\"? It will be removed from all applications."}
            class="text-zinc-600 hover:text-red-600"
          >
            Delete
          </button>
        </div>
      </li>
    </ul>

    <.modal :if={@live_action == :edit} id="tag-modal" show on_cancel={JS.patch(~p"/tags")}>
      <.header>Edit tag</.header>
      <.simple_form for={@form} id="tag-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" />
        <.input
          field={@form[:color]}
          type="select"
          label="Color"
          options={Enum.map(Tag.colors(), &{&1, &1})}
        />
        <:actions>
          <.button phx-disable-with="Saving...">Save tag</.button>
        </:actions>
      </.simple_form>
    </.modal>
    """
  end
end
