import type { SplitChartProps } from './components.types'

const WIDTH = 760
const HEIGHT = 180
const PAD = 12

function points(values: number[], invert: boolean): string {
  if (values.length === 0) return ''
  const minimum = Math.min(...values)
  const range = Math.max(...values) - minimum || 1
  const step = values.length > 1 ? WIDTH / (values.length - 1) : 0
  return values
    .map((value, index) => {
      const share = (value - minimum) / range
      const y = PAD + (invert ? share : 1 - share) * (HEIGHT - PAD * 2)
      return `${(index * step).toFixed(1)},${y.toFixed(1)}`
    })
    .join(' ')
}

export function SplitChart({ pace, heartRate, label }: SplitChartProps) {
  return (
    <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} width="100%" height={HEIGHT} role="img" aria-label={label} preserveAspectRatio="none">
      {[0.25, 0.5, 0.75].map((share) => (
        <line key={share} x1="0" y1={HEIGHT * share} x2={WIDTH} y2={HEIGHT * share} stroke="var(--track)" vectorEffect="non-scaling-stroke" />
      ))}
      <polyline fill="none" stroke="var(--accent)" strokeWidth="3" vectorEffect="non-scaling-stroke" strokeLinejoin="round" points={points(pace, true)} />
      <polyline fill="none" stroke="#ff8a4c" strokeWidth="2" strokeDasharray="6 4" vectorEffect="non-scaling-stroke" strokeLinejoin="round" points={points(heartRate, false)} />
    </svg>
  )
}
