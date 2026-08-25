let listener: ((msg: string) => void) | null = null

export function onFlash(cb: (msg: string) => void): () => void {
  listener = cb
  return () => {
    listener = null
  }
}

/** Shows a short toast-style confirmation at the bottom of the screen. */
export function flash(msg: string): void {
  listener?.(msg)
}
