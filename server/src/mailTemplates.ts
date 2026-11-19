import {
  MAIL_COLORS as C,
  MAIL_COPY,
  MAIL_FONT_BODY,
  MAIL_FONT_DISPLAY,
  MAIL_FONTS_URL,
  MAIL_LINK_HINT,
  MAIL_MAX_WIDTH,
  MAIL_SITE_HOST,
} from './mailConstants.js'
import {
  GARMIN_CATALOG,
  INVITE_REQUEST,
  MAIL_INVITE_SUBJECT,
  MAIL_RESET_SUBJECT,
  MAIL_RESET_TEXT,
  MAIL_VERIFY_SUBJECT,
  MAIL_VERIFY_TEXT,
} from './constants.js'
import type { GarminCatalogMailInput, InviteMailInput, InviteRequestMailInput, MailContent, MailLayout } from './mailTemplates.types.js'

export function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
}

function paragraph(style: string, content: string): string {
  return `<p style="margin:0;${style}">${content}</p>`
}

function brand(): string {
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 26px 0"><tr>
<td width="30" height="30" align="center" valign="middle" style="width:30px;height:30px;border-radius:8px;background:${C.tile};border:1px solid ${C.tileLine};font-family:${MAIL_FONT_DISPLAY};font-weight:800;font-size:12px;line-height:30px;color:${C.accent}">AI</td>
<td style="padding-left:10px;font-family:${MAIL_FONT_DISPLAY};font-weight:800;font-size:14px;letter-spacing:0.12em;color:${C.text}">TR<span style="color:${C.accent}">AI</span>NING</td>
</tr></table>`
}

export function cardRows(rows: ReadonlyArray<readonly [string, string]>, quote?: string): string {
  const cells = rows
    .map(
      ([label, value], index) =>
        `<tr><td style="padding:6px 12px 6px 0;${index === 0 ? '' : `border-top:1px solid ${C.line};`}font-size:14px;color:${C.muted}">${escapeHtml(label)}</td><td align="right" style="padding:6px 0;${index === 0 ? '' : `border-top:1px solid ${C.line};`}font-size:14px;color:${C.text}">${escapeHtml(value)}</td></tr>`,
    )
    .join('')
  const quoteRow =
    quote === undefined
      ? ''
      : `<tr><td colspan="2" style="padding:8px 0 0 0"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%"><tr><td style="border-left:3px solid ${C.accent};padding-left:10px;font-size:14px;font-style:italic;color:${C.body}">${escapeHtml(quote)}</td></tr></table></td></tr>`
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:20px 0 0 0;background:${C.card};border:1px solid ${C.line};border-radius:14px"><tr><td style="padding:14px 16px"><table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">${cells}${quoteRow}</table></td></tr></table>`
}

function layout(input: MailLayout): string {
  const host = input.showHost ? `<br>${MAIL_SITE_HOST}` : ''
  const linkLine = input.linkLine === undefined ? '' : paragraph(`font-size:12px;color:${C.muted};word-break:break-all`, input.linkLine)
  const intro = input.intro === undefined ? '' : paragraph(`color:${C.body}`, input.intro)
  return `<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark">
<meta name="supported-color-schemes" content="dark">
<title>${escapeHtml(input.title)}</title>
<link rel="stylesheet" href="${MAIL_FONTS_URL}">
</head>
<body style="margin:0;padding:0;background:${C.page};color:${C.text}">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;font-size:1px;line-height:1px;color:${C.page}">${escapeHtml(input.preheader)}</div>
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:${C.page}"><tr><td align="center" style="padding:0">
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="max-width:${MAIL_MAX_WIDTH}px;margin:0 auto"><tr><td style="padding:28px 26px 22px 26px;font-family:${MAIL_FONT_BODY};font-size:15px;line-height:1.55;color:${C.text}">
${brand()}
${paragraph(`font-family:${MAIL_FONT_DISPLAY};font-weight:700;font-size:11px;letter-spacing:0.18em;text-transform:uppercase;color:${C.accent};margin-bottom:8px`, escapeHtml(input.eyebrow))}
${paragraph(`font-family:${MAIL_FONT_DISPLAY};font-weight:800;font-size:26px;line-height:1.08;color:${C.text};margin-bottom:14px`, input.title)}
${intro}
${input.card ?? ''}
<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:26px 0 28px 0"><tr><td align="center" bgcolor="${C.accent}" style="border-radius:10px;background:${C.accent}"><a href="${escapeHtml(input.button.href)}" style="display:inline-block;padding:13px 22px;border-radius:10px;font-family:${MAIL_FONT_BODY};font-weight:700;font-size:15px;line-height:1.2;color:${C.accentText};text-decoration:none">${escapeHtml(input.button.label)}</a></td></tr></table>
${linkLine}
<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin-top:26px"><tr><td style="border-top:1px solid ${C.line};padding-top:14px;font-size:12px;line-height:1.5;color:${C.muted}">${escapeHtml(input.footer)}${host}</td></tr></table>
</td></tr></table>
</td></tr></table>
</body>
</html>`
}

function linkSpan(link: string): string {
  return `<span style="color:${C.accent}">${escapeHtml(link)}</span>`
}

export function verifyEmailMail(link: string): MailContent {
  const copy = MAIL_COPY.verify
  return {
    subject: MAIL_VERIFY_SUBJECT,
    text: `${MAIL_VERIFY_TEXT}\n\n${link}`,
    html: layout({
      preheader: copy.preheader,
      eyebrow: copy.eyebrow,
      title: copy.title,
      intro: copy.body,
      button: { label: copy.button, href: link },
      linkLine: `${MAIL_LINK_HINT} ${linkSpan(link)}`,
      footer: copy.footer,
      showHost: true,
    }),
  }
}

export function resetPasswordMail(link: string): MailContent {
  const copy = MAIL_COPY.reset
  return {
    subject: MAIL_RESET_SUBJECT,
    text: `${MAIL_RESET_TEXT}\n\n${link}`,
    html: layout({
      preheader: copy.preheader,
      eyebrow: copy.eyebrow,
      title: copy.title,
      intro: copy.body,
      button: { label: copy.button, href: link },
      linkLine: `${MAIL_LINK_HINT} ${linkSpan(link)}`,
      footer: copy.footer,
      showHost: true,
    }),
  }
}

export function inviteMail(input: InviteMailInput): MailContent {
  const copy = MAIL_COPY.invite
  return {
    subject: MAIL_INVITE_SUBJECT,
    text: input.message,
    html: layout({
      preheader: `${input.inviter} te convidou para o trAIning.`,
      eyebrow: copy.eyebrow,
      title: escapeHtml(`Oi, ${input.name}! ${input.inviter} te convidou.`),
      intro: copy.body,
      card: cardRows(copy.rows),
      button: { label: copy.button, href: input.link },
      linkLine: `${copy.linkHint} ${linkSpan(input.link)}`,
      footer: copy.footer,
      showHost: true,
    }),
  }
}

export function inviteRequestMail(input: InviteRequestMailInput): MailContent {
  const copy = MAIL_COPY.inviteRequest
  const message = input.message === '' ? undefined : input.message
  const text = `${input.name} (${input.email}) pediu um convite.\nRelógio: ${input.watch}\n${message === undefined ? copy.noMessage : `Mensagem: ${message}`}\n\nVer em Ajustes › Convites no app: ${input.link}`
  const card = cardRows(
    [
      [copy.labels.name, input.name],
      [copy.labels.email, input.email],
      [copy.labels.watch, input.watch],
    ],
    message ?? copy.noMessage,
  )
  return {
    subject: INVITE_REQUEST.mailSubject,
    text,
    html: layout({
      preheader: copy.preheader,
      eyebrow: copy.eyebrow,
      title: copy.title,
      card,
      button: { label: copy.button, href: input.link },
      footer: copy.footer,
      showHost: false,
    }),
  }
}

function catalogSection(title: string, items: string[]): string {
  if (items.length === 0) return ''
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:22px 0 0 0"><tr><td style="font-family:${MAIL_FONT_DISPLAY};font-weight:700;font-size:13px;letter-spacing:0.06em;text-transform:uppercase;color:${C.muted};padding-bottom:8px">${escapeHtml(title)}</td></tr>${items.join('')}</table>`
}

