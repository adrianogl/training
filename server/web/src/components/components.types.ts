import type { ReactNode } from 'react'
import type { Route, User } from '../types'

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
  children: ReactNode
}
