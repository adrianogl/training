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

export interface InviteRequestMailInput {
  name: string
  email: string
  watch: string
  message: string
  link: string
}
