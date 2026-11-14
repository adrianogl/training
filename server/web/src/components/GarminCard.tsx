import { useEffect, useState } from 'react'
import { api } from '../api'
import { GARMIN_TEXT } from '../constants'
import { errorText } from '../errors'
import type { GarminStatus } from '../types'
import { GarminModal } from './GarminModal'
import { Message } from './Message'

export function GarminCard() {
  const [status, setStatus] = useState<GarminStatus | null>(null)
  const [open, setOpen] = useState(false)
  const [error, setError] = useState<string>()

  async function load() {
    const result = await api.garminStatus()
    if (result.ok) {
      setStatus(result.value)
    } else {
      setError(errorText(result.error))
    }
  }

  useEffect(() => {
    void load()
  }, [])

  async function disconnect() {
    if (!window.confirm(GARMIN_TEXT.disconnectConfirm)) {
      return
    }
    const result = await api.garminDisconnect()
    if (result.ok) {
      setStatus({ connected: false, connectedAt: null })
    } else {
      setError(errorText(result.error))
    }
  }

  const connected = status?.connected === true
  return (
    <div className="card">
      <span className="label">{GARMIN_TEXT.section}</span>
      <div className="row">
        <div>
          <div style={{ fontWeight: 600, color: connected ? 'var(--accent)' : 'var(--text)' }}>
            {connected ? GARMIN_TEXT.connected : GARMIN_TEXT.disconnected}
          </div>
          {connected && status?.connectedAt !== null && status?.connectedAt !== undefined && (
            <span className="muted">
              {GARMIN_TEXT.connectedSince} {new Date(status.connectedAt).toLocaleDateString('pt-BR')}
            </span>
          )}
        </div>
        {status !== null &&
          (connected ? (
            <button className="btn btn-danger" type="button" onClick={disconnect}>
              {GARMIN_TEXT.disconnect}
            </button>
          ) : (
            <button className="btn btn-primary" type="button" onClick={() => setOpen(true)}>
              {GARMIN_TEXT.connect}
            </button>
          ))}
      </div>
      <Message error={error} />
      {open && (
        <GarminModal
          onClose={(done) => {
            setOpen(false)
            if (done) {
              void load()
            }
          }}
        />
      )}
    </div>
  )
}
