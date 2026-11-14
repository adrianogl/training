import { useEffect, useState } from 'react'
import { api } from '../api'
import { DETAILED_TEXT, WORKOUT_TEXT } from '../constants'
import { adviceText, detailedBars, detailedKpis, findingText } from '../detailedView'
import { dayMonth } from '../format'
import type { DetailedAnalysisView } from '../types'
import type { DetailedAnalysisProps } from './components.types'
import { SplitChart } from './SplitChart'

export function DetailedAnalysis({ activityId }: DetailedAnalysisProps) {
  const [analysis, setAnalysis] = useState<DetailedAnalysisView | null>(null)
  const [state, setState] = useState<'idle' | 'loading' | 'ready' | 'error'>('idle')

  useEffect(() => {
    setState('idle')
    setAnalysis(null)
  }, [activityId])

  async function load() {
    setState('loading')
    const result = await api.garminDetailed(activityId)
    if (!result.ok) return setState('error')
    setAnalysis(result.value.analysis)
    setState('ready')
  }

  if (state !== 'ready' || analysis === null) {
    return (
      <div className="detailed-open">
        <button type="button" className="btn" disabled={state === 'loading'} onClick={() => void load()}>
          {state === 'error' ? DETAILED_TEXT.retry : DETAILED_TEXT.open}
        </button>
        {state === 'loading' && <span className="muted">{DETAILED_TEXT.loading}</span>}
        {state === 'error' && <span className="note">{DETAILED_TEXT.error}</span>}
      </div>
    )
  }

  const { splits, similar } = analysis
  const bars = detailedBars(analysis)

  return (
    <div className="detailed">
      <div className="card">
        <span className="label">{DETAILED_TEXT.title}</span>
        <span className="muted">{DETAILED_TEXT.scope(DETAILED_TEXT.kinds[analysis.kind], similar.length)}</span>
        <div className="stats">
          {detailedKpis(analysis).map((card) => (
            <div key={card.key}>
              <span>{DETAILED_TEXT.kpis[card.key]}</span>
              <b>{card.value}</b>
              {card.average !== null && <span>{DETAILED_TEXT.similarAverage(card.average)}</span>}
            </div>
          ))}
        </div>
      </div>

      {splits.length > 1 && (
        <div className="card">
          <div className="row label">
            <span>{DETAILED_TEXT.chart}</span>
            <span className="legend">
              <span style={{ color: 'var(--accent)' }}>— {WORKOUT_TEXT.paceLegend}</span> · <span style={{ color: '#ff8a4c' }}>— {WORKOUT_TEXT.heartRateLegend}</span>
            </span>
          </div>
          <SplitChart
            label={DETAILED_TEXT.chart}
            pace={splits.map((split) => split.paceSeconds)}
            heartRate={splits.flatMap((split) => (split.heartRate === null ? [] : [split.heartRate]))}
            {...(analysis.fadeKm === null ? {} : { marker: analysis.fadeKm - 1 })}
          />
          <div className="row muted small">
            <span>km 1</span>
            {analysis.fadeKm !== null && <span className="fade-note">{DETAILED_TEXT.fadeMarker(analysis.fadeKm)}</span>}
            <span>km {splits.length}</span>
          </div>
        </div>
      )}

      {bars.length > 1 && (
        <div className="card">
          <span className="label">{DETAILED_TEXT.bars}</span>
          <div className="similar-bars">
            {bars.map((bar) => (
              <div className={`similar-row ${bar.current ? 'current' : ''}`} key={bar.key}>
                <span>{bar.current ? DETAILED_TEXT.currentRow : dayMonth(bar.day)}</span>
                <div><i style={{ width: `${bar.width}%` }} /></div>
                <b>{bar.completion === null ? '—' : `${Math.round(bar.completion)}%`}</b>
                {bar.detail !== '' && <small className="muted">{bar.detail}</small>}
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="card">
        <span className="label">{DETAILED_TEXT.patterns}</span>
        {analysis.findings.length === 0 && <p className="muted">{DETAILED_TEXT.noPatterns}</p>}
        <ul className="detailed-list">
          {analysis.findings.map((finding) => (
            <li key={finding.key}>{findingText(finding)}</li>
          ))}
        </ul>
      </div>

      {analysis.recommendations.length > 0 && (
        <div className="card">
          <span className="label">{DETAILED_TEXT.recommendations}</span>
          <ul className="detailed-list">
            {analysis.recommendations.map((recommendation) => (
              <li key={recommendation.key}>{adviceText(recommendation)}</li>
            ))}
          </ul>
        </div>
      )}

      <p className="muted small">
        {DETAILED_TEXT.sources}: {analysis.sources.map((source) => DETAILED_TEXT.source(DETAILED_TEXT.sourceNames[source.key], source.count)).join(' · ')}
      </p>
    </div>
  )
}
