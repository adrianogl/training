import { useEffect, useState } from 'react'
import { api } from '../api'
import { PlannedDetail } from '../components/PlannedDetail'
import { WorkoutDetail } from '../components/WorkoutDetail'
import { DATA_TEXT, WORKOUT_TEXT, WORKOUTS_PAGE_SIZE } from '../constants'
import { km, pace, shortDate, todayLocal } from '../format'
import type { Activity, PlannedWorkout, WorkoutSelection } from '../types'
import { matches, plannedEstimate, plannedMatches } from '../workoutView'
import type { DataPageProps } from './pages.types'

export function WorkoutsPage({ version }: DataPageProps) {
  const [activities, setActivities] = useState<Activity[]>([])
  const [planned, setPlanned] = useState<PlannedWorkout[]>([])
  const [selected, setSelected] = useState<WorkoutSelection | null>(null)
  const [more, setMore] = useState(true)
  const [query, setQuery] = useState('')
  const today = todayLocal()

  useEffect(() => {
    void api.garminActivities(WORKOUTS_PAGE_SIZE).then((result) => {
      if (!result.ok) return
      setActivities(result.value.activities)
      setMore(result.value.activities.length === WORKOUTS_PAGE_SIZE)
      setSelected((current) => current ?? (result.value.activities[0] ? { kind: 'done', id: result.value.activities[0].id } : null))
    })
    void api.garminPlanned().then((result) => result.ok && setPlanned(result.value.planned))
  }, [version])

  async function loadMore() {
    const last = activities.at(-1)
    if (last === undefined) return
    const result = await api.garminActivities(WORKOUTS_PAGE_SIZE, last.day)
    if (!result.ok) return
    setActivities((current) => [...current, ...result.value.activities.filter((item) => !current.some((existing) => existing.id === item.id))])
    setMore(result.value.activities.length === WORKOUTS_PAGE_SIZE)
  }

  const visible = activities.filter((item) => matches(item, query))
  const visiblePlanned = planned.filter((item) => plannedMatches(item, query))
  const activity = selected?.kind === 'done' ? activities.find((item) => item.id === selected.id) : undefined
  const plan = selected?.kind === 'planned' ? planned.find((item) => item.id === selected.id && item.day === selected.day) : undefined

  return (
    <section className="page wide">
      <h1>{WORKOUT_TEXT.title}</h1>
      <div className="workouts">
        <div className="workout-list">
          <label className="field">
            {WORKOUT_TEXT.search}
            <input id="workout-search" type="search" placeholder={WORKOUT_TEXT.searchPlaceholder} value={query} onChange={(event) => setQuery(event.target.value)} />
          </label>
          {visiblePlanned.length > 0 && <span className="label">{WORKOUT_TEXT.planned}</span>}
          {visiblePlanned.map((item) => (
            <button key={`${item.id}-${item.day}`} type="button" className={`workout-row${plan === item ? ' on' : ''}`} onClick={() => setSelected({ kind: 'planned', id: item.id, day: item.day })}>
              <span className="row"><span className="muted">{item.day === today ? WORKOUT_TEXT.today : shortDate(item.day)}</span><span className="pill">{WORKOUT_TEXT.plannedTag}</span></span>
              <strong>{item.title}</strong>
              <span className="muted">{plannedEstimate(item)}</span>
            </button>
          ))}
          <span className="label">{WORKOUT_TEXT.done}</span>
          {visible.length === 0 && <p className="muted">{DATA_TEXT.noActivities}</p>}
          {visible.map((item) => (
            <button key={item.id} type="button" className={`workout-row${activity?.id === item.id ? ' on' : ''}`} onClick={() => setSelected({ kind: 'done', id: item.id })}>
              <span className="muted">{shortDate(item.day)}</span>
              <strong>{item.name}</strong>
              <span className="muted">{km(item.distanceMeters)} · {pace(item.averageSpeed)}{item.averageHeartRate !== null ? ` · FC ${Math.round(item.averageHeartRate)}` : ''}</span>
            </button>
          ))}
          {more && activities.length > 0 && query === '' && <button type="button" className="btn" onClick={() => void loadMore()}>{DATA_TEXT.loadMore}</button>}
        </div>
        <div className="workout-detail">
          {activity && <WorkoutDetail key={activity.id} activity={activity} onRenamed={(id, name) => setActivities((current) => current.map((item) => (item.id === id ? { ...item, name } : item)))} />}
          {plan && <PlannedDetail planned={plan} />}
          {!activity && !plan && <p className="muted">{DATA_TEXT.pickOne}</p>}
        </div>
      </div>
    </section>
  )
}
