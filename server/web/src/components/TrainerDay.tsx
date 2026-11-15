import { TRAINER_TEXT } from '../constants'
import { longDate } from '../format'
import { stepRows } from '../trainerSteps'
import { strengthTags, workoutNumbers } from '../trainerView'
import type { TrainerDayProps } from './components.types'

export function TrainerDay({ plan, workout }: TrainerDayProps) {
  const rows = stepRows(workout)
  const tags = strengthTags(plan, workout.day)
  return (
    <div className="race-detail">
      <div className="card trainer-day-head">
        <span className="label">{longDate(workout.day).toUpperCase()}</span>
        <div className="row">
          <h2>{workout.title}</h2>
          {workout.edited && workout.kind !== 'off' && <span className="trainer-edited">{TRAINER_TEXT.edited}</span>}
        </div>
        {tags.length > 0 && <span className="trainer-tag">{tags.join(' ')}</span>}
        <div className="race-numbers">
          {workoutNumbers(workout).map((item) => (
            <div key={item.label}>
              <span>{item.label}</span>
              <b>{item.value}</b>
            </div>
          ))}
        </div>
      </div>
      {rows.length > 0 && (
        <div className="card">
          <span className="label">{TRAINER_TEXT.steps.toUpperCase()}</span>
          <ul className="trainer-steps">
            {rows.map((row) => (
              <li key={row.id} className={`step-${row.kind}${row.header ? ' header' : ''}${row.nested ? ' nested' : ''}`}>
                <b>{row.title}</b>
                {row.detail !== '' && <span className="num">{row.detail}</span>}
              </li>
            ))}
          </ul>
        </div>
      )}
      {workout.rationale !== '' && (
        <div className="card">
          <span className="label">{TRAINER_TEXT.why.toUpperCase()}</span>
          <p>{workout.rationale}</p>
          {workout.method !== null && <p className="muted small">{`${TRAINER_TEXT.method}: ${TRAINER_TEXT.methods[workout.method]}`}</p>}
        </div>
      )}
    </div>
  )
}
