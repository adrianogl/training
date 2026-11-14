import { useEffect, useState } from 'react'
import { api } from '../api'
import { AuthLayout } from '../components/AuthLayout'
import { Link } from '../components/Link'
import { Message } from '../components/Message'
import { TEXT } from '../constants'
import { queryParam } from '../router'
import type { ConfirmProps } from './pages.types'

export function ConfirmPage({ signedIn }: ConfirmProps) {
  const [state, setState] = useState<'working' | 'done' | 'failed'>('working')

  useEffect(() => {
    void api.verify(queryParam('token') ?? '').then((result) => setState(result.ok ? 'done' : 'failed'))
  }, [])

  return (
    <AuthLayout>
      <div className="form">
        <h1>{TEXT.confirmTitle}</h1>
        {state === 'done' && <Message notice={TEXT.confirmDone} />}
        {state === 'failed' && <Message error={TEXT.confirmFailed} />}
        <p className="center">
          <Link to={signedIn ? 'today' : 'login'}>{signedIn ? TEXT.goToday : TEXT.backToLogin}</Link>
        </p>
      </div>
    </AuthLayout>
  )
}
