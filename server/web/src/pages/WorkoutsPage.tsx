import { useEffect, useState } from 'react'
import { api } from '../api'
import { DATA_TEXT } from '../constants'
import { duration, km, longDate, pace, shortDate } from '../format'
import type { Activity } from '../types'
import type { DataPageProps } from './pages.types'

const PAGE = 40
const ZONE_COLORS = ['#7fb2ff', '#c8f05a', '#e8c547', '#ff8a4c', '#e5534b']

export function WorkoutsPage({ version }: DataPageProps) {
  const [activities, setActivities] = useState<Activity[]>([])
  const [selected, setSelected] = useState<number | null>(null)
  const [more, setMore] = useState(true)

  useEffect(() => {
    void api.garminActivities(PAGE).then((result) => {
      if (result.ok) {
        setActivities(result.value.activities)
        setMore(result.value.activities.length === PAGE)
        setSelected((current) => current ?? result.value.activities[0]?.id ?? null)
      }
    })
  }, [version])

  async function loadMore() {
    const last = activities.at(-1)
    if (last === undefined) {
      return
    }
    const result = await api.garminActivities(PAGE, last.day)
    if (result.ok) {
      setActivities((current) => [...current, ...result.value.activities.filter((item) => !current.some((existing) => existing.id === item.id))])
      setMore(result.value.activities.length === PAGE)
    }
  }

  const activity = activities.find((item) => item.id === selected)
  const zoneTotal = activity ? activity.zoneSeconds.reduce((sum, value) => sum + value, 0) : 0
  return (
    <section className="page wide">
      <h1>{DATA_TEXT.workoutsTitle}</h1>
      <div className="workouts">
        <div className="workout-list">
          {activities.length === 0 && <p className="muted">{DATA_TEXT.noActivities}</p>}
          {activities.map((item) => (
            <button key={item.id} type="button" className={`workout-row${item.id === selected ? ' on' : ''}`} onClick={() => setSelected(item.id)}>
              <span className="muted">{shortDate(item.day)}</span>
              <strong>{item.name}</strong>
              <span className="muted">{km(item.distanceMeters)} · {pace(item.averageSpeed)}{item.averageHeartRate !== null ? ` · FC ${Math.round(item.averageHeartRate)}` : ''}</span>
            </button>
          ))}
          {more && activities.length > 0 && <button type="button" className="btn" onClick={loadMore}>{DATA_TEXT.loadMore}</button>}
        </div>
        <div className="workout-detail">
          {!activity && <p className="muted">{DATA_TEXT.pickOne}</p>}
          {activity && (
            <>
              <div>
                <span className="muted">{longDate(activity.day)} · {activity.startLocal.slice(11, 16)}</span>
                <h2 style={{ fontSize: 28, marginTop: 4 }}>{activity.name}</h2>
              </div>
              <div className="stats">
                <div><span>{DATA_TEXT.distance}</span><b>{km(activity.distanceMeters)}</b></div>
                <div><span>{DATA_TEXT.time}</span><b>{duration(activity.movingSeconds ?? activity.durationSeconds)}</b></div>
                <div><span>{DATA_TEXT.pace}</span><b>{pace(activity.averageSpeed)}</b></div>
                <div><span>{DATA_TEXT.heartRate}</span><b>{activity.averageHeartRate === null ? '—' : `${Math.round(activity.averageHeartRate)} bpm`}</b></div>
                <div><span>{DATA_TEXT.maxHeartRate}</span><b>{activity.maxHeartRate === null ? '—' : `${Math.round(activity.maxHeartRate)} bpm`}</b></div>
                <div><span>{DATA_TEXT.elevation}</span><b>{activity.elevationGain === null ? '—' : `${Math.round(activity.elevationGain)} m`}</b></div>
                <div><span>{DATA_TEXT.load}</span><b>{activity.trainingLoad === null ? '—' : Math.round(activity.trainingLoad)}</b></div>
                <div><span>{DATA_TEXT.effect}</span><b>{activity.aerobicEffect === null ? '—' : activity.aerobicEffect.toFixed(1).replace('.', ',')}</b></div>
                <div><span>{DATA_TEXT.fastestKm}</span><b>{activity.fastestKmSeconds === null ? '—' : `${duration(activity.fastestKmSeconds)}/km`}</b></div>
                <div><span>{DATA_TEXT.vo2}</span><b>{activity.vo2max ?? '—'}</b></div>
              </div>
              {zoneTotal > 0 && (
                <div className="card">
                  <span className="label">{DATA_TEXT.zones}</span>
                  {activity.zoneSeconds.map((seconds, index) => (
                    <div className="zone" key={index}>
                      <span>Z{index + 1}</span>
                      <div><i style={{ width: `${(seconds / zoneTotal) * 100}%`, background: ZONE_COLORS[index] }} /></div>
                      <span>{Math.round(seconds / 60)} min</span>
                    </div>
                  ))}
                </div>
              )}
              <p className="note">{DATA_TEXT.analysisSoon}</p>
            </>
          )}
        </div>
      </div>
    </section>
  )
}
