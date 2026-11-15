import { RUN_KIND } from '../domain/domainConstants.js'
import type { RunShape, WorkoutStructure } from './fitTypes.js'

export function runShape(structure: WorkoutStructure): RunShape {
  const steps = structure.prescription?.steps ?? []
  const count = (intensity: string) => structure.laps.filter((lap) => lap.intensity === intensity).length
  return {
    name: structure.prescription?.name ?? null,
    hasRepeats: steps.some((step) => step.duration.kind === 'repeatSteps'),
    hasHardActiveStep: steps.some((step) => step.intensity === 'active' && step.target.kind === 'heartRateZone' && step.target.zone >= RUN_KIND.tempoZone),
    hasRepeatedActiveLaps: count('active') >= RUN_KIND.intervalActiveLaps && count('recovery') >= RUN_KIND.intervalRecoveryLaps,
  }
}
