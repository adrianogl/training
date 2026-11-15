import type { WorkPace, WorkoutStructure } from '../fit/fitTypes.js'
import { WORK_PACE } from './analysisConstants.js'
import type { WorkoutBlock } from './analysisTypes.js'
import { buildBlocks, hasPrescription } from './blocks.js'

export function workPaceOfBlocks(blocks: WorkoutBlock[]): WorkPace | null {
  const laps = blocks
    .filter((block) => block.kind === 'active')
    .flatMap((block) => block.laps)
    .filter(
      (lap) =>
        lap.distance >= WORK_PACE.minimumLapMeters &&
        lap.timerSeconds > 0 &&
        (lap.timerSeconds / lap.distance) * WORK_PACE.metersPerKilometer <= WORK_PACE.maximumLapPace &&
        (lap.intensity === null || lap.intensity === 'active'),
    )
  const meters = laps.reduce((sum, lap) => sum + lap.distance, 0)
  return meters > 0 ? { seconds: laps.reduce((sum, lap) => sum + lap.timerSeconds, 0), meters } : null
}

export function workPace(structure: WorkoutStructure): WorkPace | null {
  return hasPrescription(structure) ? workPaceOfBlocks(buildBlocks(structure, null)) : null
}

export const paceOfWork = (work: WorkPace): number => (work.seconds / work.meters) * WORK_PACE.metersPerKilometer
