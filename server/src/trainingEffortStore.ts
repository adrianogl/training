import type { Sql } from './db.js'
import { TRAINING_EFFORT } from './domain/domainConstants.js'
import type { Effort } from './domain/domainTypes.js'
import { trainingEfforts } from './domain/trainingEffort.js'
import { isRun } from './domain/today.js'
import { readRunMetrics } from './fit/fitStore.js'
import { addDays } from './garminSync.js'
import type { ActivitySummary, StoredRace } from './types.js'

export async function readTrainingEfforts(sql: Sql, key: Buffer, accountId: string, activities: ActivitySummary[], races: StoredRace[], today: string): Promise<Effort[]> {
  const from = addDays(today, -TRAINING_EFFORT.windowDays)
  const ids = activities.filter((activity) => isRun(activity) && activity.day >= from).map((activity) => activity.id)
  const metrics = await readRunMetrics(sql, key, accountId, ids)
  const raceGoalKms = races.flatMap(({ race }) => (race === null ? [] : [race.distance / TRAINING_EFFORT.metersPerKilometer]))
  return trainingEfforts(activities, metrics, raceGoalKms, today)
}
