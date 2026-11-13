import { ADMIN_TIME_ZONE } from './constants.js'
import type { AdminMetrics, HourlyBucket, RecentRequest } from './types.js'

const STYLE = `
:root { --bg: #07080A; --line: #23262d; --panel: #0d0f12; --fg: #EEF1F3; --muted: #8E959E; --accent: #C8F05A;
  --accent-ink: #0b0d08; --race: #FF8A4C; --danger: #FF6B6B; --ok: #8FE07A;
  --display: "Barlow Condensed", "Arial Narrow", system-ui, sans-serif; --body: "Inter", -apple-system, system-ui, sans-serif;
  --mono: "JetBrains Mono", ui-monospace, Menlo, monospace; color-scheme: dark; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--fg); font: 14px/1.5 var(--body);
  padding: 24px max(16px, env(safe-area-inset-right, 0px)) 48px max(16px, env(safe-area-inset-left, 0px));
  background-image: radial-gradient(600px 380px at 15% -5%, rgba(200,240,90,.10), transparent 70%); }
main { max-width: 1100px; margin: 0 auto; }
.dash { background: var(--panel); border: 1px solid var(--line); border-radius: 16px; overflow: hidden; }
.dash-top { display: flex; flex-wrap: wrap; justify-content: space-between; align-items: center; gap: 10px; padding: 14px 18px; border-bottom: 1px solid var(--line); }
.dash-top b { font: 700 20px/1 var(--display); letter-spacing: .03em; }
.dash-top b span { color: var(--accent); }
.env { font: 12px var(--mono); color: var(--muted); overflow-wrap: anywhere; }
.tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 1px; background: var(--line); }
.tile { background: var(--panel); padding: 14px 18px; display: grid; gap: 4px; min-width: 0; }
.lbl { font-size: 11px; color: var(--muted); }
.num { font: 700 32px/1 var(--display); font-variant-numeric: tabular-nums; }
.num.ok { color: var(--ok); } .num.err { color: var(--danger); }
.sub { font-size: 11.5px; color: var(--muted); }
.dash-body { display: grid; grid-template-columns: minmax(0, 1.4fr) minmax(0, 1fr); gap: 1px; background: var(--line); }
.panel { background: var(--panel); padding: 16px 18px; display: grid; gap: 10px; align-content: start; min-width: 0; }
h1 { margin: 0; font: 600 12px/1 var(--body); letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
.bars { display: grid; grid-template-columns: repeat(24, 1fr); align-items: end; gap: 3px; height: 90px; }
.bar { background: rgba(200,240,90,.55); border-radius: 2px 2px 0 0; min-height: 1px; }
.bar.e { background: var(--danger); }
.axis { display: flex; justify-content: space-between; font: 10.5px var(--mono); color: var(--muted); }
.log { overflow-x: auto; }
table { border-collapse: collapse; width: 100%; min-width: 320px; font: 12px/1.4 var(--mono); }
td { padding: 6px 12px 6px 0; border-bottom: 1px solid #1c1f25; white-space: nowrap; }
td.s2 { color: var(--ok); } td.s4 { color: var(--race); } td.s5 { color: var(--danger); }
.empty { color: var(--muted); font-size: 12px; }
.login { max-width: 360px; margin: 12vh auto 0; display: grid; gap: 14px; }
.login h2 { font: 700 34px/1 var(--display); margin: 0; }
.login h2 span { color: var(--accent); }
label { font-size: 12px; color: var(--muted); display: grid; gap: 6px; }
input { font: 14px var(--mono); color: var(--fg); background: rgba(0,0,0,.35); border: 1px solid var(--line); border-radius: 10px; padding: 12px; width: 100%; }
button { font: 600 15px var(--body); background: var(--accent); color: var(--accent-ink); border: 0; border-radius: 14px; padding: 12px; }
.error { color: var(--danger); font-size: 12px; margin: 0; }
.muted { color: var(--muted); margin: 0; }
@media (max-width: 760px) { .dash-body { grid-template-columns: 1fr; } }
`

function escapeHtml(value: string): string {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;')
}

