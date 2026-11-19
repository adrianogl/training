export interface MailContent {
  subject: string
  text: string
  html: string
}

export interface MailLayout {
  preheader: string
  eyebrow: string
  title: string
  intro?: string
  card?: string
  button: { label: string; href: string }
  linkLine?: string
  footer: string
  showHost: boolean
}

export interface InviteMailInput {
  name: string
  inviter: string
  link: string
  message: string
}

export interface GarminCatalogChange {
  id: string
  name: string | null
}

export interface GarminCatalogDiff {
  added: GarminCatalogChange[]
  removed: (GarminCatalogChange & { referenced: boolean })[]
  renamed: { id: string; from: string | null; to: string | null }[]
}

export interface GarminCatalogMailInput {
  diff: GarminCatalogDiff
  checkedOn: string
}

export interface InviteRequestMailInput {
  name: string
  email: string
  watch: string
  message: string
  link: string
}
