import { useEffect, useState } from 'react'
import { api } from '../api'
import { LineChart } from '../components/LineChart'
import { DATA_TEXT, DEFAULT_EVOLUTION_PERIOD, EVOLUTION_PERIODS, EVOLUTION_TEXT, LOW_ZONE_COUNT, ZONE_COLORS, ZONE_WEEKS } from '../constants'
import { evolutionReading, trend } from '../evolutionReading'
import { dayMonth, duration, km, signedDuration, signedNumber } from '../format'
import type { Evolution, MetricSeries } from '../types'
import type { DataPageProps, EvolutionTileProps, TileKey } from './pages.types'

function seriesOf(evolution: Evolution, key: string): MetricSeries | undefined {
  return evolution.series.find((item) => item.key === key)
}

function tileValue(key: TileKey, value: number): string {
  switch (key) {
    case 'predictionHalf':
      return duration(value)
    case 'monthlyVolume':
      return `${Math.round(value)} km`
    case 'hrv':
      return `${Math.round(value)} ms`
    default:
      return String(Math.round(value))
  }
}

function tileChange(key: TileKey, change: number, current: number): string {
  if (key === 'predictionHalf') {
    return signedDuration(change)
  }
  if (key === 'monthlyVolume') {
    const before = current - change
    return before > 0 ? `${signedNumber((change / before) * 100)}%` : signedNumber(change)
  }
  return signedNumber(change)
}

function Tile({ evolution, tile }: EvolutionTileProps) {
  const prediction = tile === 'predictionHalf' ? evolution.predictions.find((item) => item.key === tile) : undefined
  const stats = seriesOf(evolution, tile)?.stats
  const current = prediction ? prediction.seconds : (stats?.current ?? null)
  const change = prediction ? prediction.change : (stats?.change ?? null)
  const direction = tile === 'monthlyVolume' ? null : trend(tile, change, current)
  return (
    <div className="metric">
      <span>{EVOLUTION_TEXT.tiles[tile]}</span>
      <b>{current === null ? '—' : tileValue(tile, current)}</b>
      <small className={direction === 'better' ? 'good' : direction === 'worse' ? 'bad' : ''}>
        {current === null || change === null ? ' ' : tileChange(tile, change, current)}
      </small>
    </div>
  )
}

