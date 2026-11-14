import { useEffect, useState } from 'react'
import { api } from '../api'
import { Link } from '../components/Link'
import { DATA_TEXT, FACTOR_NAMES, TODAY_TEXT, VERDICTS } from '../constants'
import { duration, hoursMinutes, isRun, km, longDate, pace, readinessColor, shiftDay, todayLocal, weekStart } from '../format'
import type { Activity, TodaySummary } from '../types'
import type { DataPageProps } from './pages.types'

const WEEKDAYS = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D']

function factorValue(summary: TodaySummary, component: keyof typeof FACTOR_NAMES): string {
  const raw = summary.raw
  switch (component) {
    case 'hrv':
      return raw.hrvLastNight === null ? TODAY_TEXT.missing : `${raw.hrvLastNight} ms${raw.hrvBalancedLow !== null ? ` · faixa ${raw.hrvBalancedLow}–${raw.hrvBalancedUpper}` : ''}`
    case 'sleep':
      return raw.sleepScore === null ? TODAY_TEXT.missing : `nota ${raw.sleepScore}${raw.sleepSeconds !== null ? ` · ${hoursMinutes(raw.sleepSeconds)}` : ''}`
    case 'bodyBattery':
      return raw.bodyBatteryMorningMax === null ? TODAY_TEXT.missing : `${raw.bodyBatteryMorningMax} de manhã`
    case 'load':
      return raw.acuteChronic === null ? TODAY_TEXT.missing : `${TODAY_TEXT.load} ${raw.acuteChronic.toFixed(2).replace('.', ',')}`
  }
}

export function TodayPage({ version, syncing }: DataPageProps) {
  const today = todayLocal()
  const [summary, setSummary] = useState<TodaySummary | null>(null)
  const [activities, setActivities] = useState<Activity[]>([])

  useEffect(() => {
    void api.garminToday().then((result) => result.ok && setSummary(result.value))
    void api.garminActivities(10).then((result) => result.ok && setActivities(result.value.activities))
  }, [version])

  const readiness = summary?.readiness ?? null
  const score = readiness?.score ?? 0
  const circumference = 2 * Math.PI * 50
  const scale = Math.max(4, ...(readiness?.factors.map((factor) => Math.abs(factor.points ?? 0)) ?? [4]))
  const start = weekStart(today)
  const weekDays = Array.from({ length: 7 }, (_, index) => shiftDay(start, index))
  const lastRun = activities.find(isRun)

  return (
    <section className="page wide">
      <div>
        <span className="muted" style={{ fontSize: 14 }}>{longDate(today)}</span>
        <h1>Hoje</h1>
      </div>
      {syncing && summary === null && <p className="note">{DATA_TEXT.firstSync}</p>}
      <div className="today-grid">
        <div className="card span-2">
          <span className="label">{DATA_TEXT.readiness}</span>
          {readiness && summary ? (
            <div className="readiness">
              <svg width="120" height="120" viewBox="0 0 120 120" role="img" aria-label={`Prontidão ${score} de 100`}>
                <circle cx="60" cy="60" r="50" fill="none" stroke="var(--track)" strokeWidth="12" />
                <circle cx="60" cy="60" r="50" fill="none" stroke={readinessColor(score)} strokeWidth="12" strokeLinecap="round" strokeDasharray={`${(circumference * score) / 100} ${circumference}`} transform="rotate(-90 60 60)" />
                <text x="60" y="70" textAnchor="middle" fill="var(--text)" fontSize="32" fontWeight="800">{score}</text>
              </svg>
              <div className="readiness-text">
                <strong>{VERDICTS[readiness.verdict]}</strong>
                {summary.recoveryMinutes !== null && (
                  <span>{summary.recoveryMinutes > 0 ? DATA_TEXT.recovery(Math.round(summary.recoveryMinutes / 60)) : DATA_TEXT.recovered}</span>
                )}
                <span className="muted">
                  {readiness.normal === null ? TODAY_TEXT.noHistory : TODAY_TEXT.normal(Math.round(readiness.normal))}
                  {summary.garminReadiness !== null && ` · ${TODAY_TEXT.garmin(summary.garminReadiness)}`}
                </span>
              </div>
              <div className="drivers">
                {readiness.factors.map((factor) => {
                  const points = factor.points ?? 0
                  const width = (Math.min(Math.abs(points), scale) / scale) * 50
                  return (
                    <div className="driver" key={factor.component}>
                      <div>
                        <b>{FACTOR_NAMES[factor.component]}</b>
                        <span className="muted">{factorValue(summary, factor.component)}</span>
                      </div>
                      <div className="driver-bar" aria-hidden="true">
                        <i style={{ left: points >= 0 ? '50%' : `${50 - width}%`, width: `${width}%`, background: points >= 0 ? 'var(--accent)' : 'var(--rest)' }} />
                      </div>
                      <span className="driver-points">{factor.points === null ? '—' : `${points >= 0 ? '+' : '−'}${Math.abs(points).toFixed(1).replace('.', ',')}`}</span>
                    </div>
                  )
                })}
              </div>
            </div>
          ) : (
            <p className="muted">{DATA_TEXT.noReadiness}</p>
          )}
        </div>
        <div className="card">
          <div className="row"><span className="label">{DATA_TEXT.week}</span><b>{km((summary?.week.total ?? 0) * 1000)}</b></div>
          <div className="week">
            {weekDays.map((day, index) => {
              const value = summary?.week.perDay[day] ?? 0
              return (
                <div key={day} className={day === today ? 'today' : ''}>
                  <span>{WEEKDAYS[index]}</span>
                  <i className={value > 0 ? 'done' : ''}>{value > 0 ? Math.round(value) : ''}</i>
                </div>
              )
            })}
          </div>
          {summary && (
            <span className="muted">
              {TODAY_TEXT.lastWeek(km(summary.week.lastWeek * 1000))} · {TODAY_TEXT.average(km(summary.week.average4Weeks * 1000))}
            </span>
          )}
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
        {summary?.focus && (
          <div className="card">
            <span className="label">{TODAY_TEXT.focus}</span>
            <div className="focus-bar" aria-hidden="true">
              <i style={{ width: `${summary.focus.lowAerobic * 100}%`, background: '#7fb2ff' }} />
              <i style={{ width: `${summary.focus.highAerobic * 100}%`, background: '#ff8a4c' }} />
              <i style={{ width: `${summary.focus.anaerobic * 100}%`, background: '#e5534b' }} />
            </div>
            <div className="route-counts">
              {(Object.keys(TODAY_TEXT.focusParts) as (keyof typeof TODAY_TEXT.focusParts)[]).map((key) => (
                <span key={key}>{TODAY_TEXT.focusParts[key]}: <b>{Math.round((summary.focus?.[key] ?? 0) * 100)}%</b></span>
              ))}
            </div>
            {summary.fitness && (
              <span className="muted">
                {TODAY_TEXT.fitness} {Math.round(summary.fitness.fitness)} · {TODAY_TEXT.fatigue} {Math.round(summary.fitness.fatigue)} · {TODAY_TEXT.form} {Math.round(summary.fitness.form)}
              </span>
            )}
          </div>
        )}
      </div>
    </section>
  )
}
