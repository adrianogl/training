import { useState, type FormEvent } from 'react'
import { api } from '../api'
import { Field } from '../components/Field'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { PASSWORD_MIN_LENGTH, TEXT } from '../constants'
import { errorText } from '../errors'

export function PasswordPage() {
  const [current, setCurrent] = useState('')
  const [next, setNext] = useState('')
  const [confirmation, setConfirmation] = useState('')
  const [endOthers, setEndOthers] = useState(true)
  const [error, setError] = useState<string>()
  const [notice, setNotice] = useState<string>()
  const [busy, setBusy] = useState(false)

  async function submit(event: FormEvent) {
    event.preventDefault()
    setNotice(undefined)
    if ([...next].length < PASSWORD_MIN_LENGTH) {
      setError(TEXT.shortPassword)
      return
    }
    if (next !== confirmation) {
      setError(TEXT.mismatch)
      return
    }
    setBusy(true)
    setError(undefined)
    const result = await api.changePassword(current, next, endOthers)
    setBusy(false)
    if (result.ok) {
      setNotice(TEXT.passwordChanged)
      setCurrent('')
      setNext('')
      setConfirmation('')
    } else {
      setError(result.error === 'invalid_credentials' ? TEXT.wrongCurrent : errorText(result.error))
    }
  }

  return (
    <section className="page" style={{ maxWidth: 520 }}>
      <Link to="settings">{TEXT.backToSettings}</Link>
      <h1>{TEXT.changePassword}</h1>
      <form className="card" onSubmit={submit}>
        <Field label={TEXT.currentPassword} type="password" value={current} onChange={setCurrent} autoComplete="current-password" />
        <Field label={TEXT.newPassword} type="password" value={next} onChange={setNext} autoComplete="new-password" />
        <span className="muted">{TEXT.newPasswordHint}</span>
        <Field label={TEXT.confirmNewPassword} type="password" value={confirmation} onChange={setConfirmation} autoComplete="new-password" />
        <label className="check">
          <input type="checkbox" checked={endOthers} onChange={(event) => setEndOthers(event.target.checked)} />
          {TEXT.endOthers}
        </label>
        <Message error={error} notice={notice} />
        <div className="actions" style={{ justifyContent: 'flex-end' }}>
          <Link to="settings" className="btn">
            {TEXT.cancel}
          </Link>
          <button className="btn btn-primary" type="submit" disabled={busy || current === '' || next === ''}>
            {TEXT.savePassword}
          </button>
        </div>
      </form>
      <Link to="forgot">{TEXT.lostCurrent}</Link>
    </section>
  )
}
