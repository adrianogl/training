import type { ReactNode } from 'react'
import type { Route, SyncState, User } from '../types'

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
}

export interface LineChartProps {
  lines: ChartLine[]
  label: string
  height?: number
  marker?: string
}
