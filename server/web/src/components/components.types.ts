import type { ReactNode } from 'react'
import type { Activity, PlannedStep, PlannedWorkout, RaceView, Route, SyncState, User } from '../types'

export interface FieldProps {
  label: string
  type?: 'text' | 'email' | 'password'
  value: string
  onChange: (value: string) => void
  autoComplete: string
}

export interface MessageProps {
  error?: string | undefined
  notice?: string | undefined
}

export interface LinkProps {
  to: Route
  className?: string
  current?: boolean
  children: ReactNode
}

export interface AuthLayoutProps {
  children: ReactNode
}

export interface AppLayoutProps {
  route: Route
  user: User | null
  sync: SyncState
  children: ReactNode
}

export interface GarminModalProps {
  onClose: (connected: boolean) => void
}

export interface ChartLine {
  points: [string, number][]
  color: string
  width?: number
  dashed?: boolean
}

export interface ChartGuide {
  value: number
  label: string
  color: string
}

export interface LineChartProps {
  lines: ChartLine[]
  label: string
  height?: number
  marker?: string
  guide?: ChartGuide
}

export interface RaceEditorProps {
  race: RaceView | null
  onSaved: (id: string) => void
  onDeleted: () => void
}

export interface RaceDetailProps {
  race: RaceView
  onSaved: (id: string) => void
  onDeleted: () => void
}

export interface RaceFormState {
  name: string
  day: string
  distance: string
  goal: string
  priority: string
  startTime: string
  city: string
}

export interface SplitChartProps {
  pace: number[]
  heartRate: number[]
  label: string
}

export interface WorkoutDetailProps {
  activity: Activity
  onRenamed: (id: number, name: string) => void
}

export interface PlannedDetailProps {
  planned: PlannedWorkout
}

export interface PlannedStepListProps {
  steps: PlannedStep[]
}
