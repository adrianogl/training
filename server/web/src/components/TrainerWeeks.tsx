import { TRAINER_TEXT } from '../constants'
import { kmNumber } from '../format'
import { isCurrentWeek, dayLine, weekRange, weekWorkouts, weekdayShort } from '../trainerView'
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
              const line = dayLine(plan, workout)
              return (
                <button key={workout.day} type="button" className={`trainer-day kind-${workout.kind}${workout.day === selected ? ' on' : ''}${workout.day === today ? ' today' : ''}`} onClick={() => onSelect(workout.day)}>
                  <span className="trainer-day-date">
                    <small>{weekdayShort(workout.day)}</small>
                    <b>{Number(workout.day.slice(8))}</b>
                  </span>
                  <span className="trainer-day-text">
                    <b>{line.title}</b>
                    {line.detail !== '' && <span className="muted small">{line.detail}</span>}
                    {line.tags.length > 0 && (
                      <span className="trainer-tags">
                        {line.tags.map((tag) => (
                          <span key={tag.text} className={`trainer-chip${tag.strength ? ' strength' : ''}`}>{tag.text}</span>
                        ))}
                      </span>
                    )}
                  </span>
                  {workout.day === today && <span className="trainer-status">{TRAINER_TEXT.todayStatus}</span>}
                </button>
              )
            })}
          </details>
        )
      })}
    </div>
  )
}
