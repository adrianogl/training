import type { NavItem, Route } from './types'

export const BASE_PATH = '/app'
export const TOKEN_STORAGE_KEY = 'training.session'
export const DEVICE_LABEL = 'Site'
export const PASSWORD_MIN_LENGTH = 10

export const PATHS: Record<Route, string> = {
  login: '/entrar',
  signup: '/criar-conta',
  forgot: '/recuperar-senha',
  reset: '/redefinir-senha',
  confirm: '/confirmar',
  today: '/hoje',
  workouts: '/treinos',
  races: '/provas',
  evolution: '/evolucao',
  settings: '/ajustes',
  password: '/ajustes/senha',
  admin: '/admin',
  invite: '/convite',
}

export const PUBLIC_ROUTES: readonly Route[] = ['login', 'signup', 'forgot', 'reset', 'confirm', 'invite']

export const NAV_ITEMS: readonly NavItem[] = [
  { route: 'today', label: 'Hoje', icon: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4' },
  { route: 'workouts', label: 'Treinos', icon: 'M3 12h4l3-8 4 16 3-8h4' },
  { route: 'races', label: 'Provas', icon: 'M5 21V4h11l-2 4 2 4H5' },
  { route: 'evolution', label: 'Evolução', icon: 'M3 17l6-6 4 4 8-8M15 7h6v6' },
  { route: 'settings', label: 'Ajustes', icon: 'M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6zM19 12a7 7 0 0 0-.1-1.2l2-1.6-2-3.4-2.4 1a7 7 0 0 0-2-1.2L14 3h-4l-.5 2.6a7 7 0 0 0-2 1.2l-2.4-1-2 3.4 2 1.6A7 7 0 0 0 5 12c0 .4 0 .8.1 1.2l-2 1.6 2 3.4 2.4-1a7 7 0 0 0 2 1.2L10 21h4l.5-2.6a7 7 0 0 0 2-1.2l2.4 1 2-3.4-2-1.6c.1-.4.1-.8.1-1.2z' },
]

export const TEXT = {
  tagline: 'Inteligência do pulso à linha de chegada.',
  pitch: 'Prontidão, treinos, provas e evolução com os dados da sua Garmin, agora também no computador.',
  privacy: 'Os dados de saúde ficam cifrados no servidor.',
  loginTitle: 'Entrar',
  loginSubtitle: 'Use o mesmo e-mail e senha do app.',
  signupTitle: 'Criar conta',
  signupSubtitle: 'A mesma conta vale no site e no app.',
  forgotTitle: 'Recuperar senha',
  forgotSubtitle: 'Informe o e-mail da conta. Enviamos um link que vale por 30 minutos.',
  forgotSentTitle: 'Confira seu e-mail',
  forgotSentText: 'Se o e-mail tiver conta confirmada, o link chega em instantes. Olhe também o spam.',
  resetTitle: 'Nova senha',
  resetSubtitle: 'Depois de salvar, as outras sessões são encerradas.',
  resetDone: 'Senha alterada. Entre com a nova senha.',
  confirmTitle: 'Confirmando o e-mail',
  confirmDone: 'E-mail confirmado.',
  confirmFailed: 'O link de confirmação venceu ou já foi usado. Peça outro em Ajustes.',
  name: 'Nome',
  email: 'E-mail',
  password: 'Senha',
  confirmPassword: 'Confirmar senha',
  currentPassword: 'Senha atual',
  newPassword: 'Nova senha',
  confirmNewPassword: 'Confirmar nova senha',
  passwordHint: 'Mínimo de 10 caracteres.',
  newPasswordHint: 'Mínimo de 10 caracteres, diferente da atual.',
  keepSignedIn: 'Manter conectado neste computador',
  forgotLink: 'Esqueci a senha',
  enter: 'Entrar',
  create: 'Criar conta',
  sendLink: 'Enviar link',
  save: 'Salvar',
  saveAndEnter: 'Salvar e entrar',
  savePassword: 'Salvar nova senha',
  cancel: 'Cancelar',
  noAccount: 'Ainda não tem conta?',
  haveAccount: 'Já tem conta?',
  backToLogin: 'Voltar para o login',
  backToSettings: '‹ Ajustes',
  lostCurrent: 'Não lembra a senha atual?',
  endOthers: 'Encerrar as sessões nos outros aparelhos',
  settingsTitle: 'Ajustes',
  account: 'CONTA',
  sessions: 'Sessões ativas',
  thisSession: 'esta sessão',
  endSession: 'Encerrar',
  changePassword: 'Alterar senha',
  signOut: 'Sair',
  deleteAccount: 'Apagar conta',
  deleteNote: 'Apagar a conta remove do servidor as provas, o token do relógio e a conta. Não dá para desfazer.',
  deleteConfirm: 'Apagar a conta? Não dá para desfazer.',
  unverified: 'E-mail não confirmado.',
  resend: 'Reenviar confirmação',
  resent: 'Enviamos o link de novo.',
  passwordChanged: 'Senha alterada.',
  wrongCurrent: 'A senha atual não confere.',
  goToday: 'Ir para o Hoje',
  comingSoonTitle: 'Chega nos próximos módulos',
  comingSoonText: 'Esta área depende da conexão com a Garmin no servidor. Por enquanto, use o app.',
  mismatch: 'As senhas não são iguais.',
  shortPassword: 'A senha precisa de pelo menos 10 caracteres.',
} as const

export const GARMIN_TEXT = {
  section: 'GARMIN CONNECT',
  connected: 'Conectada',
  disconnected: 'Não conectada',
  connectedSince: 'Conectada em',
  connect: 'Conectar Garmin',
  disconnect: 'Desconectar',
  disconnectConfirm: 'Desconectar a Garmin? O site e o app param de receber dados novos.',
  title: 'Conectar sua conta Garmin',
  subtitle: 'Entre com o e-mail e a senha que você usa no Garmin Connect.',
  emailLabel: 'E-mail da Garmin',
  passwordLabel: 'Senha da Garmin',
  privacy: 'A senha vai para o servidor do trAIning, que entra na Garmin por você. Ela não fica guardada: guardamos só a sessão, cifrada. Desconecte quando quiser em Ajustes.',
  step1: 'Passo 1 de 2',
  step2: 'Passo 2 de 2',
  codeTitle: 'Código de verificação',
  codeText: 'A Garmin enviou um código de 6 dígitos para o e-mail da sua conta Garmin.',
  codeLabel: 'Código',
  continue: 'Continuar',
  confirm: 'Conectar',
  doneTitle: 'Garmin conectada',
  doneText: 'Vale para o site e o app. Pode fechar esta janela.',
  finish: 'Concluir',
  close: 'Fechar',
  cancel: 'Cancelar',
} as const

export const ADMIN_TEXT = {
  nav: 'Administração',
  title: 'Administração',
  subtitle: 'Convites, contas e uso do servidor.',
  accounts: 'Contas',
  of: 'de',
  pending: 'Convites pendentes',
  expiring: 'vence em 24 h',
  active: 'Ativas em 7 dias',
  activeHint: 'com sessão usada',
  garmin: 'Garmin conectada',
  requests: 'Requisições 24 h',
  errors: 'erros',
  invite: 'CONVIDAR',
  name: 'Nome',
  email: 'E-mail',
  phone: 'Celular com DDD (opcional)',
  channels: { email: 'E-mail', whatsapp: 'WhatsApp', link: 'Só o link' },
  actions: { email: 'Enviar convite por e-mail', whatsapp: 'Gerar mensagem para o WhatsApp', link: 'Gerar link' },
  inviteHint: 'O link vale por 7 dias e serve para uma conta só. Convidados entram pelo site.',
  mailed: 'Convite enviado para',
  whatsappReady: 'Mensagem pronta. Abra o WhatsApp e envie.',
  linkReady: 'Link criado. Copie e mande como quiser.',
  copy: 'Copiar link',
  copied: 'Link copiado.',
  copyMessage: 'Copiar mensagem',
  openWhatsapp: 'Abrir no WhatsApp',
  invites: 'CONVITES',
  noInvites: 'Nenhum convite ainda.',
  statuses: { pending: 'pendente', accepted: 'aceito', expired: 'vencido', canceled: 'cancelado' },
  cancel: 'Cancelar',
  renew: 'Gerar de novo',
  resend: 'Reenviar',
  users: 'CONTAS',
  role: { member: 'Membro', guest: 'Convidado' },
  adminRole: 'Administrador',
  access: { member: 'app e site', guest: 'só site' },
  garminOn: 'Conectada',
  garminOff: 'não conectou',
  never: 'nunca',
  remove: 'Remover',
  removeConfirm: 'Remover a conta e todos os dados dela? Não dá para desfazer.',
  usage: 'REQUISIÇÕES POR HORA · 24 H',
  database: 'banco',
  columns: { name: 'Nome', channel: 'Canal', status: 'Situação', role: 'Papel', access: 'Acesso', garmin: 'Garmin', lastSeen: 'Último uso', data: 'Dados' },
} as const

export const INVITE_TEXT = {
  eyebrow: 'CONVITE',
  title: (inviter: string) => `${inviter} te convidou para o trAIning.`,
  fallbackInviter: 'Você foi convidado',
  pitch: 'Conecte a sua Garmin e veja a prontidão do dia, a análise de cada treino, a previsão das suas provas e a sua evolução.',
  validUntil: (date: string) => `Convite válido até ${date}, para uma conta.`,
  formTitle: 'Criar sua conta',
  formSubtitle: 'Depois você conecta a Garmin em Ajustes.',
  webOnly: 'Por enquanto, quem entra por convite usa o trAIning pelo site, em qualquer navegador. O app para iPhone e iPad vem depois.',
  invalidTitle: 'Este convite não vale mais',
  invalidText: 'Ele venceu, foi cancelado ou já foi usado. Peça um novo a quem te convidou.',
  loading: 'Abrindo o convite…',
} as const

export const FORMAT_TEXT = {
  hard: 'Pode treinar forte',
  moderate: 'Treino moderado',
  rest: 'Dia de descanso',
} as const

export const READINESS_LEVELS: Record<string, string> = {
  PRIME: 'No auge, pode forte',
  HIGH: 'Pode treinar forte',
  MODERATE: 'Treino moderado',
  LOW: 'Pegue leve hoje',
  POOR: 'Dia de descanso',
}

export const DATA_TEXT = {
  readiness: 'PRONTIDÃO',
  readinessSource: 'Nota da Garmin. A nossa nota chega no próximo módulo.',
  noReadiness: 'Sem prontidão de hoje ainda. Ela chega depois que o relógio sincroniza o sono.',
  recovery: (hours: number) => `Pronto para treino forte em ${hours} h`,
  recovered: 'Recuperado para treino forte',
  hrv: 'HRV da noite',
  sleep: 'Sono',
  battery: 'Body Battery ao acordar',
  resting: 'FC de repouso',
  week: 'SEMANA',
  weekTotal: (value: string) => `${value} na semana`,
  lastRun: 'ÚLTIMA CORRIDA',
  noRuns: 'Nenhuma corrida nos últimos dias.',
  open: 'Abrir',
  syncing: (days: number) => `Sincronizando a Garmin… ${days} dias`,
  synced: (time: string) => `Sincronizado às ${time}`,
  syncError: 'Não sincronizou. Tente de novo em instantes.',
  disconnected: 'Garmin não conectada',
  connect: 'Conectar em Ajustes',
  firstSync: 'Primeira sincronização: trazendo até 180 dias de dados. Pode levar alguns minutos.',
  workoutsTitle: 'Treinos',
  noActivities: 'Nenhuma atividade sincronizada ainda.',
  loadMore: 'Carregar mais',
  distance: 'Distância',
  time: 'Tempo',
  pace: 'Pace',
  heartRate: 'FC média',
  maxHeartRate: 'FC máx.',
  elevation: 'Subida',
  load: 'Carga',
  effect: 'Efeito aeróbico',
  vo2: 'VO2 máx.',
  fastestKm: 'Km mais rápido',
  zones: 'TEMPO EM CADA ZONA',
  pickOne: 'Escolha um treino na lista.',
  analysisSoon: 'A análise bloco a bloco, com o arquivo FIT, chega no módulo de análise de treino.',
} as const

export const VERDICTS = { hard: 'Pode treinar forte', moderate: 'Treino moderado', rest: 'Dia de descanso' } as const

export const FACTOR_NAMES = { hrv: 'HRV', sleep: 'Sono', bodyBattery: 'Body Battery', load: 'Carga' } as const

export const TODAY_TEXT = {
  normal: (value: number) => `Seu normal: ${value}`,
  noHistory: 'O normal aparece com 14 dias de histórico.',
  garmin: (value: number) => `Garmin: ${value}`,
  missing: 'sem dado',
  below: 'abaixo do normal',
  above: 'acima do normal',
  load: 'Carga 7 d / 28 d',
  form: 'Forma',
  fitness: 'Condicionamento',
  fatigue: 'Fadiga',
  focus: 'FOCO DA CARGA · 28 DIAS',
  focusParts: { lowAerobic: 'Aeróbico leve', highAerobic: 'Aeróbico forte', anaerobic: 'Anaeróbico' },
  lastWeek: (value: string) => `semana passada ${value}`,
  average: (value: string) => `média de 4 semanas ${value}`,
} as const

export const WHATSAPP_URL = 'https://wa.me/'
export const BRAZIL_PREFIX = '55'

export const ERRORS: Record<string, string> = {
  invite_required: 'O cadastro é só por convite. Peça um convite a quem te indicou o trAIning.',
  invalid_invite: 'Este convite venceu, foi cancelado ou já foi usado.',
  web_only: 'Contas de convidado entram só pelo site, por enquanto.',
  forbidden: 'Só a conta de administrador acessa esta área.',
  invalid_channel: 'Escolha como enviar o convite.',
  cannot_remove_admin: 'A conta de administrador não pode ser removida.',
  garmin_invalid_credentials: 'E-mail ou senha da Garmin incorretos.',
  garmin_invalid_code: 'Código incorreto. Confira e tente de novo.',
  garmin_login_expired: 'O código venceu. Entre de novo para receber outro.',
  garmin_rate_limited: 'A Garmin bloqueou tentativas seguidas. Espere alguns minutos.',
  garmin_unavailable: 'A Garmin não respondeu. Tente de novo mais tarde.',
  storage_unavailable: 'A conexão com a Garmin ainda não está disponível no servidor.',
  invalid_credentials: 'E-mail ou senha incorretos.',
  email_taken: 'Já existe uma conta com esse e-mail. Entre com ela.',
  invalid_email: 'Confira o e-mail.',
  invalid_name: 'Informe seu nome.',
  invalid_password: 'A senha precisa de pelo menos 10 caracteres.',
  invalid_token: 'O link venceu ou já foi usado. Peça outro.',
  rate_limited: 'Muitas tentativas. Espere alguns minutos.',
  mail_unavailable: 'O envio de e-mail não está disponível agora.',
  network: 'Não conectou ao servidor. Confira a internet.',
  unknown: 'Não deu certo. Tente de novo.',
}

export const PAGE_TITLES: Partial<Record<Route, string>> = {
  today: 'Hoje',
  workouts: 'Treinos',
  races: 'Provas',
  evolution: 'Evolução',
}

export const EVOLUTION_PERIODS = [
  { days: 42, label: '6 semanas', span: 'em 6 semanas' },
  { days: 91, label: '3 meses', span: 'em 3 meses' },
  { days: 182, label: '6 meses', span: 'em 6 meses' },
  { days: 365, label: '1 ano', span: 'em 1 ano' },
] as const

export const DEFAULT_EVOLUTION_PERIOD = 91

export const STABLE_FRACTION = 0.01

export const BETTER_WHEN_LOWER = ['restingHeartRate', 'predictionHalf', 'prediction5k', 'prediction10k', 'predictionFull']

export const ZONE_COLORS = ['#7fb2ff', '#c8f05a', '#e8c547', '#ff8a4c', '#e5534b']

export const LOW_ZONE_COUNT = 2

export const ZONE_WEEKS = 6

export const EVOLUTION_TEXT = {
  title: 'Evolução',
  period: 'Período',
  improving: 'Em evolução',
  declining: 'Perdendo ritmo',
  steady: 'Estável',
  rose: 'subiu',
  fell: 'caiu',
  kept: 'ficou estável',
  halfPrediction: 'previsão da meia',
  better: (names: string) => `, com ${names} melhores`,
  and: ' e ',
  noReading: 'A leitura aparece quando houver corridas suficientes para prever a meia.',
  loading: 'Carregando a evolução…',
  error: 'Não deu para carregar a evolução agora.',
  tiles: {
    predictionHalf: 'Previsão 21 km',
    vo2max: 'VO2 máx.',
    fitness: 'Condicionamento',
    monthlyVolume: 'Volume em 30 dias',
    hrv: 'HRV da noite',
  },
  readingNames: { vo2max: 'VO2', fitness: 'condicionamento', hrv: 'HRV', restingHeartRate: 'FC de repouso' },
  form: 'FORMA E FADIGA · MÉDIA 7 DIAS',
  fitnessLegend: 'condicionamento',
  fatigueLegend: 'fadiga',
  today: 'hoje',
  formToday: (fitness: number, fatigue: number, form: number) => `Hoje: condicionamento ${fitness}, fadiga ${fatigue}, forma ${form}.`,
  formReading: (form: number) => (form >= 0 ? 'Forma positiva: o corpo absorveu a carga recente.' : 'Forma negativa: a carga recente ainda pesa.'),
  weekly: 'KM POR SEMANA',
  thisWeek: 'esta semana',
  zones: (weeks: number) => `TEMPO EM CADA ZONA · ${weeks} SEMANAS`,
  zoneSplit: (easy: number) => `${easy}% fácil, ${100 - easy}% forte`,
  records: 'RECORDES E PREVISÕES',
  recordsColumns: ['Distância', 'Melhor em 12 meses', 'Quando', 'Previsão hoje'],
  longestRun: 'Corrida mais longa',
  biggestWeek: 'Maior semana',
  weekOf: (day: string) => `semana de ${day}`,
  noData: 'Sem dados no período.',
} as const
