import { useEffect, useState } from 'react'
import { api } from '../api'
import { BLOCK_STATUS_TEXT, ERRORS, GARMIN_ACTIVITY_URL, SCORE_REASON_TEXT, SCORE_THRESHOLDS, WORKOUT_TEXT, ZONE_COLORS } from '../constants'
import { dayMonth, duration, km, longDate, pace, paceClock } from '../format'
import type { WorkoutAnalysisView } from '../types'
import type { WorkoutDetailProps } from './components.types'
import { DetailedAnalysis } from './DetailedAnalysis'
import { Message } from './Message'
import { SplitChart } from './SplitChart'

const scoreClass = (value: number) => (value >= SCORE_THRESHOLDS.strong ? 'strong' : value >= SCORE_THRESHOLDS.moderate ? 'moderate' : 'weak')

export function WorkoutDetail({ activity, onRenamed }: WorkoutDetailProps) {
  const [analysis, setAnalysis] = useState<WorkoutAnalysisView | null>(null)
  const [state, setState] = useState<'loading' | 'ready' | 'error' | 'missing'>('loading')
  const [editing, setEditing] = useState(false)
  const [name, setName] = useState(activity.name)
  const [error, setError] = useState<string | undefined>()

  useEffect(() => {
    let active = true
    setState('loading')
    setAnalysis(null)
    void api.garminActivity(activity.id).then((result) => {
      if (!active) return
      if (!result.ok) return setState('error')
      setAnalysis(result.value.analysis)
      setState(result.value.fitMissing ? 'missing' : 'ready')
    })
    return () => {
      active = false
    }
  }, [activity.id])

  async function rename(event: { preventDefault: () => void }) {
    event.preventDefault()
    const result = await api.renameActivity(activity.id, name)
    if (!result.ok) return setError(ERRORS[result.error] ?? ERRORS.unknown)
    setError(undefined)
    setEditing(false)
    onRenamed(activity.id, result.value.name)
  }

  const zoneSeconds = analysis?.zoneSeconds ?? (activity.zoneSeconds.length === 5 ? activity.zoneSeconds : null)
  const zoneTotal = zoneSeconds?.reduce((sum, value) => sum + value, 0) ?? 0
  const splits = analysis?.splits ?? []
  const groups = (['positive', 'negative', 'attention'] as const).map((group) => ({ group, items: analysis?.findings.filter((item) => item.group === group) ?? [] }))

  return (
    <>
      <div className="workout-head">
        <div>
          <span className="muted">{longDate(activity.day)} · {activity.startLocal.slice(11, 16)}</span>
          {editing ? (
            <form className="rename" onSubmit={(event) => void rename(event)}>
              <input id="workout-name" value={name} maxLength={100} onChange={(event) => setName(event.target.value)} aria-label={WORKOUT_TEXT.rename} />
              <button type="submit" className="btn btn-small">{WORKOUT_TEXT.save}</button>
              <button type="button" className="btn btn-small" onClick={() => { setEditing(false); setName(activity.name) }}>{WORKOUT_TEXT.cancel}</button>
            </form>
          ) : (
            <h2 className="workout-title">{activity.name}</h2>
          )}
          <Message error={error} />
        </div>
        <div className="actions">
          {analysis?.score && (
            <div className={`score ${scoreClass(analysis.score.value)}`} title={WORKOUT_TEXT.score}><b>{analysis.score.value}</b><span>nota</span></div>
          )}
          <a className="btn btn-small" href={`${GARMIN_ACTIVITY_URL}${activity.id}`} target="_blank" rel="noreferrer">{WORKOUT_TEXT.openGarmin}</a>
          {!editing && <button type="button" className="btn btn-small" onClick={() => setEditing(true)}>{WORKOUT_TEXT.rename}</button>}
        </div>
      </div>

      <div className="stats">
        <div><span>{WORKOUT_TEXT.numbers.distance}</span><b>{km(activity.distanceMeters)}</b></div>
        <div><span>{WORKOUT_TEXT.numbers.time}</span><b>{duration(activity.movingSeconds ?? activity.durationSeconds)}</b></div>
        <div><span>{WORKOUT_TEXT.numbers.pace}</span><b>{pace(activity.averageSpeed)}</b></div>
        <div><span>{WORKOUT_TEXT.numbers.heartRate}</span><b>{activity.averageHeartRate === null ? '—' : `${Math.round(activity.averageHeartRate)} bpm`}</b></div>
        <div><span>{WORKOUT_TEXT.numbers.elevation}</span><b>{activity.elevationGain === null ? '—' : `${Math.round(activity.elevationGain)} m`}</b></div>
      </div>

      {state === 'loading' && <p className="muted">{WORKOUT_TEXT.loading}</p>}
      {state === 'error' && <p className="note">{WORKOUT_TEXT.analysisError}</p>}
      {state === 'missing' && <p className="note">{WORKOUT_TEXT.fitMissing}</p>}
      {analysis && !analysis.isRun && state === 'ready' && <p className="note">{WORKOUT_TEXT.notRun}</p>}

      {analysis?.isRun && state === 'ready' && (
        <>
          <DetailedAnalysis activityId={activity.id} />

          <div className="card reading">
            <span className="label">{WORKOUT_TEXT.reading}</span>
            {analysis.findings.length === 0 && <p className="muted">{WORKOUT_TEXT.nothingToSay}</p>}
            {groups.map(({ group, items }) =>
              items.length === 0 ? null : (
                <div key={group} className={`finding-group ${group}`}>
                  <b>{WORKOUT_TEXT.groups[group]}</b>
                  {items.map((item, index) => (
                    <details key={index}>
                      <summary>{item.text}</summary>
                      {item.evidence && <span className="muted small">{item.evidence}</span>}
                      <span className="small">{item.why}</span>
                    </details>
                  ))}
                </div>
              ),
            )}
          </div>

          {splits.length > 1 && (
            <div className="card">
              <div className="row label"><span>{WORKOUT_TEXT.chart}</span><span className="legend"><span style={{ color: 'var(--accent)' }}>— {WORKOUT_TEXT.paceLegend}</span> · <span style={{ color: '#ff8a4c' }}>— {WORKOUT_TEXT.heartRateLegend}</span></span></div>
              <SplitChart
                label={WORKOUT_TEXT.chart}
                pace={splits.flatMap((split) => (split.avgSpeed !== null && split.avgSpeed > 0 ? [1000 / split.avgSpeed] : []))}
                heartRate={splits.flatMap((split) => (split.avgHeartRate === null ? [] : [split.avgHeartRate]))}
              />
              <div className="row muted small"><span>km 1</span><span>km {Math.ceil(splits.length / 2)}</span><span>km {splits.length}</span></div>
            </div>
          )}

          {analysis.hasPrescription && analysis.blocks.length > 0 && (
            <div className="card">
              <span className="label">{WORKOUT_TEXT.blocks}</span>
              <div className="table-wrap">
                <table className="table">
                  <thead><tr>{WORKOUT_TEXT.blockColumns.map((column) => <th key={column}>{column}</th>)}</tr></thead>
                  <tbody>
                    {analysis.blocks.map((block, index) => (
                      <tr key={index} className={block.kind === 'active' ? '' : 'muted'}>
                        <td>{block.label}</td>
                        <td>{block.distance > 0 ? km(block.distance) : '—'}</td>
                        <td>{block.avgSpeed ? `${paceClock(1000 / block.avgSpeed)}/km` : '—'}</td>
                        <td>{block.avgHeartRate ?? '—'}</td>
                        <td><span className={`status ${block.status}`}>{BLOCK_STATUS_TEXT[block.status]}</span></td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          <div className="workout-grid">
            {zoneSeconds && zoneTotal > 0 && (
              <div className="card">
                <span className="label">{WORKOUT_TEXT.zones}</span>
                {zoneSeconds.map((seconds, index) => (
                  <div className="zone" key={index}>
                    <span>Z{index + 1}</span>
                    <div><i style={{ width: `${(seconds / zoneTotal) * 100}%`, background: ZONE_COLORS[index] }} /></div>
                    <span>{WORKOUT_TEXT.minutes(Math.round(seconds / 60))}</span>
                  </div>
                ))}
              </div>
            )}
            {analysis.comparison && (
              <div className="card">
                <span className="label">{WORKOUT_TEXT.comparison}</span>
                <div className="table-wrap">
                  <table className="table">
                    <thead><tr>{WORKOUT_TEXT.comparisonColumns.map((column) => <th key={column}>{column}</th>)}</tr></thead>
                    <tbody>
                      {analysis.comparison.rows.map((row) => (
                        <tr key={row.activityId} className={row.isCurrent ? 'current' : ''}>
                          <td>{row.isCurrent ? WORKOUT_TEXT.currentRow : dayMonth(row.day)}</td>
                          <td>{row.secondsPerKilometer === null ? '—' : paceClock(row.secondsPerKilometer)}</td>
                          <td>{row.heartRate === null ? '—' : Math.round(row.heartRate)}</td>
                          <td>{row.inTarget === null ? '—' : `${row.inTarget.done}/${row.inTarget.total}`}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                {analysis.comparison.evolution && <span className="accent-text small">{analysis.comparison.evolution}</span>}
                {analysis.comparison.notice && <span className="muted small">{analysis.comparison.notice}</span>}
              </div>
            )}
            {analysis.score && (
              <div className="card">
                <span className="label">{WORKOUT_TEXT.score}</span>
                {analysis.score.items.map((item) => (
                  <div className="score-row" key={item.part}>
                    <span>{WORKOUT_TEXT.scoreParts[item.part]}</span>
                    <b>{item.maximum > 0 ? `${Math.round(item.points)}/${item.maximum}` : WORKOUT_TEXT.outOfScore}</b>
                    {item.reason && <span className="muted small">{SCORE_REASON_TEXT[item.reason] ?? ''}</span>}
                  </div>
                ))}
              </div>
            )}
          </div>
        </>
      )}
    </>
  )
}
