import { TRAINER_TEXT } from '../constants'
import type { TrainerStripProps } from './components.types'

export function TrainerStrip({ cells }: TrainerStripProps) {
  return (
    <div className="trainer-strip" role="list" aria-label={TRAINER_TEXT.weeksTitle}>
      {cells.map((cell) => (
        <div
          key={cell.id}
          role="listitem"
          className={`trainer-cell${cell.phase === null ? ' race' : ` phase-${cell.phase}`}${cell.current ? ' current' : ''}${cell.past ? ' past' : ''}`}
          aria-current={cell.current ? 'date' : undefined}
        >
          <small>{cell.title}</small>
          <b className="num">{cell.kilometers}</b>
          <small>{cell.detail}</small>
          {cell.phase !== null && <i>{TRAINER_TEXT.phases[cell.phase]}</i>}
        </div>
      ))}
    </div>
  )
}
