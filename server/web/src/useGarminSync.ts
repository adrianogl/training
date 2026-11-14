import { useEffect, useState } from 'react'
import { api } from './api'
import { DATA_TEXT } from './constants'
import type { SyncState } from './types'

const ROUND_PAUSE_MS = 1_500
const MAX_ROUNDS = 12
const REPEAT_MS = 30 * 60 * 1000

export function useGarminSync(enabled: boolean): { state: SyncState; version: number } {
  const [state, setState] = useState<SyncState>({ kind: 'idle' })
  const [version, setVersion] = useState(0)

  useEffect(() => {
    if (!enabled) {
      return
    }
    let stopped = false
    async function run() {
      let days = 0
      for (let round = 0; round < MAX_ROUNDS && !stopped; round += 1) {
        const result = await api.garminSync()
        if (stopped) {
          return
        }
        if (!result.ok) {
          setState(result.error === 'garmin_not_connected' ? { kind: 'disconnected' } : { kind: 'error', message: DATA_TEXT.syncError })
          return
        }
        days += result.value.days
        setVersion((current) => current + 1)
        if (result.value.done) {
          setState({ kind: 'done', at: new Date() })
          return
        }
        setState({ kind: 'running', days })
        await new Promise((resolve) => setTimeout(resolve, ROUND_PAUSE_MS))
      }
    }
    setState({ kind: 'running', days: 0 })
    void run()
    const timer = setInterval(() => void run(), REPEAT_MS)
    return () => {
      stopped = true
      clearInterval(timer)
    }
  }, [enabled])

  return { state, version }
}
