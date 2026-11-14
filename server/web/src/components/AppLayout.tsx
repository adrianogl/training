import { ADMIN_TEXT, DATA_TEXT, NAV_ITEMS } from '../constants'
import type { AppLayoutProps } from './components.types'
import { Link } from './Link'
import { Logo } from './Logo'

export function AppLayout({ route, user, sync, children }: AppLayoutProps) {
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
          {user?.admin === true && (
            <Link to="admin" className="nav-link" current={route === 'admin'}>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
                <path d="M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z" />
              </svg>
              {ADMIN_TEXT.nav}
            </Link>
          )}
        </div>
        {user !== null && (
          <div className="nav-user">
            <span>{user.name}</span>
            <span className="muted">
              {sync.kind === 'running' && DATA_TEXT.syncing(sync.days)}
              {sync.kind === 'done' && DATA_TEXT.synced(sync.at.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' }))}
              {sync.kind === 'error' && sync.message}
              {sync.kind === 'disconnected' && <Link to="settings">{DATA_TEXT.connect}</Link>}
            </span>
          </div>
        )}
      </nav>
      <main className="main">{children}</main>
    </div>
  )
}
