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
