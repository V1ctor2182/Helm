// 二段删除确认(无 modal):第一次点击武装(按钮变「确认」),3s 内再点同一目标才放行。
// 比 window.confirm 贴座舱,比直接删多一道护栏(backlog: 删除无确认/undo)。

export class ConfirmGate {
  pending = $state<string | null>(null)
  #timer: ReturnType<typeof setTimeout> | null = null

  /** 返回 true = 已确认放行;false = 刚武装,等第二次点击。 */
  confirm(key: string): boolean {
    if (this.pending === key) {
      this.reset()
      return true
    }
    if (this.#timer) clearTimeout(this.#timer)
    this.pending = key
    this.#timer = setTimeout(() => (this.pending = null), 3000)
    return false
  }

  reset(): void {
    if (this.#timer) clearTimeout(this.#timer)
    this.#timer = null
    this.pending = null
  }
}
