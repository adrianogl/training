import { useEffect, useState } from 'react'
import { BASE_PATH, PATHS } from './constants'
import type { Route } from './types'

const NAVIGATE_EVENT = 'training:navigate'

export function routeFromPath(pathname: string): Route | undefined {
  const relative = pathname.startsWith(BASE_PATH) ? pathname.slice(BASE_PATH.length) : pathname
  const trimmed = relative.replace(/\/+$/, '')
  const match = (Object.entries(PATHS) as [Route, string][]).find(([, path]) => path === trimmed)
  return match?.[0]
}

export function hrefFor(route: Route): string {
  return `${BASE_PATH}${PATHS[route]}`
}

export function navigate(route: Route, replace = false): void {
  const href = hrefFor(route)
  if (replace) {
    window.history.replaceState(null, '', href)
  } else {
    window.history.pushState(null, '', href)
  }
  window.dispatchEvent(new Event(NAVIGATE_EVENT))
}

export function queryParam(name: string): string | null {
  return new URLSearchParams(window.location.search).get(name)
}

export function useRoute(): Route | undefined {
  const [route, setRoute] = useState(() => routeFromPath(window.location.pathname))
  useEffect(() => {
    const update = () => setRoute(routeFromPath(window.location.pathname))
    window.addEventListener('popstate', update)
    window.addEventListener(NAVIGATE_EVENT, update)
    return () => {
      window.removeEventListener('popstate', update)
      window.removeEventListener(NAVIGATE_EVENT, update)
    }
  }, [])
  return route
}
