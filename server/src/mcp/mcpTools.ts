import type { Sql } from '../db.js'
import { MCP } from './mcpConstants.js'
import { MCP_TEXT } from './mcpText.js'
import { readBlob, writeBlob } from './mcpStore.js'
import { isAdminAccount, listFeedback, resolveFeedback } from './feedbackTools.js'
import { FEEDBACK } from './mcpConstants.js'
import { parseResponse, validateResponse } from './strengthValidator.js'
import type { DayReport, StrengthContext } from './strengthTypes.js'

export interface ToolResult {
  content: { type: 'text'; text: string }[]
  isError?: boolean
}

interface StoredContext {
  atualizado: string
  texto: string
  contexto: StrengthContext
}

const jsonInput = { type: 'object', properties: { json: { type: 'string', description: MCP_TEXT.jsonArgument } }, required: ['json'] }

export const TOOLS = [
  { name: 'contexto_forca', description: MCP_TEXT.contextDescription, inputSchema: { type: 'object', properties: {} } },
  { name: 'validar_treinos', description: MCP_TEXT.validateDescription, inputSchema: jsonInput },
  { name: 'salvar_treinos', description: MCP_TEXT.saveDescription, inputSchema: jsonInput },
]

export const ADMIN_TOOLS = [
  { name: FEEDBACK.listTool, description: MCP_TEXT.feedbackListDescription, inputSchema: { type: 'object', properties: {} } },
  {
    name: FEEDBACK.resolveTool,
    description: MCP_TEXT.feedbackResolveDescription,
    inputSchema: {
      type: 'object',
      properties: {
        conta: { type: 'string', description: MCP_TEXT.feedbackAccountArgument },
        id: { type: 'string', description: MCP_TEXT.feedbackIdArgument },
        resolucao: { type: 'string', description: MCP_TEXT.feedbackResolutionArgument },
        versao: { type: 'string', description: MCP_TEXT.feedbackVersionArgument },
      },
      required: ['conta', 'id', 'resolucao', 'versao'],
    },
  },
]

export async function toolsFor(sql: Sql, accountId: string) {
  return (await isAdminAccount(sql, accountId)) ? [...TOOLS, ...ADMIN_TOOLS] : TOOLS
}

const text = (value: string, isError = false): ToolResult => (isError ? { content: [{ type: 'text', text: value }], isError } : { content: [{ type: 'text', text: value }] })

function report(days: DayReport[]): string {
  return days
    .map((day) => {
      const lines = [`${day.dia}: ${day.erros.length === 0 ? 'ok' : 'erro'}${day.minutos_estimados === null ? '' : ` · ${day.minutos_estimados} min estimados`}`]
      for (const issue of day.erros) lines.push(`  erro: ${issue}`)
      for (const issue of day.avisos) lines.push(`  aviso: ${issue}`)
      return lines.join('\n')
    })
    .join('\n')
}

async function loadContext(sql: Sql, key: Buffer, accountId: string): Promise<StoredContext | null> {
  const blob = await readBlob(sql, key, accountId, MCP.contextId)
  return blob === null ? null : (JSON.parse(blob.text) as StoredContext)
}

async function validate(sql: Sql, key: Buffer, accountId: string, json: unknown): Promise<{ result: ToolResult; days?: DayReport[]; source?: string }> {
  if (typeof json !== 'string') return { result: text(MCP_TEXT.missingJson, true) }
  const stored = await loadContext(sql, key, accountId)
  if (stored === null) return { result: text(MCP_TEXT.noContext, true) }
  const parsed = parseResponse(json)
  if ('error' in parsed) {
    return { result: text(parsed.error === 'unsupported_version' ? MCP_TEXT.unsupportedVersion(parsed.version) : MCP_TEXT.invalidJson, true) }
  }
  const days = validateResponse(parsed, stored.contexto)
  return { result: text(report(days)), days, source: json }
}

export async function callTool(sql: Sql, key: Buffer, accountId: string, name: string, args: Record<string, unknown>, now: Date): Promise<ToolResult> {
  switch (name) {
    case 'contexto_forca': {
      const stored = await loadContext(sql, key, accountId)
      return stored === null ? text(MCP_TEXT.noContext, true) : text(`${MCP_TEXT.contextHeader(stored.atualizado)}\n\n${stored.texto}`)
    }
    case 'validar_treinos': {
      const { result, days } = await validate(sql, key, accountId, args.json)
      if (days === undefined) return result
      const invalid = days.filter((day) => day.erros.length > 0).length
      const summary = invalid === 0 ? MCP_TEXT.allValid(days.length) : MCP_TEXT.withErrors(days.length - invalid, invalid)
      return text(`${summary}\n\n${result.content[0]?.text ?? ''}`)
    }
    case 'salvar_treinos': {
      const { result, days, source } = await validate(sql, key, accountId, args.json)
      if (days === undefined || source === undefined) return result
      const saved = await writeBlob(sql, key, accountId, MCP.claudeId, JSON.stringify({ salvoEm: now.toISOString(), json: source }), now)
      if (!saved) return text(MCP_TEXT.saveFailed, true)
      const invalid = days.filter((day) => day.erros.length > 0).length
      return text(`${MCP_TEXT.saved(days.length - invalid, invalid)}\n\n${result.content[0]?.text ?? ''}`)
    }
    case FEEDBACK.listTool:
    case FEEDBACK.resolveTool: {
      if (!(await isAdminAccount(sql, accountId))) return text(MCP_TEXT.feedbackNotAdmin, true)
      const outcome = name === FEEDBACK.listTool ? await listFeedback(sql, key) : await resolveFeedback(sql, key, args, now)
      return text(outcome.text, outcome.isError)
    }
    default:
      return text(MCP_TEXT.unknownTool(name), true)
  }
}
