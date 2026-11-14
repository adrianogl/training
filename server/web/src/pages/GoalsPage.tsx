import { useCallback, useEffect, useState } from 'react'
import { api } from '../api'
import { GoalDetail } from '../components/GoalDetail'
import { GoalEditor } from '../components/GoalEditor'
import { GOALS_TEXT } from '../constants'
import { goalLine, goalStatus, goalTitle } from '../goalView'
import type { GoalView } from '../types'
import type { DataPageProps } from './pages.types'

export function GoalsPage({ version }: DataPageProps) {
  const [goals, setGoals] = useState<GoalView[] | null>(null)
  const [failed, setFailed] = useState(false)
  const [selected, setSelected] = useState<string | null>(null)
  const [creating, setCreating] = useState(false)

  const load = useCallback(async (select?: string | null) => {
    const result = await api.goals()
    setFailed(!result.ok)
    if (!result.ok) return
    setGoals(result.value.goals)
    const ids = result.value.goals.map((goal) => goal.id)
    setSelected((current) => (select !== undefined ? select : current !== null && ids.includes(current) ? current : (ids[0] ?? null)))
  }, [])

  useEffect(() => {
    void load()
  }, [load, version])

  const groups = [
    { key: 'active', title: GOALS_TEXT.active, items: goals?.filter((goal) => !goal.archived) ?? [] },
    { key: 'archived', title: GOALS_TEXT.archivedGroup, items: goals?.filter((goal) => goal.archived) ?? [] },
  ]
  const current = creating ? null : (goals?.find((goal) => goal.id === selected) ?? null)

  return (
    <section className="page wide races">
      <aside className="race-list" aria-label={GOALS_TEXT.title}>
        <div className="row">
          <h1>{GOALS_TEXT.title}</h1>
          <button type="button" className="btn btn-small" onClick={() => setCreating(true)}>{GOALS_TEXT.newGoal}</button>
        </div>
        {goals === null && <p className="muted">{failed ? GOALS_TEXT.error : GOALS_TEXT.loading}</p>}
        {goals !== null && goals.length === 0 && !creating && <p className="muted">{GOALS_TEXT.empty}</p>}
        {groups.map((group) =>
          group.items.length === 0 ? null : (
            <div key={group.key} className="race-group">
              <span className="label">{group.title}</span>
              {group.items.map((goal) => {
                const status = goalStatus(goal)
                return (
                  <button
                    key={goal.id}
                    type="button"
                    className={`race-item${!creating && goal.id === selected ? ' on' : ''}`}
                    onClick={() => {
                      setCreating(false)
                      setSelected(goal.id)
                    }}
                  >
                    <span className="muted">{GOALS_TEXT.kinds[goal.kind]}</span>
                    <b>{goalTitle(goal)}</b>
                    <span className="muted">{goalLine(goal)}{status === null ? '' : ` · ${status.text}`}</span>
                    <span className="muted small">{GOALS_TEXT.scopes[goal.kind]}</span>
                  </button>
                )
              })}
            </div>
          ),
        )}
      </aside>
      <div className="race-main">
        {creating ? (
          <GoalEditor
            key="new"
            goal={null}
            onSaved={(id) => {
              setCreating(false)
              void load(id)
            }}
            onDeleted={() => setCreating(false)}
          />
        ) : current !== null ? (
          <GoalDetail goal={current} onSaved={(id) => void load(id)} onDeleted={() => void load(null)} />
        ) : null}
      </div>
    </section>
  )
}
