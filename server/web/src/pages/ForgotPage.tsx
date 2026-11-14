import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { AuthLayout } from '../components/AuthLayout'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { TEXT } from '../constants'
import { errorText } from '../errors'

export function ForgotPage() {
  const [email, setEmail] = useState('')
  const [sent, setSent] = useState(false)
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    const result = await api.forgot(email)
    setBusy(false)
    if (result.ok) {
      setSent(true)
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <AuthLayout>
      <form className="form" onSubmit={submit}>
        {sent ? (
          <div>
            <h1>{TEXT.forgotSentTitle}</h1>
            <p className="muted">{TEXT.forgotSentText}</p>
          </div>
        ) : (
          <>
            <div>
              <h1>{TEXT.forgotTitle}</h1>
              <p className="muted">{TEXT.forgotSubtitle}</p>
            </div>
            <Field label={TEXT.email} type="email" value={email} onChange={setEmail} autoComplete="email" />
            <Message error={error} />
            <button className="btn btn-primary" type="submit" disabled={busy || email === ''}>
              {TEXT.sendLink}
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
