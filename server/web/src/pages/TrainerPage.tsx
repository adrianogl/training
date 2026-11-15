import { useEffect, useMemo, useState } from 'react'
import { api } from '../api'
import { TrainerChanges } from '../components/TrainerChanges'
import { TrainerDay } from '../components/TrainerDay'
import { TrainerStrip } from '../components/TrainerStrip'
import { TrainerWeeks } from '../components/TrainerWeeks'
import { TRAINER_TEXT } from '../constants'
import { todayLocal } from '../format'
import { defaultDay, goalCaption, parseTrainerPlan, weekCells } from '../trainerView'
import type { TrainerPlan } from '../types'
import type { DataPageProps } from './pages.types'

type Load = { kind: 'loading' } | { kind: 'error' } | { kind: 'empty' } | { kind: 'ready'; plan: TrainerPlan }

export function TrainerPage({ version }: DataPageProps) {
  const [load, setLoad] = useState<Load>({ kind: 'loading' })
  const [selected, setSelected] = useState<string | null>(null)
  const today = todayLocal()

  useEffect(() => {
    void api.trainer().then((result) => {
      if (!result.ok) {
        setLoad(result.status === 404 ? { kind: 'empty' } : { kind: 'error' })
        return
      }
      const plan = parseTrainerPlan(result.value)
      setLoad(plan === null ? { kind: 'error' } : { kind: 'ready', plan })
      setSelected((current) => current ?? (plan === null ? null : defaultDay(plan, todayLocal())))
    })
  }, [version])

  const plan = load.kind === 'ready' ? load.plan : null
  const cells = useMemo(() => (plan === null ? [] : weekCells(plan, today)), [plan, today])
  const workout = plan?.workouts.find((item) => item.day === selected) ?? null

  return (
    <section className="page wide trainer">
      <div className="trainer-head">
        <div className="row">
          <div className="trainer-title">
            <h1>{TRAINER_TEXT.title}</h1>
            <span className="trainer-beta">{TRAINER_TEXT.beta}</span>
          </div>
          <span className="pill trainer-readonly" title={TRAINER_TEXT.readOnly}>{TRAINER_TEXT.editInApp}</span>
        </div>
        {plan !== null && (
          <p>
            <b>{plan.target.name}</b>
            <span className="muted"> · {goalCaption(plan, today)}</span>
          </p>
        )}
      </div>
      {load.kind === 'loading' && <p className="muted">{TRAINER_TEXT.loading}</p>}
      {load.kind === 'error' && <p className="muted">{TRAINER_TEXT.error}</p>}
      {load.kind === 'empty' && <p className="muted">{TRAINER_TEXT.empty}</p>}
      {plan !== null && (
        <>
          <TrainerStrip cells={cells} />
          <div className="races">
            <aside className="race-list" aria-label={TRAINER_TEXT.planTitle}>
              <TrainerWeeks plan={plan} today={today} selected={selected} onSelect={setSelected} />
            </aside>
            <div className="race-main">
              {workout === null ? <p className="muted">{TRAINER_TEXT.noDay}</p> : <TrainerDay plan={plan} workout={workout} />}
              <TrainerChanges versions={plan.versions} />
            </div>
          </div>
        </>
      )}
    </section>
  )
}
