import { useEffect, useState } from 'react'
import { api } from '../api'
import { Link } from '../components/Link'
import { DATA_TEXT } from '../constants'
import { duration, hoursMinutes, isRun, km, longDate, pace, readinessColor, readinessLabel, shiftDay, todayLocal, weekStart } from '../format'
import type { Activity, HealthDay } from '../types'
import type { DataPageProps } from './pages.types'

const WEEKDAYS = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']

export function TodayPage({ version, syncing }: DataPageProps) {
  const today = todayLocal()
  const [days, setDays] = useState<HealthDay[]>([])
  const [activities, setActivities] = useState<Activity[]>([])

  useEffect(() => {
    void api.garminDays(shiftDay(today, -6), today).then((result) => result.ok && setDays(result.value.days))
    void api.garminActivities(30).then((result) => result.ok && setActivities(result.value.activities))
  }, [today, version])

  const current = days.find((day) => day.day === today) ?? days.at(-1)
  const readiness = current?.readiness ?? null
  const start = weekStart(today)
  const weekDays = Array.from({ length: 7 }, (_, index) => shiftDay(start, index))
  const runs = activities.filter(isRun)
  const kmByDay = new Map<string, number>()
  for (const run of runs) {
    kmByDay.set(run.day, (kmByDay.get(run.day) ?? 0) + (run.distanceMeters ?? 0))
  }
  const weekMeters = weekDays.reduce((sum, day) => sum + (kmByDay.get(day) ?? 0), 0)
  const lastRun = runs[0]
  const score = readiness?.score ?? 0
  const circumference = 2 * Math.PI * 50

  return (
    <section className="page wide">
      <div>
        <span className="muted" style={{ fontSize: 14 }}>{longDate(today)}</span>
        <h1>Hoje</h1>
      </div>
      {syncing && days.length === 0 && <p className="note">{DATA_TEXT.firstSync}</p>}
      <div className="today-grid">
        <div className="card span-2">
          <span className="label">{DATA_TEXT.readiness}</span>
          {readiness ? (
            <div className="readiness">
              <svg width="120" height="120" viewBox="0 0 120 120" role="img" aria-label={`Prontidão ${score} de 100`}>
                <circle cx="60" cy="60" r="50" fill="none" stroke="var(--track)" strokeWidth="12" />
                <circle cx="60" cy="60" r="50" fill="none" stroke={readinessColor(score)} strokeWidth="12" strokeLinecap="round" strokeDasharray={`${(circumference * score) / 100} ${circumference}`} transform="rotate(-90 60 60)" />
                <text x="60" y="70" textAnchor="middle" fill="var(--text)" fontSize="32" fontWeight="800">{score}</text>
              </svg>
              <div className="readiness-text">
                <strong>{readinessLabel(readiness.level, score)}</strong>
                {readiness.recoveryMinutes !== null && (
                  <span>{readiness.recoveryMinutes > 0 ? DATA_TEXT.recovery(Math.round(readiness.recoveryMinutes / 60)) : DATA_TEXT.recovered}</span>
                )}
                <span className="muted">{DATA_TEXT.readinessSource}</span>
              </div>
              <div className="factors">
                <div><span>{DATA_TEXT.hrv}</span><b>{current?.hrv?.lastNight ?? '—'} ms</b>{current?.hrv?.balancedLow != null && <small>faixa {current.hrv.balancedLow}–{current.hrv.balancedUpper}</small>}</div>
                <div><span>{DATA_TEXT.sleep}</span><b>{current?.sleep ? hoursMinutes(current.sleep.seconds) : '—'}</b>{current?.sleep?.score != null && <small>nota {current.sleep.score}</small>}</div>
                <div><span>{DATA_TEXT.battery}</span><b>{current?.bodyBattery.atWake ?? '—'}</b></div>
                <div><span>{DATA_TEXT.resting}</span><b>{current?.restingHeartRate ?? '—'} bpm</b></div>
              </div>
            </div>
          ) : (
            <p className="muted">{DATA_TEXT.noReadiness}</p>
          )}
        </div>
        <div className="card">
          <div className="row"><span className="label">{DATA_TEXT.week}</span><span><b>{km(weekMeters)}</b></span></div>
          <div className="week">
            {weekDays.map((day, index) => {
              const meters = kmByDay.get(day) ?? 0
              return (
                <div key={day} className={day === today ? 'today' : ''}>
                  <span>{WEEKDAYS[index]}</span>
                  <i className={meters > 0 ? 'done' : ''}>{meters > 0 ? Math.round(meters / 1000) : ''}</i>
                </div>
              )
            })}
          </div>
        </div>
        <div className="card">
          <div className="row"><span className="label">{DATA_TEXT.lastRun}</span>{lastRun && <Link to="workouts">{DATA_TEXT.open}</Link>}</div>
          {lastRun ? (
            <>
              <strong style={{ fontSize: 18 }}>{lastRun.name}</strong>
              <span className="muted">{longDate(lastRun.day)}</span>
              <span>{km(lastRun.distanceMeters)} · {pace(lastRun.averageSpeed)} · {duration(lastRun.movingSeconds ?? lastRun.durationSeconds)}{lastRun.averageHeartRate !== null ? ` · FC ${Math.round(lastRun.averageHeartRate)}` : ''}</span>
            </>
          ) : (
            <p className="muted">{DATA_TEXT.noRuns}</p>
          )}
        </div>
      </div>
    </section>
  )
}
