defmodule JobTrackerWeb.AppComponents do
  @moduledoc """
  Components specific to the job tracker: status badges, tags, stat cards.
  """

  use Phoenix.Component

  alias JobTracker.Pipeline.Status

  @status_classes %{
    wishlist: "bg-zinc-100 text-zinc-700 ring-zinc-200",
    applied: "bg-sky-50 text-sky-700 ring-sky-200",
    screening: "bg-indigo-50 text-indigo-700 ring-indigo-200",
    interviewing: "bg-violet-50 text-violet-700 ring-violet-200",
    offer: "bg-amber-50 text-amber-800 ring-amber-200",
    accepted: "bg-emerald-50 text-emerald-700 ring-emerald-200",
    rejected: "bg-red-50 text-red-700 ring-red-200",
    withdrawn: "bg-zinc-50 text-zinc-500 ring-zinc-200"
  }

  def status_classes(status), do: Map.fetch!(@status_classes, status)

  attr :status, :atom, required: true
  attr :class, :string, default: nil

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ring-1 ring-inset whitespace-nowrap",
      status_classes(@status),
      @class
    ]}>
      {Status.label(@status)}
    </span>
    """
  end

  @tag_classes %{
    "zinc" => "bg-zinc-100 text-zinc-700",
    "red" => "bg-red-100 text-red-700",
    "amber" => "bg-amber-100 text-amber-800",
    "emerald" => "bg-emerald-100 text-emerald-700",
    "sky" => "bg-sky-100 text-sky-700",
    "indigo" => "bg-indigo-100 text-indigo-700",
    "violet" => "bg-violet-100 text-violet-700",
    "pink" => "bg-pink-100 text-pink-700"
  }

  def tag_classes(color), do: Map.get(@tag_classes, color, @tag_classes["zinc"])

  attr :tag, :map, required: true

  def tag_pill(assigns) do
    ~H"""
    <span class={["inline-flex rounded px-1.5 py-0.5 text-xs font-medium", tag_classes(@tag.color)]}>
      {@tag.name}
    </span>
    """
  end

  attr :tags, :list, required: true
  attr :class, :string, default: nil

  def tag_list(assigns) do
    ~H"""
    <div :if={@tags != []} class={["flex flex-wrap gap-1", @class]}>
      <.tag_pill :for={tag <- @tags} tag={tag} />
    </div>
    """
  end

  attr :priority, :integer, required: true

  def priority(assigns) do
    ~H"""
    <span
      class="inline-flex gap-0.5"
      title={"Priority: #{priority_label(@priority)}"}
      aria-label={"Priority: #{priority_label(@priority)}"}
    >
      <span
        :for={i <- 1..3}
        class={["h-1.5 w-1.5 rounded-full", if(i <= @priority, do: "bg-brand", else: "bg-zinc-200")]}
      />
    </span>
    """
  end

  def priority_label(1), do: "low"
  def priority_label(2), do: "medium"
  def priority_label(3), do: "high"
  def priority_label(_), do: "medium"

  attr :title, :string, required: true
  attr :value, :any, required: true
  attr :hint, :string, default: nil
  attr :id, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div id={@id} class="rounded-lg border border-zinc-200 bg-white p-4">
      <p class="text-sm text-zinc-500">{@title}</p>
      <p class="mt-1 text-2xl font-semibold text-zinc-900">{@value}</p>
      <p :if={@hint} class="mt-1 text-xs text-zinc-500">{@hint}</p>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :actions

  def panel(assigns) do
    ~H"""
    <section class={["rounded-lg border border-zinc-200 bg-white", @class]} {@rest}>
      <div class="flex items-center justify-between border-b border-zinc-100 px-4 py-3">
        <h2 class="text-sm font-semibold text-zinc-900">{@title}</h2>
        <div class="flex items-center gap-2 text-sm">{render_slot(@actions)}</div>
      </div>
      <div class="p-4">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  attr :class, :string, default: nil
  slot :inner_block, required: true

  def empty_state(assigns) do
    ~H"""
    <p class={[
      "rounded-lg border border-dashed border-zinc-200 p-6 text-center text-sm text-zinc-500",
      @class
    ]}>
      {render_slot(@inner_block)}
    </p>
    """
  end
end
