import type { LineChartProps } from './components.types'

const WIDTH = 520
const PAD = 8

function dayIndex(first: string, day: string): number {
  return Math.round((new Date(`${day}T12:00:00Z`).getTime() - new Date(`${first}T12:00:00Z`).getTime()) / 86_400_000)
}

export function LineChart({ lines, label, height = 170, marker }: LineChartProps) {
  const all = lines.flatMap((line) => line.points)
  const days = all.map(([day]) => day).sort()
  const first = days[0]
  const last = days.at(-1)
  if (first === undefined || last === undefined) {
    return null
  }
  const span = Math.max(1, dayIndex(first, last))
  const values = all.map(([, value]) => value)
  const minimum = Math.min(...values)
  const maximum = Math.max(...values)
  const range = maximum - minimum || 1
  const x = (day: string) => (dayIndex(first, day) / span) * WIDTH
  const y = (value: number) => PAD + (1 - (value - minimum) / range) * (height - PAD * 2)
  return (
    <svg viewBox={`0 0 ${WIDTH} ${height}`} width="100%" height={height} role="img" aria-label={label} preserveAspectRatio="none">
      {marker !== undefined && (
        <>
          <line x1={WIDTH - 1} y1="0" x2={WIDTH - 1} y2={height} stroke="var(--line-2)" strokeDasharray="4 4" />
          <text x={WIDTH - 6} y="14" fill="var(--dim)" fontSize="11" textAnchor="end">{marker}</text>
        </>
      )}
      {lines.map((line, index) => (
        <polyline
          key={index}
          fill="none"
          stroke={line.color}
          strokeWidth={line.width ?? 2}
          vectorEffect="non-scaling-stroke"
          strokeLinejoin="round"
          points={line.points.map(([day, value]) => `${x(day).toFixed(1)},${y(value).toFixed(1)}`).join(' ')}
        />
      ))}
    </svg>
  )
}
