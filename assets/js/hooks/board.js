// Drag and drop for the pipeline board, using the native HTML5 API.
//
// While a card is dragged over a column we move a placeholder to where it
// would land. On drop the card is moved there right away and the server is
// told the new status and index; LiveView then re-renders the board in the
// order the server stored.
const Board = {
  mounted() {
    this.dragged = null
    this.placeholder = document.createElement("li")
    this.placeholder.className = "h-16 rounded-md border-2 border-dashed border-zinc-300"

    this.el.addEventListener("dragstart", e => {
      const card = e.target.closest("[data-id]")
      if (!card) return
      this.dragged = card
      e.dataTransfer.effectAllowed = "move"
      e.dataTransfer.setData("text/plain", card.dataset.id)
      requestAnimationFrame(() => card.classList.add("opacity-40"))
    })

    this.el.addEventListener("dragend", () => {
      if (this.dragged) this.dragged.classList.remove("opacity-40")
      this.placeholder.remove()
      this.dragged = null
    })

    this.el.addEventListener("dragover", e => {
      const zone = e.target.closest("[data-status]")?.querySelector("[data-dropzone]")
      if (!zone || !this.dragged) return
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"

      const after = this.cardAfter(zone, e.clientY)
      if (after) {
        zone.insertBefore(this.placeholder, after)
      } else {
        zone.appendChild(this.placeholder)
      }
    })

    this.el.addEventListener("drop", e => {
      const column = e.target.closest("[data-status]")
      if (!column || !this.dragged) return
      e.preventDefault()

      const zone = column.querySelector("[data-dropzone]")
      if (!this.placeholder.parentNode) zone.appendChild(this.placeholder)
      const cards = [...zone.children].filter(el => el !== this.dragged)
      const index = cards.indexOf(this.placeholder)

      zone.insertBefore(this.dragged, this.placeholder)
      this.placeholder.remove()

      this.pushEvent("move", {
        id: this.dragged.dataset.id,
        status: column.dataset.status,
        index: index
      })
    })
  },

  // The first card whose middle is below the pointer, or null to drop at the end.
  cardAfter(zone, y) {
    const cards = [...zone.querySelectorAll("[data-id]")].filter(el => el !== this.dragged)
    return cards.find(card => {
      const box = card.getBoundingClientRect()
      return y < box.top + box.height / 2
    }) || null
  }
}

export default Board
