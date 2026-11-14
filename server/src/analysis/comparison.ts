import { ANALYSIS } from './analysisConstants.js'
import type { BlockValue, WorkoutBlock, WorkoutComparison, WorkoutOccurrence } from './analysisTypes.js'

function distinctEarlier(previous: WorkoutOccurrence[], currentId: number): WorkoutOccurrence[] {
  const seen = new Set([currentId])
  return [...previous]
    .sort((a, b) => (a.day !== b.day ? (a.day < b.day ? 1 : -1) : b.activityId - a.activityId))
    .filter((item) => {
      if (seen.has(item.activityId)) return false
      seen.add(item.activityId)
      return true
    })
}

const unique = (labels: string[]) => labels.filter((label, index) => labels.indexOf(label) === index)

function activeBlocks(occurrence: WorkoutOccurrence, labels: string[]): WorkoutBlock[] {
  return labels.flatMap((label) => {
    const block = occurrence.blocks.find((item) => item.label === label)
    return block !== undefined && block.kind === 'active' ? [block] : []
  })
}

function weightedSpeed(blocks: WorkoutBlock[]): number | null {
  const seconds = blocks.reduce((sum, block) => sum + block.seconds, 0)
  return seconds > 0 ? blocks.reduce((sum, block) => sum + block.distance, 0) / seconds : null
}

function weightedHeartRate(blocks: WorkoutBlock[]): number | null {
  const measured = blocks.filter((block) => block.avgHeartRate !== null && block.seconds > 0)
  const seconds = measured.reduce((sum, block) => sum + block.seconds, 0)
  return seconds > 0 ? measured.reduce((sum, block) => sum + (block.avgHeartRate ?? 0) * block.seconds, 0) / seconds : null
}

const difference = (current: number | null, baseline: number | null) => (current === null || baseline === null ? null : current - baseline)

export function compare(current: WorkoutOccurrence, previous: WorkoutOccurrence[]): WorkoutComparison | null {
  const earlier = distinctEarlier(previous, current.activityId).slice(0, ANALYSIS.maxComparisons)
  if (earlier.length === 0) return null
  const shown = [current, ...earlier]
  const currentLabels = current.blocks.map((block) => block.label)
  const sameStructure = earlier.every((item) => item.blocks.length === currentLabels.length && item.blocks.every((block, index) => block.label === currentLabels[index]))
  const labels = unique(currentLabels).filter((label) => earlier.every((item) => item.blocks.some((block) => block.label === label)))
  const blocks = labels.map((label) => {
    const values: Record<string, BlockValue> = {}
    for (const occurrence of shown) {
      const block = occurrence.blocks.find((item) => item.label === label)
      if (block !== undefined) values[String(occurrence.activityId)] = { speed: block.avgSpeed, heartRate: block.avgHeartRate, status: block.status }
    }
    return { label, values }
  })
  const oldest = shown[shown.length - 1] ?? current
  const currentActive = activeBlocks(current, labels)
  const oldestActive = activeBlocks(oldest, labels)
  return {
    occurrences: shown.map((item) => item.activityId),
    blocks,
    sameStructure,
    activeSpeedDelta: difference(weightedSpeed(currentActive), weightedSpeed(oldestActive)),
    activeHeartRateDelta: difference(weightedHeartRate(currentActive), weightedHeartRate(oldestActive)),
  }
}
