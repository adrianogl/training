import { useEffect, useState } from 'react'
import { api } from './api'
import { AppLayout } from './components/AppLayout'
import { PAGE_TITLES, PUBLIC_ROUTES } from './constants'
import { ComingSoonPage } from './pages/ComingSoonPage'
import { ConfirmPage } from './pages/ConfirmPage'
import { ForgotPage } from './pages/ForgotPage'
import { LoginPage } from './pages/LoginPage'
import { PasswordPage } from './pages/PasswordPage'
import { ResetPage } from './pages/ResetPage'
import { SettingsPage } from './pages/SettingsPage'
import { SignupPage } from './pages/SignupPage'
import { navigate, useRoute } from './router'
import { clearToken, readToken, saveToken } from './session'
import type { AuthResult, Route, User } from './types'

export function App() {
  const route = useRoute()
  const [token, setToken] = useState(readToken)
  const [user, setUser] = useState<User | null>(null)
  const signedIn = token !== null

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
    default:
      return (
        <AppLayout route={target} user={user}>
          {target === 'settings' && user !== null && <SettingsPage user={user} onUserChange={setUser} onSignedOut={signOut} />}
          {target === 'password' && <PasswordPage />}
          {PAGE_TITLES[target] !== undefined && <ComingSoonPage title={PAGE_TITLES[target] ?? ''} />}
        </AppLayout>
      )
  }
}

export function resolve(route: Route | undefined, signedIn: boolean): Route {
  if (route === undefined) {
    return signedIn ? 'today' : 'login'
  }
  if (PUBLIC_ROUTES.includes(route)) {
    return signedIn && (route === 'login' || route === 'signup') ? 'today' : route
  }
  return signedIn ? route : 'login'
}