export function EvolutionPage({ version, syncing }: DataPageProps) {
  const [period, setPeriod] = useState<number>(DEFAULT_EVOLUTION_PERIOD)
  const [evolution, setEvolution] = useState<Evolution | null>(null)
  const [failed, setFailed] = useState(false)

  useEffect(() => {
    let active = true
    void api.garminEvolution(period).then((result) => {
      if (!active) return
      setFailed(!result.ok)
      if (result.ok) setEvolution(result.value)
    })
    return () => {
      active = false
    }
  }, [period, version])

  const span = EVOLUTION_PERIODS.find((item) => item.days === period)?.span ?? ''
  const fitness = evolution ? seriesOf(evolution, 'fitness') : undefined
  const fatigue = evolution ? seriesOf(evolution, 'fatigue') : undefined
  const weeks = evolution?.weeks ?? []
  const maxWeek = Math.max(1, ...weeks.map((week) => week.kilometers))
  const zoneWeeks = weeks.slice(-ZONE_WEEKS).filter((week) => week.zoneSeconds.some((value) => value > 0))
  const zoneTotal = zoneWeeks.reduce((sum, week) => sum + week.zoneSeconds.reduce((a, b) => a + b, 0), 0)
  const zoneEasy = zoneWeeks.reduce((sum, week) => sum + week.zoneSeconds.slice(0, LOW_ZONE_COUNT).reduce((a, b) => a + b, 0), 0)
  const fitnessNow = fitness?.stats.current ?? null
  const fatigueNow = fatigue?.stats.current ?? null
  const records = evolution?.records
  const recordFor: Record<string, { seconds: number; day: string } | null | undefined> = { prediction5k: records?.fastest5k }

  return (
    <section className="page wide evolution">
      <header className="evolution-head">
        <div>
          <h1>{EVOLUTION_TEXT.title}</h1>
          <span className="lead">
            {evolution ? evolutionReading(evolution.predictions.find((item) => item.key === 'predictionHalf'), evolution.series, span) : failed ? EVOLUTION_TEXT.error : EVOLUTION_TEXT.loading}
          </span>
        </div>
        <div role="group" aria-label={EVOLUTION_TEXT.period} className="period">
          {EVOLUTION_PERIODS.map((item) => (
            <button key={item.days} type="button" aria-pressed={item.days === period} onClick={() => setPeriod(item.days)}>
              {item.label}
            </button>
          ))}
        </div>
      </header>
      {syncing && evolution === null && <p className="note">{DATA_TEXT.firstSync}</p>}
      {evolution && (
        <>
          <div className="metrics">
            {(Object.keys(EVOLUTION_TEXT.tiles) as TileKey[]).map((tile) => (
              <Tile key={tile} evolution={evolution} tile={tile} />
            ))}
          </div>
          <div className="evolution-grid">
            <section className="card" aria-label={EVOLUTION_TEXT.form}>
              <div className="row label">
                <span>{EVOLUTION_TEXT.form}</span>
                <span className="legend">
                  <span style={{ color: 'var(--accent)' }}>— {EVOLUTION_TEXT.fitnessLegend}</span> · <span style={{ color: '#ff8a4c' }}>— {EVOLUTION_TEXT.fatigueLegend}</span>
                </span>
              </div>
              {fitness && fatigue && fitness.points.length > 1 ? (
                <>
                  <LineChart
                    label={EVOLUTION_TEXT.form}
                    marker={EVOLUTION_TEXT.today}
                    lines={[
                      { points: fitness.movingAverage, color: 'var(--accent)', width: 3 },
                      { points: fatigue.movingAverage, color: '#ff8a4c' },
                    ]}
                  />
                  {fitnessNow !== null && fatigueNow !== null && (
                    <span className="muted">
                      {EVOLUTION_TEXT.formToday(Math.round(fitnessNow), Math.round(fatigueNow), Math.round(fitnessNow - fatigueNow))} {EVOLUTION_TEXT.formReading(fitnessNow - fatigueNow)}
                    </span>
                  )}
                </>
              ) : (
                <p className="muted">{EVOLUTION_TEXT.noData}</p>
              )}
            </section>

            <section className="card" aria-label={EVOLUTION_TEXT.weekly}>
              <span className="label">{EVOLUTION_TEXT.weekly}</span>
              <div className="week-bars">
                {weeks.map((week, index) => (
                  <i
                    key={week.start}
                    className={index === weeks.length - 1 ? 'current' : ''}
                    style={{ height: `${(week.kilometers / maxWeek) * 100}%` }}
                    title={`${dayMonth(week.start)} · ${km(week.kilometers * 1000)}`}
                  />
                ))}
              </div>
              <div className="row muted small">
                <span>{weeks[0] ? dayMonth(weeks[0].start) : ''}</span>
                <span>{EVOLUTION_TEXT.thisWeek} · {km((weeks.at(-1)?.kilometers ?? 0) * 1000)}</span>
              </div>
            </section>

            <section className="card" aria-label={EVOLUTION_TEXT.zones(zoneWeeks.length)}>
              <span className="label">{EVOLUTION_TEXT.zones(zoneWeeks.length)}</span>
              {zoneWeeks.length === 0 ? (
                <p className="muted">{EVOLUTION_TEXT.noData}</p>
              ) : (
                <>
                  <div className="zone-weeks">
                    {zoneWeeks.map((week) => (
                      <div key={week.start} title={dayMonth(week.start)}>
                        {week.zoneSeconds.map((value, index) => (
                          <i key={index} style={{ flex: value, background: ZONE_COLORS[index] }} />
                        ))}
                      </div>
                    ))}
                  </div>
                  <div className="route-counts">
                    {ZONE_COLORS.map((color, index) => (
                      <span key={color}><span style={{ color }}>■</span> Z{index + 1}</span>
                    ))}
                    {zoneTotal > 0 && <span>· {EVOLUTION_TEXT.zoneSplit(Math.round((zoneEasy / zoneTotal) * 100))}</span>}
                  </div>
                </>
              )}
            </section>

            <section className="card" aria-label={EVOLUTION_TEXT.records}>
              <span className="label">{EVOLUTION_TEXT.records}</span>
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>{EVOLUTION_TEXT.recordsColumns.map((column) => <th key={column}>{column}</th>)}</tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td>1 km</td>
                      <td><b>{records?.fastestKm ? duration(records.fastestKm.seconds) : '—'}</b></td>
                      <td className="muted">{records?.fastestKm ? dayMonth(records.fastestKm.day) : ''}</td>
                      <td className="muted">—</td>
                    </tr>
                    {evolution.predictions.map((prediction) => {
                      const record = recordFor[prediction.key]
                      const direction = trend(prediction.key, prediction.change, prediction.seconds)
                      return (
                        <tr key={prediction.key}>
                          <td>{prediction.label}</td>
                          <td>{record ? <b>{duration(record.seconds)}</b> : <span className="muted">—</span>}</td>
                          <td className="muted">{record ? dayMonth(record.day) : ''}</td>
                          <td className={direction === 'better' ? 'accent' : ''}>{prediction.seconds === null ? '—' : duration(prediction.seconds)}</td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
              <div className="route-counts">
                {records?.longestRun && <span>{EVOLUTION_TEXT.longestRun}: <b>{km(records.longestRun.meters)}</b> · {dayMonth(records.longestRun.day)}</span>}
                {records?.biggestWeek && <span>{EVOLUTION_TEXT.biggestWeek}: <b>{km(records.biggestWeek.kilometers * 1000)}</b> · {EVOLUTION_TEXT.weekOf(dayMonth(records.biggestWeek.start))}</span>}
              </div>
            </section>
          </div>
        </>
      )}
    </section>
  )
}
