import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { RaceDetail } from '../components/RaceDetail'
import { RaceEditor } from '../components/RaceEditor'
import { RACES_TEXT } from '../constants'
import { dayMonth, duration } from '../format'
import type { RaceView } from '../types'
import type { DataPageProps } from './pages.types'

export function RacesPage({ version }: DataPageProps) {
  const [races, setRaces] = useState<RaceView[] | null>(null)
  const [failed, setFailed] = useState(false)
  const [selected, setSelected] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)

  const load = useCallback(async (select?: string | null) => {
    const result = await api.races()
    setFailed(!result.ok)
    if (!result.ok) return
    setRaces(result.value.races)
    const ids = result.value.races.filter((race) => !race.locked).map((race) => race.id)
    setSelected((current) => (select !== undefined ? select : current !== null && ids.includes(current) ? current : (ids[0] ?? null)))
  }, [])

  useEffect(() => {
    void load()
  }, [load, version])

  const groups = [
    { key: 'upcoming', title: RACES_TEXT.upcoming, items: races?.filter((race) => race.status === 'upcoming') ?? [] },
    { key: 'done', title: RACES_TEXT.done, items: races?.filter((race) => race.status === 'done') ?? [] },
  ]
  const locked = races?.filter((race) => race.locked) ?? []
  const current = creating ? null : (races?.find((race) => race.id === selected) ?? null)

  return (
    <section className="page wide races">
      <aside className="race-list" aria-label={RACES_TEXT.title}>
        <div className="row">
          <h1>{RACES_TEXT.title}</h1>
          <button type="button" className="btn btn-small" onClick={() => setCreating(true)}>{RACES_TEXT.newRace}</button>
        </div>
        {races === null && <p className="muted">{failed ? RACES_TEXT.error : RACES_TEXT.loading}</p>}
        {races !== null && races.length === 0 && <p className="muted">{RACES_TEXT.empty}</p>}
        {groups.map((group) =>
          group.items.length === 0 ? null : (
            <div key={group.key} className="race-group">
              <span className="label">{group.title}</span>
              {group.items.map((race) => (
                <button
                  key={race.id}
                  type="button"
                  className={`race-item${!creating && race.id === selected ? ' on' : ''}`}
                  onClick={() => {
                    setCreating(false)
                    setSelected(race.id)
                  }}
                >
                  <span className="row">
                    <span className="muted">{race.day ? dayMonth(race.day) : ''}{race.daysUntil !== null ? ` · ${RACES_TEXT.inDays(race.daysUntil)}` : ''}</span>
                    <span className="pill">{race.priority}</span>
                  </span>
                  <b>{race.name}</b>
                  <span className="muted">
                    {race.result ? duration(race.result.seconds) : race.outlook ? race.outlook.label : ''}
                    {' · '}
                    {race.goalSeconds !== null ? RACES_TEXT.goalShort(duration(race.goalSeconds)) : RACES_TEXT.noGoal}
                    {race.result && race.goalSeconds !== null && race.result.seconds <= race.goalSeconds ? ` · ${RACES_TEXT.beaten}` : ''}
                  </span>
                </button>
              ))}
            </div>
          ),
        )}
        {locked.length > 0 && (
          <div className="race-group">
            <span className="label">{RACES_TEXT.locked}</span>
            <p className="muted small">{RACES_TEXT.lockedNote}</p>
          </div>
        )}
      </aside>
      <div className="race-main">
        {creating ? (
          <RaceEditor
            key="new"
            race={null}
            onSaved={(id) => {
              setCreating(false)
              void load(id)
            }}
            onDeleted={() => setCreating(false)}
          />
        ) : current !== null ? (
          <RaceDetail race={current} onSaved={(id) => void load(id)} onDeleted={() => void load()} />
        ) : null}
      </div>
    </section>
  )
}
