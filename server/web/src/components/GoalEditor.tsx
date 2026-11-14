import { useState } from 'react'
import { api } from '../api'
import { ERRORS, GOAL_DISTANCES, GOALS_TEXT } from '../constants'
import { duration, kmNumber, paceClock, parseClock } from '../format'
import type { GoalInput } from '../types'
import type { GoalEditorProps, GoalFormState as FormState } from './components.types'
import { Message } from './Message'

function initial(goal: GoalEditorProps['goal']): FormState {
  return {
    kind: goal?.kind ?? 'time',
    distance: String(goal?.kind === 'time' ? goal.distanceKm : 10),
    time: goal?.targetSeconds ? duration(goal.targetSeconds) : '',
    deadline: goal?.deadline ?? '',
    longDistance: goal?.kind === 'continuousLong' ? kmNumber(goal.distanceKm) : '',
    pace: goal?.paceSecondsPerKm ? paceClock(goal.paceSecondsPerKm) : '',
  }
}

function toInput(form: FormState, archived: boolean): GoalInput | string {
  if (form.kind === 'time') {
    const seconds = parseClock(form.time)
    if (seconds === null) return 'invalid_target_time'
    return { kind: 'time', distanceKm: Number(form.distance), targetSeconds: seconds, deadline: form.deadline === '' ? null : form.deadline, archived }
  }
  const distance = Number(form.longDistance.replace(',', '.'))
  if (!(distance > 0)) return 'invalid_distance'
  const pace = parseClock(form.pace)
  if (pace === null) return 'invalid_target_pace'
  return { kind: 'continuousLong', distanceKm: distance, paceSecondsPerKm: pace, archived }
}

export function GoalEditor({ goal, onSaved, onDeleted }: GoalEditorProps) {
  const [form, setForm] = useState<FormState>(() => initial(goal))
  const [error, setError] = useState<string | undefined>()
  const [notice, setNotice] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)
  const [confirming, setConfirming] = useState(false)

  const set = (field: keyof FormState) => (event: { target: { value: string } }) => setForm((current) => ({ ...current, [field]: event.target.value }))

  async function submit(archived: boolean) {
    const input = toInput(form, archived)
    if (typeof input === 'string') {
      setError(ERRORS[input])
      return
    }
    setBusy(true)
    const result = goal === null ? await api.createGoal(input) : await api.updateGoal(goal.id, input)
    setBusy(false)
    if (!result.ok) {
      setError(ERRORS[result.error] ?? ERRORS.unknown)
      return
    }
    setError(undefined)
    setNotice(GOALS_TEXT.saved)
    onSaved(result.value.id)
  }

  async function remove() {
    if (goal === null) return
    setBusy(true)
    const result = await api.deleteGoal(goal.id)
    setBusy(false)
    if (!result.ok) {
      setError(ERRORS[result.error] ?? ERRORS.unknown)
      return
    }
    onDeleted()
  }

  const archived = goal?.archived ?? false

  return (
    <form
      className="card race-form"
      aria-label={GOALS_TEXT.form}
      onSubmit={(event) => {
        event.preventDefault()
        void submit(archived)
      }}
    >
      <span className="label">{GOALS_TEXT.form}</span>
      {goal === null && (
        <div className="goal-kinds" role="radiogroup" aria-label={GOALS_TEXT.fields.kind}>
          {(['time', 'continuousLong'] as const).map((kind) => (
            <button key={kind} type="button" role="radio" aria-checked={form.kind === kind} className={`goal-kind${form.kind === kind ? ' on' : ''}`} onClick={() => setForm((current) => ({ ...current, kind }))}>
              <b>{GOALS_TEXT.kinds[kind]}</b>
              <span className="muted small">{GOALS_TEXT.kindHints[kind]}</span>
            </button>
          ))}
        </div>
      )}
      {form.kind === 'time' ? (
        <div className="race-form-grid">
          <label className="field">
            {GOALS_TEXT.fields.distance}
            <select id="goal-distance" value={form.distance} onChange={set('distance')}>
              {GOAL_DISTANCES.map((item) => <option key={item.value} value={String(item.value)}>{item.label}</option>)}
            </select>
          </label>
          <label className="field">{GOALS_TEXT.fields.time}<input id="goal-time" inputMode="numeric" placeholder={GOALS_TEXT.timeHint} value={form.time} onChange={set('time')} /></label>
          <label className="field">{GOALS_TEXT.fields.deadline}<input id="goal-deadline" type="date" value={form.deadline} onChange={set('deadline')} /></label>
        </div>
      ) : (
        <div className="race-form-grid">
          <label className="field">{GOALS_TEXT.fields.longDistance}<input id="goal-long-distance" inputMode="decimal" value={form.longDistance} onChange={set('longDistance')} /></label>
          <label className="field">{GOALS_TEXT.fields.pace}<input id="goal-pace" inputMode="numeric" placeholder={GOALS_TEXT.paceHint} value={form.pace} onChange={set('pace')} /></label>
        </div>
      )}
      <Message error={error} notice={notice} />
      <div className="actions">
        {goal !== null && !confirming && (
          <>
            <button type="button" className="btn btn-danger" disabled={busy} onClick={() => setConfirming(true)}>{GOALS_TEXT.remove}</button>
            <button type="button" className="btn" disabled={busy} onClick={() => void submit(!archived)}>{archived ? GOALS_TEXT.unarchive : GOALS_TEXT.archive}</button>
          </>
        )}
        {confirming && (
          <>
            <span className="muted">{GOALS_TEXT.removeQuestion}</span>
            <button type="button" className="btn" onClick={() => setConfirming(false)}>{GOALS_TEXT.cancel}</button>
            <button type="button" className="btn btn-danger" disabled={busy} onClick={() => void remove()}>{GOALS_TEXT.confirmRemove}</button>
          </>
        )}
        <button type="submit" className="btn btn-primary" disabled={busy}>{goal === null ? GOALS_TEXT.create : GOALS_TEXT.save}</button>
      </div>
    </form>
  )
}
