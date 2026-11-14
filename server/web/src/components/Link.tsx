import { hrefFor, navigate } from '../router'
import type { LinkProps } from './components.types'

export function Link({ to, className, current, children }: LinkProps) {
  return (
    <a
      href={hrefFor(to)}
      className={className}
      aria-current={current === true ? 'page' : undefined}
      onClick={(event) => {
        if (event.metaKey || event.ctrlKey || event.shiftKey || event.button !== 0) {
          return
        }
        event.preventDefault()
        navigate(to)
      }}
    >
      {children}
    </a>
  )
}
