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
