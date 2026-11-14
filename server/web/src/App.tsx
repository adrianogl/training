import { useEffect, useState } from 'react'
import { api } from './api'
import { AppLayout } from './components/AppLayout'
import { PUBLIC_ROUTES } from './constants'
import { AdminPage } from './pages/AdminPage'
import { ConfirmPage } from './pages/ConfirmPage'
import { EvolutionPage } from './pages/EvolutionPage'
import { GoalsPage } from './pages/GoalsPage'
import { RacesPage } from './pages/RacesPage'
import { ForgotPage } from './pages/ForgotPage'
import { InvitePage } from './pages/InvitePage'
import { LoginPage } from './pages/LoginPage'
import { PasswordPage } from './pages/PasswordPage'
import { ResetPage } from './pages/ResetPage'
import { SettingsPage } from './pages/SettingsPage'
import { SignupPage } from './pages/SignupPage'
import { TodayPage } from './pages/TodayPage'
import { WorkoutsPage } from './pages/WorkoutsPage'
import { navigate, useRoute } from './router'
import { useGarminSync } from './useGarminSync'
import { clearToken, readToken, saveToken } from './session'
import type { AuthResult, Route, User } from './types'

export function App() {
  const route = useRoute()
  const [token, setToken] = useState(readToken)
  const [user, setUser] = useState<User | null>(null)
  const signedIn = token !== null
  const sync = useGarminSync(signedIn)

  useEffect(() => {
    if (token === null) {
      return
    }
    void api.me().then((result) => {
      if (result.ok) {
        setUser(result.value.user)
      } else if (result.status === 401) {
        clearToken()
        setToken(null)
      }
    })
  }, [token])

  const target = resolve(route, signedIn)
  useEffect(() => {
    if (target !== route) {
      navigate(target, true)
    }
  }, [target, route])

  function signIn(result: AuthResult, persistent: boolean) {
    saveToken(result.token, persistent)
    setToken(result.token)
    setUser(result.user)
    navigate('today')
  }

  function signOut() {
    clearToken()
    setToken(null)
    setUser(null)
    navigate('login')
  }

  switch (target) {
    case 'login':
      return <LoginPage onSignedIn={signIn} />
    case 'signup':
      return <SignupPage onSignedIn={signIn} />
    case 'forgot':
      return <ForgotPage />
    case 'reset':
      return <ResetPage />
    case 'confirm':
      return <ConfirmPage signedIn={signedIn} />
    case 'invite':
      return <InvitePage onSignedIn={signIn} />
    default:
      return (
        <AppLayout route={target} user={user} sync={sync.state}>
          {target === 'settings' && user !== null && <SettingsPage user={user} onUserChange={setUser} onSignedOut={signOut} />}
          {target === 'password' && <PasswordPage />}
          {target === 'admin' && user?.admin === true && <AdminPage />}
          {target === 'today' && <TodayPage version={sync.version} syncing={sync.state.kind === 'running'} />}
          {target === 'workouts' && <WorkoutsPage version={sync.version} syncing={sync.state.kind === 'running'} />}
          {target === 'evolution' && <EvolutionPage version={sync.version} syncing={sync.state.kind === 'running'} />}
          {target === 'races' && <RacesPage version={sync.version} syncing={sync.state.kind === 'running'} />}
          {target === 'goals' && <GoalsPage version={sync.version} syncing={sync.state.kind === 'running'} />}
        </AppLayout>
      )
  }
}

export function resolve(route: Route | undefined, signedIn: boolean): Route {
  if (route === undefined) {
    return signedIn ? 'today' : 'login'
  }
  if (PUBLIC_ROUTES.includes(route)) {
    return signedIn && (route === 'login' || route === 'signup' || route === 'invite') ? 'today' : route
  }
  return signedIn ? route : 'login'
}
