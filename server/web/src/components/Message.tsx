import type { MessageProps } from './components.types'

export function Message({ error, notice }: MessageProps) {
  if (error !== undefined) {
    return (
      <p className="message message-error" role="alert">
        {error}
      </p>
    )
  }
  if (notice !== undefined) {
    return (
      <p className="message message-notice" role="status">
        {notice}
      </p>
    )
  }
  return null
}
