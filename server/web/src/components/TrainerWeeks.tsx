import { TRAINER_TEXT } from '../constants'
import { kmNumber } from '../format'
import { isCurrentWeek, strengthTags, weekRange, weekWorkouts, weekdayShort, workoutSummary } from '../trainerView'
import type { TrainerWeeksProps } from './components.types'

export function TrainerWeeks({ plan, today, selected, onSelect }: TrainerWeeksProps) {
  return (
    <div className="trainer-weeks">
      {plan.weeks.map((week) => {
        const workouts = weekWorkouts(plan, week)
        return (
          <details key={week.index} className="trainer-week" open={isCurrentWeek(week, today)}>
            <summary>
              <b>{TRAINER_TEXT.weekTitle(week.index, weekRange(week.start))}</b>
              <span className="muted small">{TRAINER_TEXT.weekCaption(kmNumber(week.plannedMeters / 1000))}</span>
            </summary>
            {workouts.map((workout) => {
              const summary = workoutSummary(workout)
              const tags = strengthTags(plan, workout.day)
              return (
                <button key={workout.day} type="button" className={`trainer-day kind-${workout.kind}${workout.day === selected ? ' on' : ''}${workout.day === today ? ' today' : ''}`} onClick={() => onSelect(workout.day)}>
                  <span className="trainer-day-date">
                    <small>{weekdayShort(workout.day)}</small>
                    <b>{Number(workout.day.slice(8))}</b>
                  </span>
                  <span className="trainer-day-text">
                    <b>{workout.title}</b>
                    {summary !== '' && <span className="muted small">{summary}</span>}
                    {tags.length > 0 && <span className="trainer-tag">{tags.join(' ')}</span>}
                  </span>
                  {workout.edited && workout.kind !== 'off' && <span className="trainer-edited">{TRAINER_TEXT.edited}</span>}
                </button>
              )
            })}
          </details>
        )
      })}
    </div>
  )
}
