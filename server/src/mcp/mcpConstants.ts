export const MCP = {
  route: 'mcp',
  protocolVersion: '2025-06-18',
  serverName: 'trAIning',
  serverVersion: '1.0.0',
  maxBodyBytes: 256 * 1024,
  callsPerMinute: 60,
  contextId: 'strengthContext',
  claudeId: 'strengthClaude',
  tokenBytes: 32,
} as const

export const JSON_RPC = {
  parseError: -32700,
  invalidRequest: -32600,
  methodNotFound: -32601,
  invalidParams: -32602,
  internalError: -32603,
} as const

export const FEEDBACK = {
  blobId: 'exerciseFeedback',
  accountPrefixLength: 8,
  accountPrefixPattern: /^[0-9a-f]{1,64}$/,
  referenceEpochSeconds: 978307200,
  minimumBumpSeconds: 1,
  doesNotMatch: 'doesNotMatch',
  pending: 'pending',
  resolved: 'resolved',
  listTool: 'avaliacoes_imagens',
  resolveTool: 'resolver_avaliacao',
} as const
