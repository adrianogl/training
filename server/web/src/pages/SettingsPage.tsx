import { useEffect, useState } from 'react'
import { api } from '../api'
import { GarminCard } from '../components/GarminCard'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { TEXT } from '../constants'
import { errorText } from '../errors'
import type { SessionInfo } from '../types'
import type { SettingsProps } from './pages.types'

export function SettingsPage({ user, onUserChange, onSignedOut }: SettingsProps) {
  const [name, setName] = useState(user.name)
  const [sessions, setSessions] = useState<SessionInfo[]>([])
  const [error, setError] = useState<string>()
  const [notice, setNotice] = useState<string>()

  useEffect(() => {
    void api.sessions().then((result) => {
      if (result.ok) {
        setSessions(result.value.sessions)
      }
    })
  }, [])

  async function saveName() {
    const trimmed = name.trim()
    if (trimmed === '' || trimmed === user.name) {
      return
    }
    const result = await api.rename(trimmed)
    if (result.ok) {
      onUserChange(result.value.user)
    } else {
      setError(errorText(result.error))
    }
  }

  async function endSession(id: string) {
    const result = await api.endSession(id)
    if (result.ok) {
      setSessions((current) => current.filter((session) => session.id !== id))
    }
  }

  async function resend() {
    const result = await api.resendVerification()
    if (result.ok) {
      setNotice(TEXT.resent)
    } else {
      setError(errorText(result.error))
    }
  }

  async function signOut() {
    await api.logout()
    onSignedOut()
  }

  async function deleteAccount() {
    if (!window.confirm(TEXT.deleteConfirm)) {
      return
    }
    const result = await api.deleteAccount()
    if (result.ok) {
      onSignedOut()
    } else {
      setError(errorText(result.error))
    }
  }

  return (
    <section className="page">
      <h1>{TEXT.settingsTitle}</h1>
      <div className="card">
        <span className="label">{TEXT.account}</span>
        <div className="row">
          <label className="field" style={{ flex: '1 1 260px' }}>
            {TEXT.name}
            <input value={name} autoComplete="name" onChange={(event) => setName(event.target.value)} onBlur={saveName} />
          </label>
          <div className="actions">
            <Link to="password" className="btn">
              {TEXT.changePassword}
            </Link>
            <button className="btn" type="button" onClick={signOut}>
              {TEXT.signOut}
            </button>
          </div>
        </div>
        <div className="row">
          <span className="muted">
            {user.email}
            {!user.emailVerified && ` · ${TEXT.unverified}`}
          </span>
          {!user.emailVerified && (
            <button className="btn btn-small" type="button" onClick={resend}>
              {TEXT.resend}
            </button>
          )}
        </div>
        <Message error={error} notice={notice} />
        {sessions.length > 0 && (
          <div className="sessions">
            <span className="muted">{TEXT.sessions}</span>
            {sessions.map((session) => (
              <div className="row" key={session.id}>
                <span>
                  {session.device}{' '}
                  <span className="muted">
                    · {session.current ? TEXT.thisSession : new Date(session.lastSeenAt).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' })}
                  </span>
                </span>
                {!session.current && (
                  <button className="btn btn-small" type="button" onClick={() => endSession(session.id)}>
                    {TEXT.endSession}
                  </button>
                )}
              </div>
            ))}
          </div>
        )}
        <div className="row divided">
          <span className="muted">{TEXT.deleteNote}</span>
          <button className="btn btn-danger" type="button" onClick={deleteAccount}>
            {TEXT.deleteAccount}
          </button>
        </div>
      </div>
      <GarminCard />
    </section>
  )
}
