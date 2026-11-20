export interface FeedbackEntry {
  id: string
  exercise?: Record<string, { _0?: string }>
  exerciseName: string
  mediaId: string
  verdict: string
  chosenMediaId?: string | null
  noneMatched: boolean
  note?: string | null
  createdAt: number
  updatedAt: number
  workoutDay?: string | null
  status: string
  resolution?: string | null
  resolvedIn?: string | null
  undoes?: string | null
}

export interface PendingFeedback {
  account: string
  entry: FeedbackEntry
}
