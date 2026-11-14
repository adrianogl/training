import { useEffect, useState, type FormEvent } from 'react'
import { api } from '../api'
import { Message } from '../components/Message'
import { ADMIN_TEXT } from '../constants'
import { errorText } from '../errors'
import type { AdminData, InviteChannel, InviteResult, InviteRow } from '../types'
import { formatBytes, whatsappUrl } from '../whatsapp'

const CHANNELS: InviteChannel[] = ['email', 'whatsapp', 'link']

function shortDate(iso: string): string {
  return new Date(iso).toLocaleString('pt-BR', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' })
}

export function AdminPage() {
  const [data, setData] = useState<AdminData | null>(null)
  const [error, setError] = useState<string>()
  const [name, setName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [channel, setChannel] = useState<InviteChannel>('whatsapp')
  const [result, setResult] = useState<InviteResult | null>(null)
  const [notice, setNotice] = useState<string>()
  const [busy, setBusy] = useState(false)

  async function load() {
    const response = await api.adminOverview()
    if (response.ok) {
      setData(response.value)
    } else {
      setError(errorText(response.error))
    }
  }

  useEffect(() => {
    void load()
  }, [])

  async function submit(event: FormEvent) {
    event.preventDefault()
    setBusy(true)
    setError(undefined)
    setNotice(undefined)
    const response = await api.adminInvite(name.trim(), channel, channel === 'email' ? email.trim() : undefined)
    setBusy(false)
    if (!response.ok) {
      setError(errorText(response.error))
      return
    }
    setResult(response.value)
    void load()
  }

  async function act(invite: InviteRow, action: 'cancel' | 'renew') {
    const response = await api.adminInviteAction(invite.id, action)
    if (!response.ok) {
      setError(errorText(response.error))
      return
    }
    if ('link' in response.value) {
      setChannel(invite.channel)
      setName(invite.name)
      setResult(response.value)
    }
    void load()
  }

  async function remove(id: string) {
    if (!window.confirm(ADMIN_TEXT.removeConfirm)) {
      return
    }
    const response = await api.adminRemoveUser(id)
    if (response.ok) {
      void load()
    } else {
      setError(errorText(response.error))
    }
  }

  async function copy(text: string) {
    try {
      await navigator.clipboard.writeText(text)
      setNotice(ADMIN_TEXT.copied)
    } catch {
      setNotice(text)
    }
  }

  const overview = data?.overview
  const maxHour = Math.max(1, ...(overview?.requestsByHour.map((row) => row.count) ?? [1]))
  return (
    <section className="page admin">
      <div>
        <h1>{ADMIN_TEXT.title}</h1>
        <p className="muted" style={{ fontSize: 15, margin: '4px 0 0' }}>{ADMIN_TEXT.subtitle}</p>
      </div>
      <Message error={error} />
      {overview && (
        <div className="metrics">
          <div className="metric"><span>{ADMIN_TEXT.accounts}</span><b>{overview.accounts} <small>{ADMIN_TEXT.of} {overview.maxAccounts}</small></b><div className="meter"><i style={{ width: `${Math.min(100, (overview.accounts / overview.maxAccounts) * 100)}%` }} /></div></div>
          <div className="metric"><span>{ADMIN_TEXT.pending}</span><b>{overview.pendingInvites}</b>{overview.expiringInvites > 0 && <small>{overview.expiringInvites} {ADMIN_TEXT.expiring}</small>}</div>
          <div className="metric"><span>{ADMIN_TEXT.active}</span><b>{overview.activeAccounts}</b><small>{ADMIN_TEXT.activeHint}</small></div>
          <div className="metric"><span>{ADMIN_TEXT.garmin}</span><b>{overview.garminConnected} <small>{ADMIN_TEXT.of} {overview.accounts}</small></b></div>
          <div className="metric"><span>{ADMIN_TEXT.requests}</span><b>{overview.requests24h.toLocaleString('pt-BR')}</b><small className={overview.errors24h > 0 ? 'bad' : ''}>{overview.errors24h} {ADMIN_TEXT.errors}</small></div>
        </div>
      )}
      <div className="admin-grid">
        <form className="card" onSubmit={submit}>
          <span className="label">{ADMIN_TEXT.invite}</span>
          <label className="field">{ADMIN_TEXT.name}<input value={name} onChange={(event) => setName(event.target.value)} autoComplete="off" /></label>
          <div className="segmented" role="radiogroup" aria-label="Enviar por">
            {CHANNELS.map((item) => (
              <button key={item} type="button" role="radio" aria-checked={channel === item} className={channel === item ? 'on' : ''} onClick={() => { setChannel(item); setResult(null) }}>
                {ADMIN_TEXT.channels[item]}
              </button>
            ))}
          </div>
          {channel === 'email' && <label className="field">{ADMIN_TEXT.email}<input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="off" /></label>}
          {channel === 'whatsapp' && <label className="field">{ADMIN_TEXT.phone}<input inputMode="tel" value={phone} onChange={(event) => setPhone(event.target.value)} autoComplete="off" /></label>}
          <span className="muted">{ADMIN_TEXT.inviteHint}</span>
          <button className="btn btn-primary" type="submit" disabled={busy || name.trim() === '' || (channel === 'email' && email.trim() === '')}>{ADMIN_TEXT.actions[channel]}</button>
          {result && (
            <div className="invite-result">
              <strong>{result.mailed ? `${ADMIN_TEXT.mailed} ${result.invite.email}.` : channel === 'whatsapp' ? ADMIN_TEXT.whatsappReady : ADMIN_TEXT.linkReady}</strong>
              {channel === 'whatsapp' && <p className="message-box">{result.message}</p>}
              <div className="actions">
                <button className="btn btn-small" type="button" onClick={() => copy(result.link)}>{ADMIN_TEXT.copy}</button>
                {channel !== 'email' && <button className="btn btn-small" type="button" onClick={() => copy(result.message)}>{ADMIN_TEXT.copyMessage}</button>}
                {channel === 'whatsapp' && <a className="btn btn-small btn-whatsapp" href={whatsappUrl(result.message, phone)} target="_blank" rel="noreferrer">{ADMIN_TEXT.openWhatsapp}</a>}
              </div>
              <Message notice={notice} />
            </div>
          )}
        </form>
        <div className="card">
          <span className="label">{ADMIN_TEXT.invites}</span>
          {data && data.invites.length === 0 && <p className="muted">{ADMIN_TEXT.noInvites}</p>}
          {data && data.invites.length > 0 && (
            <div className="table-wrap"><table className="table">
              <thead><tr><th>{ADMIN_TEXT.columns.name}</th><th>{ADMIN_TEXT.columns.channel}</th><th>{ADMIN_TEXT.columns.status}</th><th /></tr></thead>
              <tbody>
                {data.invites.map((invite) => (
                  <tr key={invite.id}>
                    <td>{invite.name}</td>
                    <td className="muted">{ADMIN_TEXT.channels[invite.channel]}</td>
                    <td><span className={`pill pill-${invite.status}`}>{ADMIN_TEXT.statuses[invite.status]}{invite.status === 'pending' ? ` · até ${shortDate(invite.expiresAt)}` : ''}</span></td>
                    <td className="right">
                      {invite.status === 'pending' && <button className="btn btn-small" type="button" onClick={() => act(invite, 'cancel')}>{ADMIN_TEXT.cancel}</button>}
                      {(invite.status === 'expired' || invite.status === 'canceled') && <button className="btn btn-small" type="button" onClick={() => act(invite, 'renew')}>{ADMIN_TEXT.renew}</button>}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table></div>
          )}
        </div>
      </div>
      {data && (
        <div className="card">
          <span className="label">{ADMIN_TEXT.users}</span>
          <div className="table-wrap"><table className="table" style={{ minWidth: 760 }}>
            <thead><tr><th>{ADMIN_TEXT.columns.name}</th><th>{ADMIN_TEXT.columns.role}</th><th>{ADMIN_TEXT.columns.access}</th><th>{ADMIN_TEXT.columns.garmin}</th><th>{ADMIN_TEXT.columns.lastSeen}</th><th>{ADMIN_TEXT.columns.data}</th><th /></tr></thead>
            <tbody>
              {data.users.map((user) => (
                <tr key={user.id}>
                  <td>{user.name}<div className="muted">{user.email}</div></td>
                  <td className={user.admin ? 'accent' : ''}>{user.admin ? ADMIN_TEXT.adminRole : ADMIN_TEXT.role[user.role]}</td>
                  <td className="muted">{ADMIN_TEXT.access[user.role]}</td>
                  <td className={user.garminConnected ? '' : 'muted'}>{user.garminConnected ? ADMIN_TEXT.garminOn : ADMIN_TEXT.garminOff}</td>
                  <td className="muted">{user.lastSeenAt ? shortDate(user.lastSeenAt) : ADMIN_TEXT.never}</td>
                  <td className="muted">{formatBytes(user.dataBytes)}</td>
                  <td className="right">{!user.admin && <button className="btn btn-small btn-danger" type="button" onClick={() => remove(user.id)}>{ADMIN_TEXT.remove}</button>}</td>
                </tr>
              ))}
            </tbody>
          </table></div>
        </div>
      )}
      {overview && (
        <div className="card">
          <div className="row"><span className="label">{ADMIN_TEXT.usage}</span>{overview.databaseBytes !== null && <span className="muted">{ADMIN_TEXT.database}: {formatBytes(overview.databaseBytes)}</span>}</div>
          <div className="bars" aria-hidden="true">
            {overview.requestsByHour.map((row) => <i key={row.hour} style={{ height: `${(row.count / maxHour) * 100}%` }} title={`${shortDate(row.hour)}: ${row.count}`} />)}
          </div>
          <div className="route-counts">
            {overview.requestsByRoute.map((row) => <span key={row.route}>{row.route}: <b>{row.count}</b></span>)}
          </div>
        </div>
      )}
    </section>
  )
}
