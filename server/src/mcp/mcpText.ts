export const MCP_TEXT = {
  instructions:
    'Servidor de força do trAIning. Para montar treinos: chame contexto_forca, monte o JSON no formato pedido, chame validar_treinos até não haver erros e então salvar_treinos. Os treinos só entram no app depois que o atleta revisa e aplica.',
  contextDescription: 'Lê o contexto de força do atleta (dias de força, MFIT, corrida, prontidão, dor, cargas, catálogo, regras) e o formato da resposta.',
  validateDescription: 'Valida um JSON de treinos de força com as regras do app. Devolve, por dia, erros (bloqueiam o dia) e avisos.',
  saveDescription: 'Valida e salva o JSON de treinos de força para o atleta revisar e aplicar no app. Substitui o que foi salvo antes e ainda não aplicado.',
  jsonArgument: 'JSON de treinos no formato "versao": 1, como texto.',
  noContext: 'O app ainda não enviou o contexto de força. Peça ao atleta para abrir Treinador › Força no app e tentar de novo.',
  contextHeader: (updated: string) => `Contexto atualizado pelo app em ${updated}.`,
  invalidJson: 'Não achei um JSON válido. Envie só o JSON no formato pedido.',
  unsupportedVersion: (version: number) => `Versão ${version} desconhecida. Use "versao": 1.`,
  allValid: (days: number) => `${days} dia(s) sem erros.`,
  withErrors: (valid: number, invalid: number) => `${valid} dia(s) sem erros e ${invalid} com erros. Corrija os erros e valide de novo.`,
  saved: (valid: number, invalid: number) =>
    invalid === 0
      ? `Salvo. ${valid} dia(s) prontos. O atleta precisa abrir Treinador › Força no app para revisar e aplicar.`
      : `Salvo. ${valid} dia(s) prontos e ${invalid} que o app vai recusar. O atleta precisa abrir Treinador › Força no app para revisar e aplicar.`,
  unknownTool: (name: string) => `Ferramenta desconhecida: ${name}`,
  missingJson: 'Falta o argumento "json".',
  rateLimited: 'Muitas chamadas. Espere um minuto.',
  saveFailed: 'Não deu para salvar: o espaço da conta acabou. Peça ao atleta para avisar o Adriano.',
  unauthorized: 'Token do MCP inválido ou revogado. Gere outro em Ajustes › Claude no app.',
} as const
