defmodule JobTrackerWeb.AppComponents do
  @moduledoc """
  Components specific to the job tracker: status badges, tags, stat cards.
  """

  use Phoenix.Component

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
