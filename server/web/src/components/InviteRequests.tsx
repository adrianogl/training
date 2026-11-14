import { INVITE_REQUEST_TEXT } from '../constants'
import { dayMonth } from '../format'
import type { InviteRequestsProps } from './components.types'

export function InviteRequests({ requests, onAct }: InviteRequestsProps) {
  return (
    <div className="card">
      <div className="row"><span className="label">{INVITE_REQUEST_TEXT.title}</span>{requests.length > 0 && <span className="accent-text small">{INVITE_REQUEST_TEXT.count(requests.length)}</span>}</div>
      {requests.length === 0 && <p className="muted" style={{ margin: 0 }}>{INVITE_REQUEST_TEXT.empty}</p>}
      {requests.map((request) => (
        <div className="request" key={request.id}>
          <div className="request-who">
            <b>{request.name}</b>
            <span className="muted small">{request.email} · {dayMonth(request.createdAt.slice(0, 10))}</span>
          </div>
          <div className="actions">
            <button type="button" className="btn btn-small btn-primary" onClick={() => onAct(request, 'invite')}>{INVITE_REQUEST_TEXT.invite}</button>
            <button type="button" className="btn btn-small" onClick={() => onAct(request, 'decline')}>{INVITE_REQUEST_TEXT.decline}</button>
          </div>
          <span className="request-msg small">
            <span className={`pill${request.watch === 'garmin' ? '' : ' pill-pending'}`}>{INVITE_REQUEST_TEXT.watches[request.watch] ?? request.watch}</span> {request.message === '' ? INVITE_REQUEST_TEXT.noMessage : request.message}
          </span>
        </div>
      ))}
    </div>
  )
}
