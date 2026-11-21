export interface ContextExercise {
  id: string
  nome?: string
  padrao: string
  equipamento: string
  regioes: string[]
  focos: string[]
  unilateral: boolean
  isometria: boolean
}

export interface StrengthContext {
  periodo: { inicio: string; fim: string; hoje: string }
  prova?: { nome: string; dia: string } | null
  dias_do_treinador: { dia_da_semana: string; foco: string; intensidade: string; minutos: number; local: string }[]
  mfit: { dia_da_semana: string; padroes: string[] }[]
  corrida: { dia: string; tipo: string; nome: string }[]
  prontidao: { dia: string; nota: number }[]
  dor: string[]
  equipamento_casa?: string[]
  ultimas_cargas_kg: Record<string, number>
  observacoes?: Record<string, string[]>
  catalogo_formato?: string
  catalogo: (ContextExercise | string)[]
  regras: string[]
}

export interface ResponseExercise {
  id: string
  series: number
  reps?: number
  segundos?: number
  descanso?: number
  kg?: number
}

export interface ResponseDay {
  dia: string
  foco?: string
  minutos?: number
  local?: string
  porque?: string
  substitui_mfit?: boolean
  exercicios: ResponseExercise[]
}

export interface StrengthResponse {
  versao: number
  autor?: string
  resumo?: string
  treinos: ResponseDay[]
}

export interface DayReport {
  dia: string
  erros: string[]
  avisos: string[]
  minutos_estimados: number | null
}
