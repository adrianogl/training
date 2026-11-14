import { useState } from 'react'
import { api } from '../api'
import { ERRORS, RACE_PRIORITIES, RACES_TEXT } from '../constants'
import { duration, parseClock, todayLocal } from '../format'
import { distanceText, parseDistance } from '../raceView'
import type { RaceInput } from '../types'
import type { RaceEditorProps, RaceFormState as FormState } from './components.types'
import { Message } from './Message'

function initial(race: RaceEditorProps['race']): FormState {
  return {
    name: race?.name ?? '',
    day: race?.day ?? todayLocal(),
    distance: race?.distance ? distanceText(race.distance) : '',
    goal: race?.goalSeconds ? duration(race.goalSeconds) : '',
    priority: race?.priority ?? 'A',
    startTime: race?.startTime ?? '',
    city: race?.city ?? '',
  }
}

function toInput(form: FormState): RaceInput | string {
  const distance = parseDistance(form.distance)
  if (distance === null) return 'invalid_distance'
  const goal = form.goal.trim() === '' ? null : parseClock(form.goal)
  if (form.goal.trim() !== '' && goal === null) return 'invalid_goal'
  return { name: form.name.trim(), day: form.day, distance, goalSeconds: goal, priority: form.priority, startTime: form.startTime === '' ? null : form.startTime, city: form.city.trim() === '' ? null : form.city.trim() }
}

export function RaceEditor({ race, onSaved, onDeleted }: RaceEditorProps) {
  const [form, setForm] = useState<FormState>(() => initial(race))
  const [error, setError] = useState<string | undefined>()
  const [notice, setNotice] = useState<string | undefined>()
  const [busy, setBusy] = useState(false)
  const [confirming, setConfirming] = useState(false)

  const set = (field: keyof FormState) => (event: { target: { value: string } }) => setForm((current) => ({ ...current, [field]: event.target.value }))

  async function save(event: { preventDefault: () => void }) {
    event.preventDefault()
    const input = toInput(form)
    if (typeof input === 'string') {
      setError(ERRORS[input])
      return
    }
    setBusy(true)
    const result = race === null ? await api.createRace(input) : await api.updateRace(race.id, input)
    setBusy(false)
    if (!result.ok) {
      setError(ERRORS[result.error] ?? ERRORS.unknown)
      return
    }
    setError(undefined)
    setNotice(RACES_TEXT.saved)
    onSaved(result.value.id)
  }

  async function remove() {
    if (race === null) return
    setBusy(true)
    const result = await api.deleteRace(race.id)
    setBusy(false)
    if (!result.ok) {
      setError(ERRORS[result.error] ?? ERRORS.unknown)
      return
    }
    onDeleted()
  }

  return (
    <form className="card race-form" aria-label={RACES_TEXT.form} onSubmit={(event) => void save(event)}>
      <span className="label">{RACES_TEXT.form}</span>
      <label className="field">{RACES_TEXT.fields.name}<input id="race-name" value={form.name} onChange={set('name')} /></label>
      <div className="race-form-grid">
        <label className="field">{RACES_TEXT.fields.day}<input id="race-day" type="date" value={form.day} onChange={set('day')} /></label>
        <label className="field">{RACES_TEXT.fields.startTime}<input id="race-start" type="time" value={form.startTime} onChange={set('startTime')} /></label>
        <label className="field">{RACES_TEXT.fields.distance}<input id="race-distance" inputMode="decimal" value={form.distance} onChange={set('distance')} /></label>
        <label className="field">{RACES_TEXT.fields.goal}<input id="race-goal" inputMode="numeric" placeholder={RACES_TEXT.goalHint} value={form.goal} onChange={set('goal')} /></label>
        <label className="field">
          {RACES_TEXT.fields.priority}
          <select id="race-priority" value={form.priority} onChange={set('priority')}>
            {RACE_PRIORITIES.map((item) => <option key={item.value} value={item.value}>{item.label}</option>)}
          </select>
        </label>
        <label className="field">{RACES_TEXT.fields.city}<input id="race-city" value={form.city} onChange={set('city')} /></label>
      </div>
      <Message error={error} notice={notice} />
      <div className="actions">
        {race !== null && !confirming && <button type="button" className="btn btn-danger" disabled={busy} onClick={() => setConfirming(true)}>{RACES_TEXT.remove}</button>}
        {confirming && (
          <>
            <span className="muted">{RACES_TEXT.removeQuestion}</span>
            <button type="button" className="btn" onClick={() => setConfirming(false)}>{RACES_TEXT.cancel}</button>
            <button type="button" className="btn btn-danger" disabled={busy} onClick={() => void remove()}>{RACES_TEXT.confirmRemove}</button>
          </>
        )}
        <button type="submit" className="btn btn-primary" disabled={busy}>{race === null ? RACES_TEXT.create : RACES_TEXT.save}</button>
      </div>
    </form>
  )
}
