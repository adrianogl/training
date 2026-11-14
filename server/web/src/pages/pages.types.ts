import type { EVOLUTION_TEXT } from '../constants'
import type { AuthResult, Evolution, User } from '../types'

export interface SignInProps {
  onSignedIn: (result: AuthResult, persistent: boolean) => void
}

export interface SettingsProps {
  user: User
  onUserChange: (user: User) => void
  onSignedOut: () => void
}

export interface ComingSoonProps {
  title: string
}

export interface ConfirmProps {
  signedIn: boolean
}

export interface DataPageProps {
  version: number
  syncing: boolean
}

export type TileKey = keyof typeof EVOLUTION_TEXT.tiles

export interface EvolutionTileProps {
  evolution: Evolution
  tile: TileKey
}
