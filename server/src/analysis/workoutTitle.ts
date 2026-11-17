const WEEKDAYS = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'sab', 'dom']

function clean(title: string): string {
  const [first, second, ...rest] = title.split(' ')
  if (first === undefined || second === undefined || rest.length === 0) return title
  return first.localeCompare(second, 'pt-BR', { sensitivity: 'base' }) === 0 ? [second, ...rest].join(' ') : title
}

export function comparisonKey(title: string): string {
  const words = clean(title).toLowerCase().split(' ').filter((word) => word.length > 0)
  const weekday = words.findIndex((word) => WEEKDAYS.includes(word))
  if (weekday >= 0) return words.slice(0, weekday).join(' ')
  const last = words.at(-1)
  if (last !== undefined && words.length > 1 && WEEKDAYS.some((day) => day.startsWith(last) && day !== last)) words.pop()
  return words.join(' ')
}
