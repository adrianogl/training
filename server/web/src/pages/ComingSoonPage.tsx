import { TEXT } from '../constants'
import type { ComingSoonProps } from './pages.types'

export function ComingSoonPage({ title }: ComingSoonProps) {
  return (
    <section className="page">
      <h1>{title}</h1>
      <div className="card">
        <span className="label">{TEXT.comingSoonTitle.toUpperCase()}</span>
        <p className="muted" style={{ margin: 0, fontSize: 15 }}>
          {TEXT.comingSoonText}
        </p>
      </div>
    </section>
  )
}
