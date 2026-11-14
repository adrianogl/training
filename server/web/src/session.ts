import { TOKEN_STORAGE_KEY } from './constants'

function storages(): Storage[] {
  try {
    return [window.localStorage, window.sessionStorage]
  } catch {
    return []
  }
}

export function readToken(): string | null {
  for (const storage of storages()) {
    const value = storage.getItem(TOKEN_STORAGE_KEY)
    if (value !== null) {
      return value
    }
  }
  return null
}

export function saveToken(token: string, persistent: boolean): void {
  clearToken()
  const [local, session] = storages()
  ;(persistent ? local : session)?.setItem(TOKEN_STORAGE_KEY, token)
}

export function clearToken(): void {
  for (const storage of storages()) {
    storage.removeItem(TOKEN_STORAGE_KEY)
  }
}
