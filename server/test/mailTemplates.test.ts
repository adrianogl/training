import { describe, expect, it, vi } from 'vitest'
import { resendMailer } from '../src/mailer.js'
import { inviteMail, inviteRequestMail, resetPasswordMail, verifyEmailMail } from '../src/mailTemplates.js'

const link = 'https://training.aglv.dev/x?token=abc'
const invite = { name: 'Marina', inviter: 'Adriano', link, message: `Oi, Marina! Adriano te convidou.\n${link}` }
const request = { name: 'Marina', email: 'marina@exemplo.com', watch: 'Garmin', message: 'Quero testar', link }

const cases = [
  ['confirmar e-mail', verifyEmailMail(link), 'Confirmar e-mail'],
  ['redefinir senha', resetPasswordMail(link), 'Criar senha nova'],
  ['convite', inviteMail(invite), 'Criar minha conta'],
  ['pedido de convite', inviteRequestMail(request), 'Ver no app'],
] as const

describe('templates de e-mail', () => {
  it.each(cases)('%s tem subject, text e html com link e botão', (_name, mail, button) => {
    expect(mail.subject).not.toBe('')
    expect(mail.text).toContain(link)
    expect(mail.html).toContain(`href="${link}"`)
    expect(mail.html).toContain(`>${button}</a>`)
    expect(mail.html).toContain('name="color-scheme" content="dark"')
    expect(mail.html).toContain('border-radius:10px')
  })

  it('escapa HTML vindo do usuário', () => {
    const xss = '<script>alert(1)</script>'
    const mails = [inviteMail({ ...invite, name: xss, inviter: xss }), inviteRequestMail({ ...request, name: xss, email: xss, watch: xss, message: xss })]
    for (const mail of mails) {
      expect(mail.html).not.toContain('<script>')
      expect(mail.html).toContain('&lt;script&gt;')
    }
  })

  it('pedido sem mensagem mostra "Sem mensagem."', () => {
    const mail = inviteRequestMail({ ...request, message: '' })
    expect(mail.html).toContain('Sem mensagem.')
    expect(mail.text).toContain('Sem mensagem.')
  })
})

describe('resendMailer', () => {
  it('envia text e html', async () => {
    const fetcher = vi.fn(async () => new Response('{}', { status: 200 }))
    await resendMailer('key', 'a@b.c', fetcher as unknown as typeof fetch).send({ to: 'x@y.z', subject: 's', text: 't', html: '<p>h</p>' })
    const call = fetcher.mock.calls[0] as unknown as [string, { body: string }]
    expect(JSON.parse(call[1].body)).toMatchObject({ text: 't', html: '<p>h</p>' })
  })
})
