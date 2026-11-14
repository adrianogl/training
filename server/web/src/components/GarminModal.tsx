import { useEffect, useRef, useState, type FormEvent } from 'react'
import { api } from '../api'
import { GARMIN_TEXT } from '../constants'
import { errorText } from '../errors'
import type { GarminModalStep } from '../types'
import type { GarminModalProps } from './components.types'
import { Field } from './Field'
import { Logo } from './Logo'
import { Message } from './Message'

export function GarminModal({ onClose }: GarminModalProps) {
  const dialog = useRef<HTMLDialogElement>(null)
  const [step, setStep] = useState<GarminModalStep>('credentials')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [code, setCode] = useState('')
  const [error, setError] = useState<string>()
  const [busy, setBusy] = useState(false)

  useEffect(() => {
    dialog.current?.showModal()
  }, [])

  async function submitCredentials(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    const result = await api.garminConnect(email, password)
    setBusy(false)
    setPassword('')
    if (!result.ok) {
      setError(errorText(result.error))
      return
    }
    setStep(result.value.status === 'needs_code' ? 'code' : 'done')
  }

  async function submitCode(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    const result = await api.garminVerify(code.trim())
    setBusy(false)
    if (result.ok) {
      setStep('done')
    } else if (result.error === 'garmin_login_expired') {
      setStep('credentials')
      setError(errorText(result.error))
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <dialog ref={dialog} className="modal" aria-label={GARMIN_TEXT.title} onCancel={() => onClose(step === 'done')}>
      <div className="row">
        <div className="logo">
          <Logo />
          <span className="muted" aria-hidden="true">
            ⇄
          </span>
          <span className="pill">Garmin Connect</span>
        </div>
        <button className="btn btn-small" type="button" aria-label={GARMIN_TEXT.close} onClick={() => onClose(step === 'done')}>
          ×
        </button>
      </div>
      {step === 'credentials' && (
        <form className="form" onSubmit={submitCredentials}>
          <div>
            <span className="muted">{GARMIN_TEXT.step1}</span>
            <h1>{GARMIN_TEXT.title}</h1>
            <p className="muted">{GARMIN_TEXT.subtitle}</p>
          </div>
          <Field label={GARMIN_TEXT.emailLabel} type="email" value={email} onChange={setEmail} autoComplete="username" />
          <Field label={GARMIN_TEXT.passwordLabel} type="password" value={password} onChange={setPassword} autoComplete="current-password" />
          <p className="note">{GARMIN_TEXT.privacy}</p>
          <Message error={error} />
          <div className="actions" style={{ justifyContent: 'flex-end' }}>
            <button className="btn" type="button" onClick={() => onClose(false)}>
              {GARMIN_TEXT.cancel}
            </button>
            <button className="btn btn-primary" type="submit" disabled={busy || email === '' || password === ''}>
              {GARMIN_TEXT.continue}
            </button>
          </div>
        </form>
      )}
      {step === 'code' && (
        <form className="form" onSubmit={submitCode}>
          <div>
            <span className="muted">{GARMIN_TEXT.step2}</span>
            <h1>{GARMIN_TEXT.codeTitle}</h1>
            <p className="muted">{GARMIN_TEXT.codeText}</p>
          </div>
          <label className="field">
            {GARMIN_TEXT.codeLabel}
            <input className="code-input" inputMode="numeric" autoComplete="one-time-code" maxLength={8} value={code} onChange={(event) => setCode(event.target.value)} />
          </label>
          <Message error={error} />
          <div className="actions" style={{ justifyContent: 'flex-end' }}>
            <button className="btn btn-primary" type="submit" disabled={busy || code.trim().length < 4}>
              {GARMIN_TEXT.confirm}
            </button>
          </div>
        </form>
      )}
      {step === 'done' && (
        <div className="form">
          <h1>{GARMIN_TEXT.doneTitle}</h1>
          <p className="muted">{GARMIN_TEXT.doneText}</p>
          <div className="actions" style={{ justifyContent: 'flex-end' }}>
            <button className="btn btn-primary" type="button" onClick={() => onClose(true)}>
              {GARMIN_TEXT.finish}
            </button>
          </div>
        </div>
      )}
    </dialog>
  )
}
