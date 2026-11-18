export const MAIL_MAX_WIDTH = 560
export const MAIL_SITE_HOST = 'training.aglv.dev'
export const MAIL_FONTS_URL =
  'https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,400..900&family=Inter:wght@400;500;600;700&display=swap'
export const MAIL_FONT_DISPLAY = "Archivo,'Arial Black',Arial,sans-serif"
export const MAIL_FONT_BODY = 'Inter,Arial,sans-serif'
export const MAIL_COLORS = {
  page: '#07080a',
  text: '#f2f2f0',
  body: '#c9cdd1',
  muted: '#8f959c',
  accent: '#c8f05a',
  accentText: '#0b0d0a',
  line: '#22262a',
  card: '#121517',
  tile: '#1a2410',
  tileLine: '#3c5214',
} as const
export const MAIL_LINK_HINT = 'Se o botão não abrir, copie este link:'

export const MAIL_COPY = {
  verify: {
    preheader: 'Confirme o e-mail da sua conta no trAIning.',
    eyebrow: 'Sua conta',
    title: 'Confirme seu e-mail',
    body: 'Toque no botão para confirmar o e-mail da sua conta no trAIning. O link vale por 24 horas.',
    button: 'Confirmar e-mail',
    footer: 'Você recebeu este e-mail porque criou uma conta no trAIning.',
  },
  reset: {
    preheader: 'Crie uma senha nova para a sua conta no trAIning.',
    eyebrow: 'Sua conta',
    title: 'Crie uma senha nova',
    body: 'Toque no botão para criar uma senha nova. O link vale por 30 minutos.',
    button: 'Criar senha nova',
    footer: 'Se não foi você, ignore este e-mail. Sua senha continua a mesma.',
  },
  invite: {
    eyebrow: 'Convite',
    body: 'O trAIning lê os dados da sua Garmin e mostra a prontidão do dia, a análise dos treinos e a previsão das provas.',
    rows: [
      ['Prontidão', 'de 0 a 100, toda manhã'],
      ['Treinos', 'nota e análise de cada corrida'],
      ['Provas', 'previsão e estratégia km a km'],
    ],
    button: 'Criar minha conta',
    linkHint: 'O convite vale por 7 dias. Link:',
    footer: 'Projeto pessoal, sem vínculo com a Garmin.',
  },
  inviteRequest: {
    preheader: 'Alguém pediu um convite para o trAIning.',
    eyebrow: 'Admin',
    title: 'Novo pedido de convite',
    labels: { name: 'Nome', email: 'E-mail', watch: 'Relógio' },
    noMessage: 'Sem mensagem.',
    button: 'Ver no app',
    footer: 'Aviso automático do admin do trAIning.',
  },
} as const