function catalogItem(name: string, id: string, warning?: string): string {
  const border = warning === undefined ? '' : `border-left:3px solid ${C.warn};padding-left:10px;`
  const note = warning === undefined ? '' : `<br><span style="font-size:12px;color:${C.warn}">${escapeHtml(warning)}</span>`
  return `<tr><td style="padding:3px 0;${border}font-size:14px;color:${C.text}">${escapeHtml(name)}<br><span style="font-family:ui-monospace,Menlo,monospace;font-size:12px;color:${C.muted};word-break:break-all">${escapeHtml(id)}</span>${note}</td></tr>`
}

export function garminCatalogMail(input: GarminCatalogMailInput): MailContent {
  const copy = MAIL_COPY.garminCatalog
  const { added, removed, renamed } = input.diff
  const label = (name: string | null) => name ?? copy.noName
  const subject = `Catálogo da Garmin mudou: ${added.length} novos, ${removed.length} removidos, ${renamed.length} renomeados`
  const textLines = [
    copy.body,
    '',
    ...removed.map((item) => `Removido: ${item.id} (${label(item.name)})${item.referenced ? ` — ${copy.referenced}` : ''}`),
    ...added.map((item) => `Novo: ${item.id} (${label(item.name)})`),
    ...renamed.map((item) => `Renomeado: ${item.id} (${label(item.from)} → ${label(item.to)})`),
    '',
    `Rode: ${GARMIN_CATALOG.command}`,
  ]
  const card = cardRows([
    [copy.labels.added, String(added.length)],
    [copy.labels.removed, String(removed.length)],
    [copy.labels.renamed, String(renamed.length)],
    [copy.labels.checked, input.checkedOn],
  ])
  const sections = [
    catalogSection(copy.sections.removed, removed.map((item) => catalogItem(label(item.name), item.id, item.referenced ? copy.referenced : undefined))),
    catalogSection(copy.sections.added, added.map((item) => catalogItem(label(item.name), item.id))),
    catalogSection(copy.sections.renamed, renamed.map((item) => catalogItem(`${label(item.from)} → ${label(item.to)}`, item.id))),
    `<table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="margin:20px 0 0 0;background:${C.card};border:1px solid ${C.line};border-radius:10px"><tr><td style="padding:12px 14px;font-family:ui-monospace,Menlo,monospace;font-size:13px;color:${C.accent}">${escapeHtml(GARMIN_CATALOG.command)}</td></tr></table>`,
  ].join('')
  return {
    subject,
    text: textLines.join('\n'),
    html: layout({
      preheader: copy.preheader,
      eyebrow: copy.eyebrow,
      title: copy.title,
      intro: copy.body,
      card: card + sections,
      button: { label: copy.button, href: GARMIN_CATALOG.repositoryUrl },
      footer: copy.footer,
      showHost: false,
    }),
  }
}
