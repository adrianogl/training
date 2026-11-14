import { useState } from 'react'
import { RACES_TEXT } from '../constants'
import { dayMonth, dayMonthNear, duration, kmNumber, longDate, paceClock } from '../format'
import { checklistLine, stretches } from '../raceView'
import type { RaceDetailProps } from './components.types'
import { LineChart } from './LineChart'
import { RaceEditor } from './RaceEditor'

const STATUS_MARK = { ok: '✓', attention: '!', missing: '–' } as const

export function RaceDetail({ race, onSaved, onDeleted }: RaceDetailProps) {
  const [adjust, setAdjust] = useState(true)
  const outlook = race.outlook
  const strategy = race.strategy
  const heat = strategy?.heat ?? null
  const factor = heat !== null && !adjust ? 1 / (1 + heat.fraction) : 1
  const list = strategy !== null && race.distance !== null ? stretches(strategy.kms, race.distance, factor) : []
  const recent = outlook?.series.slice(-90) ?? []
  const projection = outlook?.projection.map((point): [string, number] => [point.day, point.mid]) ?? []
  const peak = Math.max(1, ...race.block.map((week) => week.km))
  const target = strategy?.target ?? null
  const crossing = outlook?.goalCrossing

  return (
    <section className="race-detail" aria-label={race.name ?? ''}>
      <header className="race-head">
        <div>
          <span className="muted">{race.day ? RACES_TEXT.raceLine(longDate(race.day), race.priority ?? '') : ''}</span>
          <h2>{race.name}</h2>
        </div>
        {race.daysUntil !== null && (
          <div className="race-countdown"><b>{race.daysUntil}</b><span>{RACES_TEXT.days}</span></div>
        )}
      </header>

      <div className="race-grid">
        <RaceEditor key={race.id} race={race} onSaved={onSaved} onDeleted={onDeleted} />

        {race.status === 'done' ? (
          <div className="card">
            <span className="label">{RACES_TEXT.done}</span>
            <strong className="race-result">{race.result ? RACES_TEXT.result(duration(race.result.seconds)) : RACES_TEXT.resultMissing}</strong>
            {race.result && race.goalSeconds !== null && (
              <span className="muted">{RACES_TEXT.goalShort(duration(race.goalSeconds))}{race.result.seconds <= race.goalSeconds ? ` · ${RACES_TEXT.beaten}` : ''}</span>
            )}
          </div>
        ) : (
          <div className="card">
            <span className="label">{RACES_TEXT.prediction}</span>
            {outlook && outlook.today !== null ? (
              <>
                <LineChart
                  label={RACES_TEXT.prediction}
                  height={150}
                  lines={[
                    { points: recent, color: 'var(--text)', width: 2.5 },
                    { points: [...(recent.slice(-1)), ...projection], color: 'var(--amber)', width: 2.5, dashed: true },
                  ]}
                  {...(outlook.goalSeconds !== null ? { guide: { value: outlook.goalSeconds, label: RACES_TEXT.goalLine(duration(outlook.goalSeconds)), color: 'var(--accent)' } } : {})}
                />
                <div className="race-numbers">
                  <div><span>{RACES_TEXT.todayLabel}</span><b>{duration(outlook.today)}</b></div>
                  <div><span>{RACES_TEXT.raceDayLabel}</span><b>{outlook.raceDay ? duration(outlook.raceDay.mid) : '—'}</b></div>
                  <div><span>{RACES_TEXT.goalLabel}</span><b>{outlook.goalSeconds !== null ? duration(outlook.goalSeconds) : '—'}</b></div>
                </div>
                <span className="muted">
                  {crossing?.kind === 'on' ? RACES_TEXT.crossing.on(dayMonthNear(crossing.day)) : crossing ? RACES_TEXT.crossing[crossing.kind] : ''}
                  {outlook.assessment ? ` ${RACES_TEXT.assessment[outlook.assessment]}` : ''}
                </span>
              </>
            ) : (
              <p className="muted">{RACES_TEXT.noPrediction}</p>
            )}
          </div>
        )}
      </div>

      {race.status === 'upcoming' && (
        <div className="race-grid three">
          <div className="card">
            <span className="label">{RACES_TEXT.strategy}</span>
            {list.length === 0 ? (
              <p className="muted">{RACES_TEXT.noStrategy}</p>
            ) : (
              <>
                <div className="table-wrap">
                  <table className="table">
                    <thead><tr>{RACES_TEXT.stretchColumns.map((column) => <th key={column}>{column}</th>)}</tr></thead>
                    <tbody>
                      {list.map((item) => (
                        <tr key={item.from}>
                          <td>{RACES_TEXT.stretch(item.from, item.to, item.label)}</td>
                          <td><b>{paceClock(item.pace)}</b></td>
                          <td className="muted">{duration(item.split)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
                <span className="muted small">
                  {target === null ? '' : target.source === 'frozen' ? RACES_TEXT.targetSource.frozen(target.frozenOn ? dayMonth(target.frozenOn) : '') : RACES_TEXT.targetSource[target.source]}
                </span>
                {heat !== null ? (
                  <>
                    <label className="check">
                      <input id="race-heat" type="checkbox" checked={adjust} onChange={(event) => setAdjust(event.target.checked)} />
                      {RACES_TEXT.heatToggle}
                    </label>
                    <span className="muted small">
                      {RACES_TEXT.heatLine(heat.weather.hour, Math.round(heat.weather.temperature), Math.round(heat.weather.dewPoint), kmNumber(heat.fraction * 100))}
                      {heat.tooHot ? ` ${RACES_TEXT.tooHot}` : ''}
                    </span>
                  </>
                ) : (
                  strategy?.weatherNote && <span className="muted small">{RACES_TEXT.weatherNote[strategy.weatherNote]}</span>
                )}
              </>
            )}
          </div>

          <div className="card">
            <span className="label">{RACES_TEXT.block}</span>
            <div className="week-bars">
              {race.block.map((week, index) => (
                <i
                  key={week.start}
                  className={index === race.block.length - 1 ? 'current' : week.projected ? 'projected' : ''}
                  style={{ height: `${(week.km / peak) * 100}%` }}
                  title={`${dayMonth(week.start)} · ${kmNumber(week.km)} km${week.projected ? ` · ${RACES_TEXT.projected}` : ''}`}
                />
              ))}
            </div>
            {race.block.length > 0 && (
              <span className="muted small">{RACES_TEXT.blockLine(`${kmNumber(peak, 0)} km`, `${kmNumber(race.block.at(-1)?.km ?? 0, 0)} km`)}</span>
            )}
          </div>

          <div className="card">
            <span className="label">{RACES_TEXT.checklist}</span>
            <ul className="checklist">
              {race.checklist.map((item) => {
                const line = checklistLine(item)
                return (
                  <li key={item.kind} className={item.status}>
                    <i aria-hidden="true">{STATUS_MARK[item.status]}</i>
                    <div><b>{line.title}</b><span className="muted">{line.detail}</span></div>
                  </li>
                )
              })}
            </ul>
          </div>
        </div>
      )}
    </section>
  )
}
