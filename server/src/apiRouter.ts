import { inviteRequestActionRoute, inviteRequestRoute } from './inviteRequestRoutes.js'
import { activityRoute, detailedActivityRoute, plannedRoute, renameActivityRoute } from './activityRoutes.js'
import { deleteRaceRoute, racesRoute, saveRaceRoute } from './raceRoutes.js'
import { deleteGoalRoute, goalsRoute, saveGoalRoute } from './goalRoutes.js'
import {
  changePasswordRoute,
  forgotPasswordRoute,
  loginRoute,
  logoutRoute,
  meRoute,
  resendVerificationRoute,
  resetPasswordRoute,
  sessionsRoute,
  signupRoute,
  verifyEmailRoute,
} from './authRoutes.js'
import { adminCreateInviteRoute, adminDeleteUserRoute, adminInviteActionRoute, adminOverviewRoute, invitePreviewRoute } from './adminRoutes.js'
import { API_PATH_PREFIX, API_ROUTER_QUERY } from './constants.js'
import type { Sql } from './db.js'
import {
  garminActivitiesRoute,
  garminConnectRoute,
  garminCronRoute,
  garminDaysRoute,
  garminSessionRoute,
  garminStatusRoute,
  garminSyncRoute,
  garminTodayRoute,
  garminEvolutionRoute,
  garminVerifyRoute,
} from './garminRoutes.js'
import {
  createAccountRoute,
  deleteAccountRoute,
  deleteWatchTokenRoute,
  getWatchReadinessRoute,
  pullChangesRoute,
  pushChangesRoute,
  putWatchReadinessRoute,
  putWatchTokenRoute,
} from './routes.js'

type Handler = (request: Request, sql: Sql) => Promise<Response>

const ROUTES: Record<string, Partial<Record<string, Handler>>> = {
  account: { POST: (request, sql) => createAccountRoute(request, sql), DELETE: deleteAccountRoute },
  changes: { GET: pullChangesRoute, POST: (request, sql) => pushChangesRoute(request, sql) },
  'watch/token': { PUT: putWatchTokenRoute, DELETE: deleteWatchTokenRoute },
  'watch/readiness': { GET: getWatchReadinessRoute, PUT: putWatchReadinessRoute },
  'auth/signup': { POST: (request, sql) => signupRoute(request, sql) },
  'auth/login': { POST: (request, sql) => loginRoute(request, sql) },
  'auth/logout': { POST: (request, sql) => logoutRoute(request, sql) },
  'auth/me': { GET: (request, sql) => meRoute(request, sql), PATCH: (request, sql) => meRoute(request, sql) },
  'auth/password': { POST: (request, sql) => changePasswordRoute(request, sql) },
  'auth/forgot': { POST: (request, sql) => forgotPasswordRoute(request, sql) },
  'auth/reset': { POST: (request, sql) => resetPasswordRoute(request, sql) },
  'auth/verify': { POST: (request, sql) => verifyEmailRoute(request, sql) },
  'auth/resend-verification': { POST: (request, sql) => resendVerificationRoute(request, sql) },
  'auth/sessions': { GET: (request, sql) => sessionsRoute(request, sql), DELETE: (request, sql) => sessionsRoute(request, sql) },
  'garmin/connect': { POST: (request, sql) => garminConnectRoute(request, sql) },
  'garmin/verify': { POST: (request, sql) => garminVerifyRoute(request, sql) },
  'garmin/status': { GET: (request, sql) => garminStatusRoute(request, sql), DELETE: (request, sql) => garminStatusRoute(request, sql) },
  'garmin/session': { GET: (request, sql) => garminSessionRoute(request, sql) },
  'garmin/sync': { POST: (request, sql) => garminSyncRoute(request, sql) },
  goals: { GET: (request, sql) => goalsRoute(request, sql), POST: (request, sql) => saveGoalRoute(request, sql), PUT: (request, sql) => saveGoalRoute(request, sql), DELETE: (request, sql) => deleteGoalRoute(request, sql) },
  races: { GET: (request, sql) => racesRoute(request, sql), POST: (request, sql) => saveRaceRoute(request, sql), PUT: (request, sql) => saveRaceRoute(request, sql), DELETE: (request, sql) => deleteRaceRoute(request, sql) },
  'garmin/planned': { GET: (request, sql) => plannedRoute(request, sql) },
  'garmin/activity': { GET: (request, sql) => activityRoute(request, sql), PUT: (request, sql) => renameActivityRoute(request, sql) },
  'garmin/activity/detailed': { GET: (request, sql) => detailedActivityRoute(request, sql) },
  'garmin/evolution': { GET: (request, sql) => garminEvolutionRoute(request, sql) },
  'garmin/today': { GET: (request, sql) => garminTodayRoute(request, sql) },
  'garmin/days': { GET: (request, sql) => garminDaysRoute(request, sql) },
  'garmin/activities': { GET: (request, sql) => garminActivitiesRoute(request, sql) },
  'cron/garmin-sync': { GET: (request, sql) => garminCronRoute(request, sql) },
  'admin/overview': { GET: (request, sql) => adminOverviewRoute(request, sql) },
  'admin/invites': { POST: (request, sql) => adminCreateInviteRoute(request, sql) },
  'admin/invites/action': { POST: (request, sql) => adminInviteActionRoute(request, sql) },
  'invite-requests': { POST: (request, sql) => inviteRequestRoute(request, sql) },
  'admin/invite-requests/action': { POST: (request, sql) => inviteRequestActionRoute(request, sql) },
  'admin/users': { DELETE: (request, sql) => adminDeleteUserRoute(request, sql) },
  'invites/preview': { GET: (request, sql) => invitePreviewRoute(request, sql) },
}

export function routeKey(request: Request): string {
  const url = new URL(request.url)
  const fromQuery = url.searchParams.get(API_ROUTER_QUERY)
  const path = fromQuery ?? (url.pathname.startsWith(API_PATH_PREFIX) ? url.pathname.slice(API_PATH_PREFIX.length) : '')
  return path.replace(/^\/+|\/+$/g, '')
}

export function dispatch(request: Request, sql: Sql): Promise<Response> {
  const routes = ROUTES[routeKey(request)]
  if (routes === undefined) {
    return Promise.resolve(Response.json({ error: 'not_found' }, { status: 404 }))
  }
  const handler = routes[request.method]
  if (handler === undefined) {
    return Promise.resolve(
      Response.json({ error: 'method_not_allowed' }, { status: 405, headers: { allow: Object.keys(routes).join(', ') } }),
    )
  }
  return handler(request, sql)
}
