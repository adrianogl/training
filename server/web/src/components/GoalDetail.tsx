import { GOALS_TEXT } from '../constants'
import { dayMonthNear, duration, kmNumber, paceClock } from '../format'
import { goalLine, goalStatus, goalTitle, predictionShare } from '../goalView'
import type { LongGoalProgressView, TimeGoalProgressView } from '../types'
import type { GoalDetailProps } from './components.types'
import { GoalEditor } from './GoalEditor'

function TimeProgress({ progress, target, deadline }: { progress: TimeGoalProgressView; target: number; deadline: string | null }) {
  if (progress.todaySeconds === null) return <p className="muted">{GOALS_TEXT.noPrediction}</p>
  const share = predictionShare(progress.todaySeconds, target)
  const crossing = progress.crossing
  const note =
    crossing.kind === 'on'
      ? GOALS_TEXT.crossing.on(dayMonthNear(crossing.day), deadline === null ? null : dayMonthNear(deadline), deadline !== null && crossing.day > deadline)
      : GOALS_TEXT.crossing[crossing.kind]
  return (
    <>
      <div className="goal-bar" aria-hidden="true">
        <i style={{ width: `${Math.max(4, share.prediction)}%` }} />
        <span className="goal-mark" style={{ left: `${share.target}%` }} />
      </div>
      <div className="row muted small">
        <span>{GOALS_TEXT.todayPrediction} <b className="num">{duration(progress.todaySeconds)}</b></span>
        <span>{GOALS_TEXT.goalLabel} <b className="num accent">{duration(target)}</b></span>
      </div>
      {note !== '' && <p className="muted small">{note}</p>}
    </>
  )
}

function LongProgress({ progress, goalKm }: { progress: LongGoalProgressView; goalKm: number }) {
  if (progress.runs.length === 0) return <p className="muted">{GOALS_TEXT.longEmpty}</p>
  const highest = Math.max(goalKm, ...progress.runs.map((run) => run.longestContinuousKm ?? 0))
  return (
    <>
      <span className="label">{GOALS_TEXT.longRuns}</span>
      <div className="goal-runs">
        {progress.runs.map((run) => (
          <div key={run.activityId} title={dayMonthNear(run.day)}>
            <i className={run.met === true ? 'met' : run.met === null ? 'unknown' : ''} style={{ height: run.longestContinuousKm === null ? '8%' : `${(run.longestContinuousKm / highest) * 100}%` }} />
            <small>{run.longestContinuousKm === null ? GOALS_TEXT.noFit : kmNumber(run.longestContinuousKm)}</small>
          </div>
        ))}
      </div>
      {progress.bestContinuousKm !== null && <p className="muted small">{GOALS_TEXT.best(kmNumber(progress.bestContinuousKm))}</p>}
      <ul className="goal-run-list">
        {[...progress.runs].reverse().map((run) => {
          if (run.pauses === null || run.paceSecondsPerKm === null) return <li key={run.activityId} className="muted">{GOALS_TEXT.runNoData(dayMonthNear(run.day))}</li>
          const pauses = run.pauses.length === 0 ? GOALS_TEXT.noPauses : `${GOALS_TEXT.pausesLabel(run.pauses.length)}: ${run.pauses.map((pause) => GOALS_TEXT.pauseLine(kmNumber(pause.km), Math.round(pause.seconds))).join(', ')}`
          return <li key={run.activityId} className={run.met === true ? 'accent' : ''}>{GOALS_TEXT.runLine(dayMonthNear(run.day), pauses, paceClock(run.paceSecondsPerKm))}</li>
        })}
      </ul>
    </>
  )
}

export function GoalDetail({ goal, onSaved, onDeleted }: GoalDetailProps) {
  const status = goalStatus(goal)
  return (
    <div className="race-detail">
      <div className="race-head">
        <div>
          <span className="label">{GOALS_TEXT.kinds[goal.kind].toUpperCase()}</span>
          <h2>{goalTitle(goal)}</h2>
          <span className="muted">{goalLine(goal)}</span>
        </div>
        {status !== null && <span className={`pill ${status.tone === 'ok' ? 'pill-ok' : 'pill-warn'}`}>{status.text}</span>}
      </div>
      {goal.progress !== null && (
        <section className="card goal-progress" aria-label={GOALS_TEXT.progress}>
          <span className="label">{GOALS_TEXT.progress}</span>
          {goal.progress.kind === 'time' ? <TimeProgress progress={goal.progress} target={goal.targetSeconds ?? 0} deadline={goal.deadline} /> : <LongProgress progress={goal.progress} goalKm={goal.distanceKm} />}
        </section>
      )}
      <GoalEditor key={goal.id + goal.updatedAt} goal={goal} onSaved={onSaved} onDeleted={onDeleted} />
    </div>
  )
}
