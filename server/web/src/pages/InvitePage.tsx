import { useEffect, useState, type FormEvent } from 'react'
import { api } from '../api'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Logo } from '../components/Logo'
import { Message } from '../components/Message'
import { PASSWORD_MIN_LENGTH, TEXT, INVITE_TEXT } from '../constants'
import { errorText } from '../errors'
import { queryParam } from '../router'
import type { InvitePreview } from '../types'
import type { SignInProps } from './pages.types'

export function InvitePage({ onSignedIn }: SignInProps) {
  const token = queryParam('c') ?? ''
  const [preview, setPreview] = useState<InvitePreview | null | undefined>(undefined)
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    void api.invitePreview(token).then((result) => {
      if (result.ok) {
        setPreview(result.value)
        setName(result.value.name)
        setEmail(result.value.email ?? '')
      } else {
        setPreview(null)
      }
    })
  }, [token])

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
    const result = await api.signup(name, email, password, token)
    setBusy(false)
    if (result.ok) {
      onSignedIn(result.value, true)
    } else {
      setError(errorText(result.error))
    }
  }

  const until = preview?.expiresAt === undefined ? '' : new Date(preview.expiresAt).toLocaleDateString('pt-BR', { day: 'numeric', month: 'long' })
  return (
    <div className="auth">
      <aside className="auth-aside">
        <Logo />
        <div>
          <span className="label" style={{ color: 'var(--accent)' }}>{INVITE_TEXT.eyebrow}</span>
          <h2 style={{ marginTop: 12 }}>{preview?.inviterName ? INVITE_TEXT.title(preview.inviterName) : INVITE_TEXT.fallbackInviter}</h2>
          <p className="muted" style={{ fontSize: 16, maxWidth: 460 }}>{INVITE_TEXT.pitch}</p>
        </div>
        <span className="muted">{preview ? INVITE_TEXT.validUntil(until) : TEXT.privacy}</span>
      </aside>
      <main className="auth-main">
        {preview === undefined && <p className="muted">{INVITE_TEXT.loading}</p>}
        {preview === null && (
          <div className="form">
            <h1>{INVITE_TEXT.invalidTitle}</h1>
            <p className="muted">{INVITE_TEXT.invalidText}</p>
            <p className="center"><Link to="login">{TEXT.backToLogin}</Link></p>
          </div>
        )}
        {preview && (
          <form className="form" onSubmit={submit}>
            <div>
              <h1>{INVITE_TEXT.formTitle}</h1>
              <p className="muted">{INVITE_TEXT.formSubtitle}</p>
            </div>
            <Field label={TEXT.name} value={name} onChange={setName} autoComplete="name" />
            <Field label={TEXT.email} type="email" value={email} onChange={setEmail} autoComplete="email" />
            <Field label={TEXT.password} type="password" value={password} onChange={setPassword} autoComplete="new-password" />
            <span className="muted">{TEXT.passwordHint}</span>
            <Field label={TEXT.confirmPassword} type="password" value={confirmation} onChange={setConfirmation} autoComplete="new-password" />
            <p className="note">{preview?.appAccess ? INVITE_TEXT.appAccess : INVITE_TEXT.webOnly}</p>
            <Message error={error} />
            <button className="btn btn-primary" type="submit" disabled={busy || name === '' || email === '' || password === ''}>
              {TEXT.create}
            </button>
            <p className="center">
              {TEXT.haveAccount} <Link to="login">{TEXT.enter}</Link>
            </p>
          </form>
        )}
      </main>
    </div>
  )
}
