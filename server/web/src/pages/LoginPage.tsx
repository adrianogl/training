import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { AuthLayout } from '../components/AuthLayout'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { TEXT } from '../constants'
import { errorText } from '../errors'
import type { SignInProps } from './pages.types'

export function LoginPage({ onSignedIn }: SignInProps) {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [persistent, setPersistent] = useState(true)
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    const result = await api.login(email, password)
    setBusy(false)
    if (result.ok) {
      onSignedIn(result.value, persistent)
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <AuthLayout>
      <form className="form" onSubmit={submit}>
        <div>
          <h1>{TEXT.loginTitle}</h1>
          <p className="muted">{TEXT.loginSubtitle}</p>
        </div>
        <Field label={TEXT.email} type="email" value={email} onChange={setEmail} autoComplete="email" />
        <Field label={TEXT.password} type="password" value={password} onChange={setPassword} autoComplete="current-password" />
        <div className="row">
          <label className="check">
            <input type="checkbox" checked={persistent} onChange={(event) => setPersistent(event.target.checked)} />
            {TEXT.keepSignedIn}
          </label>
          <Link to="forgot">{TEXT.forgotLink}</Link>
        </div>
        <Message error={error} />
        <button className="btn btn-primary" type="submit" disabled={busy || email === '' || password === ''}>
          {TEXT.enter}
        </button>
        <p className="center">
          {TEXT.noAccount} <Link to="signup">{TEXT.create}</Link>
        </p>
      </form>
    </AuthLayout>
  )
}
