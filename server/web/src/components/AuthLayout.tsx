import { TEXT } from '../constants'
import type { AuthLayoutProps } from './components.types'
import { Logo } from './Logo'

export function AuthLayout({ children }: AuthLayoutProps) {
  return (
    <div className="auth">
      <aside className="auth-aside">
        <Logo />
        <div>
          <h2>{TEXT.tagline}</h2>
          <p className="muted" style={{ fontSize: 16, maxWidth: 460 }}>
            {TEXT.pitch}
          </p>
        </div>
        <span className="muted">{TEXT.privacy}</span>
      </aside>
      <main className="auth-main">{children}</main>
    </div>
  )
}
