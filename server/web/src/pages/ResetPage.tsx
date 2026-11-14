import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { AuthLayout } from '../components/AuthLayout'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { PASSWORD_MIN_LENGTH, TEXT } from '../constants'
import { errorText } from '../errors'
import { queryParam } from '../router'

export function ResetPage() {
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState<string>()
  const [done, setDone] = useState(false)
  const [busy, setBusy] = useState(false)
  const token = queryParam('token') ?? ''

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
    const result = await api.reset(token, password)
    setBusy(false)
    if (result.ok) {
      setDone(true)
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <AuthLayout>
      <form className="form" onSubmit={submit}>
        <div>
          <h1>{TEXT.resetTitle}</h1>
          <p className="muted">{TEXT.resetSubtitle}</p>
        </div>
        {done ? (
          <Message notice={TEXT.resetDone} />
        ) : (
          <>
            <Field label={TEXT.newPassword} type="password" value={password} onChange={setPassword} autoComplete="new-password" />
            <Field label={TEXT.confirmNewPassword} type="password" value={confirmation} onChange={setConfirmation} autoComplete="new-password" />
            <Message error={error} />
            <button className="btn btn-primary" type="submit" disabled={busy || password === ''}>
              {TEXT.save}
            </button>
          </>
        )}
        <p className="center">
          <Link to="login">{TEXT.backToLogin}</Link>
        </p>
      </form>
    </AuthLayout>
  )
}