function layout(title: string, body: string): string {
  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@600;700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap">
<style>${STYLE}</style>
</head>
<body><main>${body}</main></body>
</html>`
}

function formatTime(iso: string): string {
  return new Intl.DateTimeFormat('pt-BR', { timeZone: ADMIN_TIME_ZONE, hour: '2-digit', minute: '2-digit' }).format(
    new Date(iso),
  )
}

function formatHour(iso: string): string {
  return `${new Intl.DateTimeFormat('pt-BR', { timeZone: ADMIN_TIME_ZONE, hour: 'numeric' }).format(new Date(iso))}h`
}

function plural(count: number, singular: string, pluralForm: string): string {
  return `${count} ${count === 1 ? singular : pluralForm}`
}

function tile(label: string, value: string, sub: string, tone = ''): string {
  const numClass = tone === '' ? 'num' : `num ${tone}`
  return `<div class="tile"><span class="lbl">${escapeHtml(label)}</span><span class="${numClass}">${escapeHtml(value)}</span><span class="sub">${escapeHtml(sub)}</span></div>`
}

function bars(hourly: HourlyBucket[]): string {
  const peak = Math.max(1, ...hourly.map((bucket) => bucket.total))
  const spans = hourly
    .map((bucket) => {
      const height = Math.round((bucket.total / peak) * 100)
      const tone = bucket.errors > 0 ? 'bar e' : 'bar'
      return `<span class="${tone}" style="height:${height}%" title="${escapeHtml(formatHour(bucket.hourStart))}: ${bucket.total}"></span>`
    })
    .join('')
  const ticks = [0, 6, 12, 18, hourly.length - 1]
    .map((index) => hourly[index])
    .filter((bucket): bucket is HourlyBucket => bucket !== undefined)
    .map((bucket) => `<span>${escapeHtml(formatHour(bucket.hourStart))}</span>`)
    .join('')
  return `<div class="bars" aria-hidden="true">${spans}</div><div class="axis">${ticks}</div>`
}

function countLabel(entry: RecentRequest): string {
  if (entry.recordCount === null) {
    return entry.status === 429 ? 'rate limit' : ''
  }
  return entry.method === 'GET' ? plural(entry.recordCount, 'novo', 'novos') : plural(entry.recordCount, 'registro', 'registros')
}

function recentTable(recent: RecentRequest[]): string {
  if (recent.length === 0) {
    return '<p class="empty">Nenhuma requisição registrada.</p>'
  }
  const rows = recent
    .map(
      (entry) =>
        `<tr><td>${escapeHtml(formatTime(entry.at))}</td><td>${escapeHtml(`${entry.method} ${entry.route}`)}</td><td class="s${String(entry.status)[0]}">${entry.status}</td><td>${escapeHtml(countLabel(entry))}</td></tr>`,
    )
    .join('')
  return `<table>${rows}</table>`
}

function header(host: string): string {
  return `<div class="dash-top"><b>tr<span>AI</span>ning sync</b><span class="env">${escapeHtml(host)}</span></div>`
}

export function renderAdminPage(metrics: AdminMetrics, host: string): string {
  const { race, decision } = metrics.records
  const lastWrite = metrics.lastWrite.at === null ? '—' : formatTime(metrics.lastWrite.at)
  const tiles = [
    tile('Status', 'OK', `banco respondendo em ${metrics.database.latencyMs} ms`, 'ok'),
    tile('Contas', String(metrics.accounts), 'chaves de sync ativas'),
    tile('Provas', String(race.live), plural(race.deleted, 'apagada', 'apagadas')),
    tile('Respostas', String(decision.live), plural(decision.deleted, 'apagada', 'apagadas')),
    tile('Última escrita', lastWrite, `seq ${metrics.lastWrite.seq}`),
    tile('Erros 24 h', String(metrics.errors24h), 'status 4xx e 5xx', metrics.errors24h > 0 ? 'err' : ''),
  ].join('')
  return layout(
    'Painel do sync',
    `<div class="dash">${header(host)}<div class="tiles">${tiles}</div>
<div class="dash-body"><section class="panel"><h1>Requisições por hora · últimas 24 h</h1>${bars(metrics.hourly)}</section>
<section class="panel log"><h1>Últimas requisições</h1>${recentTable(metrics.recent)}</section></div></div>`,
  )
}

export function renderLoginPage(failed: boolean): string {
  const error = failed ? '<p class="error">Token inválido.</p>' : ''
  return layout(
    'Painel do sync',
    `<form method="post" action="/admin" class="login"><h2>tr<span>AI</span>ning sync</h2>
<label>Token de administrador<input type="password" name="token" autocomplete="current-password" required autofocus></label>${error}
<button type="submit">Entrar</button></form>`,
  )
}

export function renderDisabledPage(): string {
  return layout(
    'Painel desativado',
    '<div class="login"><h2>tr<span>AI</span>ning sync</h2><p class="muted">Painel desativado: ADMIN_TOKEN ausente ou com menos de 32 caracteres.</p></div>',
  )
}

export function renderUnavailablePage(): string {
  return layout(
    'Painel do sync',
    `<div class="dash"><div class="tiles">${tile('Status', 'ERRO', 'banco não respondeu', 'err')}</div></div>`,
  )
}
