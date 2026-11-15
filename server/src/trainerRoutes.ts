import type { Sql } from './db.js'
import { failure, garminEnvFromProcess, json, withAccount } from './garminRoutes.js'
import { readTrainerPlan } from './trainer.js'
import type { GarminEnv } from './types.js'

export function trainerRoute(request: Request, sql: Sql, env: GarminEnv = garminEnvFromProcess()): Promise<Response> {
  return withAccount(request, sql, env, 'trainer', async (accountId, key) => {
    const plan = await readTrainerPlan(sql, key, accountId)
    return plan === null ? failure(404, 'trainer_plan_not_found') : json(200, plan)
  })
}
