import { RESEND_URL } from './constants.js'
import type { Mail, Mailer } from './types.js'

export function resendMailer(apiKey: string, from: string, fetcher: typeof fetch = fetch): Mailer {
  return {
    async send(mail: Mail) {
      const response = await fetcher(RESEND_URL, {
        method: 'POST',
        headers: { authorization: `Bearer ${apiKey}`, 'content-type': 'application/json' },
        body: JSON.stringify({ from, to: [mail.to], subject: mail.subject, text: mail.text, html: mail.html }),
      })
      if (!response.ok) {
        throw new Error(`mail_failed_${response.status}`)
      }
    },
  }
}

export function mailerFromEnv(env: Record<string, string | undefined>): Mailer | undefined {
  const apiKey = env.RESEND_API_KEY
  const from = env.MAIL_FROM
  if (apiKey === undefined || apiKey === '' || from === undefined || from === '') {
    return undefined
  }
  return resendMailer(apiKey, from)
}
