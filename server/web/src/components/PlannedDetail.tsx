import { WORKOUT_TEXT } from '../constants'
import { longDate } from '../format'
import { plannedEstimate, stepLine } from '../workoutView'
import type { PlannedDetailProps, PlannedStepListProps } from './components.types'

function StepList({ steps }: PlannedStepListProps) {
  return (
    <ul className="planned-steps">
      {steps.map((step, index) =>
        step.children.length > 0 ? (
          <li key={index}>
            <b>{WORKOUT_TEXT.repeat(step.repeats)}</b>
            <StepList steps={step.children} />
          </li>
        ) : (
          <li key={index}>{stepLine(step)}</li>
        ),
      )}
    </ul>
  )
}

export function PlannedDetail({ planned }: PlannedDetailProps) {
  return (
    <>
      <div>
        <span className="muted">{longDate(planned.day)} · {WORKOUT_TEXT.plannedTag}</span>
        <h2 className="workout-title">{planned.title}</h2>
        <span className="muted">{plannedEstimate(planned)}</span>
      </div>
      <div className="card">
        <span className="label">{WORKOUT_TEXT.plannedSteps}</span>
        <StepList steps={planned.steps} />
      </div>
    </>
  )
}
