import { randomUUID } from 'node:crypto'
import { GOALS } from './constants.js'
import type { Sql } from './db.js'
import { applyGoalEdit, deadlineError, parseGoalEdit } from './goalInput.js'
import { deleteGoal, nextGoalUpdatedAt, readGoals, writeGoal } from './goals.js'
import { body, failure, garminEnvFromProcess, json, withAccount } from './garminRoutes.js'
import { localDay } from './garminSync.js'
import { limitsFromEnv } from './limits.js'
import type { GarminEnv, GoalItem } from './types.js'

export function goalsRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'goals', async (accountId, key) => {
    const today = localDay(env.now())
    const goals = (await readGoals(sql, key, accountId)).flatMap(({ goal }) => (goal === null ? [] : [goal]))
    const active = goals.filter((goal) => !goal.archived).sort((a, b) => a.createdAt.localeCompare(b.createdAt))
    const archived = goals.filter((goal) => goal.archived).sort((a, b) => b.updatedAt.localeCompare(a.updatedAt))
    return json(200, { today, goals: [...active, ...archived] })
  })
}

export function saveGoalRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess(), maxAccountBytes = limitsFromEnv(process.env).maxAccountBytes): Promise<Response> {
  return withAccount(request, sql, env, 'goals', async (accountId, key) => {
    const requested = new URL(request.url).searchParams.get('id')
    const edit = parseGoalEdit(await body(request))
    if (typeof edit === 'string') return failure(400, edit)
    const stored = await readGoals(sql, key, accountId)
    let current: GoalItem | null = null
    let id = randomUUID().toUpperCase()
    if (requested !== null) {
      const found = stored.find((item) => item.id.toLowerCase() === requested.toLowerCase())
      if (found === undefined) return failure(404, 'goal_not_found')
      if (found.goal === null) return failure(409, 'goal_locked')
      current = found.goal
      id = found.id
    }
    const deadline = deadlineError(edit, current, localDay(env.now()))
    if (deadline !== null) return failure(400, deadline)
    const active = stored.filter((item) => item.goal !== null && !item.goal.archived && item.id !== id).length
    if (!edit.archived && active >= GOALS.maxActive) return failure(409, 'too_many_goals')
    const goal = applyGoalEdit(current, id, edit, await nextGoalUpdatedAt(sql, accountId, id, env.now()))
    if (!(await writeGoal(sql, key, accountId, goal, maxAccountBytes))) return failure(413, 'quota_exceeded')
    return json(requested === null ? 201 : 200, { id })
  })
}

export function deleteGoalRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'goals', async (accountId, key) => {
    const requested = new URL(request.url).searchParams.get('id') ?? ''
    const stored = (await readGoals(sql, key, accountId)).find((item) => item.id.toLowerCase() === requested.toLowerCase())
    if (stored === undefined) return failure(404, 'goal_not_found')
    await deleteGoal(sql, accountId, stored.id, await nextGoalUpdatedAt(sql, accountId, stored.id, env.now()))
    return new Response(null, { status: 204 })
  })
}
