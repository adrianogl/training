import { it } from 'vitest'
import { mkdirSync, writeFileSync } from 'node:fs'
import { inviteMail, inviteRequestMail, resetPasswordMail, verifyEmailMail } from '../src/mailTemplates.js'

const OUTPUT_DIR = new URL('../.email-preview/', import.meta.url)
const BASE = 'https://training.aglv.dev'

const previews = {
  'confirmar-email': verifyEmailMail(`${BASE}/app/confirmar?token=exemplo`),
  'redefinir-senha': resetPasswordMail(`${BASE}/redefinir-senha?token=exemplo`),
  convite: inviteMail({
    name: 'Marina',
    inviter: 'Adriano',
    link: `${BASE}/convite?c=exemplo`,
    message: 'Oi, Marina! Adriano te convidou.',
  }),
  'pedido-de-convite': inviteRequestMail({
    name: 'Marina Souza',
    email: 'marina@exemplo.com',
    watch: 'Forerunner 265',
    message: 'Corro com um grupo de BH e queria testar antes da meia de março.',
    link: `${BASE}/administracao`,
  }),
}

it('grava os previews', () => {
  mkdirSync(OUTPUT_DIR, { recursive: true })
  for (const [name, mail] of Object.entries(previews)) {
    writeFileSync(new URL(`${name}.html`, OUTPUT_DIR), mail.html)
  }
})
