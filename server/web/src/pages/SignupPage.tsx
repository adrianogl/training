import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { AuthLayout } from '../components/AuthLayout'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { PASSWORD_MIN_LENGTH, TEXT } from '../constants'
import { errorText } from '../errors'
import type { SignInProps } from './pages.types'

export function SignupPage({ onSignedIn }: SignInProps) {
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    if ([...password].length < PASSWORD_MIN_LENGTH) {
      setError(TEXT.shortPassword)
      return
    }
    if (password !== confirmation) {
      setError(TEXT.mismatch)
      return
    }
    setBusy(true)
    setError(undefined)
    const result = await api.signup(name, email, password)
    setBusy(false)
    if (result.ok) {
      onSignedIn(result.value, true)
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <AuthLayout>
      <form className="form" onSubmit={submit}>
        <div>
          <h1>{TEXT.signupTitle}</h1>
          <p className="muted">{TEXT.signupSubtitle}</p>
        </div>
        <Field label={TEXT.name} value={name} onChange={setName} autoComplete="name" />
        <Field label={TEXT.email} type="email" value={email} onChange={setEmail} autoComplete="email" />
        <Field label={TEXT.password} type="password" value={password} onChange={setPassword} autoComplete="new-password" />
        <span className="muted">{TEXT.passwordHint}</span>
        <Field label={TEXT.confirmPassword} type="password" value={confirmation} onChange={setConfirmation} autoComplete="new-password" />
        <Message error={error} />
        <button className="btn btn-primary" type="submit" disabled={busy || name === '' || email === '' || password === ''}>
          {TEXT.create}
        </button>
        <p className="center">
          {TEXT.haveAccount} <Link to="login">{TEXT.enter}</Link>
        </p>
      </form>
    </AuthLayout>
  )
}
