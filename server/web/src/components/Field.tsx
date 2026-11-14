import type { FieldProps } from './components.types'

export function Field({ label, type = 'text', value, onChange, autoComplete }: FieldProps) {
  return (
    <label className="field">
      {label}
      <input type={type} value={value} autoComplete={autoComplete} onChange={(event) => onChange(event.target.value)} />
    </label>
  )
}
