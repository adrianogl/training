import { useState } from 'react'
import { TRAINER_TEXT } from '../constants'
import { dayMonth } from '../format'
import { triggerText, visibleChanges } from '../trainerView'
import type { TrainerChangesProps } from './components.types'

export function TrainerChanges({ versions }: TrainerChangesProps) {
  const ordered = [...versions].reverse()
  const [selected, setSelected] = useState<number | null>(null)
  const current = ordered.find((version) => version.number === selected) ?? ordered[0]
  if (current === undefined) return null
  const changes = visibleChanges(current)
  return (
    <div className="card trainer-changes">
      <span className="label">{TRAINER_TEXT.changesTitle.toUpperCase()}</span>
      {current.summary !== '' && <p>{current.summary}</p>}
      {changes.length === 0 ? (
        <p className="muted">{TRAINER_TEXT.noChanges}</p>
      ) : (
        <ul className="trainer-change-list">
          {changes.map((change, index) => (
            <li key={index}>
              <b>{change.title}</b>
              {change.before !== null && change.after !== null && (
                <span>
                  <s className="muted">{change.before}</s> → {change.after}
                </span>
              )}
              {change.reason !== '' && <span className="muted small">{change.reason}</span>}
            </li>
          ))}
        </ul>
      )}
      {ordered.length > 1 && (
        <>
          <span className="label">{TRAINER_TEXT.versionsTitle.toUpperCase()}</span>
          <div className="trainer-versions">
            {ordered.map((version) => (
              <button key={version.number} type="button" className={`trainer-version${version.number === current.number ? ' on' : ''}`} onClick={() => setSelected(version.number)}>
                {TRAINER_TEXT.versionLine(version.number, dayMonth(version.createdAt.slice(0, 10)), triggerText(version.trigger))}
                {version.number === ordered[0]?.number && <span className="accent-text"> · {TRAINER_TEXT.currentVersion}</span>}
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  )
}
