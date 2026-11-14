import { NAV_ITEMS } from '../constants'
import type { AppLayoutProps } from './components.types'
import { Link } from './Link'
import { Logo } from './Logo'

export function AppLayout({ route, user, children }: AppLayoutProps) {
  return (
    <div className="shell">
      <nav className="nav" aria-label="Áreas">
        <Logo />
        <div className="nav-links">
          {NAV_ITEMS.map((item) => (
            <Link key={item.route} to={item.route} className="nav-link" current={route === item.route || (item.route === 'settings' && route === 'password')}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d={item.icon} />
              </svg>
              {item.label}
            </Link>
          ))}
        </div>
        {user !== null && (
          <div className="nav-user">
            <span>{user.name}</span>
            <span className="muted">{user.email}</span>
          </div>
        )}
      </nav>
      <main className="main">{children}</main>
    </div>
  )
}
