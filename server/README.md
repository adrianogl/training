# Servidor de sincronização

API da sincronização entre aparelhos do trAIning: Vercel Functions (Node 22) com Postgres no Neon. Guarda só `id`, `updatedAt`, a marca de apagado e o payload cifrado no aparelho. Spec: `tasks/sync-servidor-spec.md`.

## Variáveis de ambiente

| Nome | Uso |
| --- | --- |
| `DATABASE_URL` | Connection string do Neon. Usada pelas funções e pelo `npm run migrate`. |
| `ADMIN_EMAILS` | E-mails das contas de administrador, separados por vírgula. Eles podem criar conta sem convite e veem Ajustes › Convites no app. |
| `MAX_ACCOUNTS` | Limite total de contas (padrão 3; em produção, 20). Acima dele, `POST /api/v1/account` responde 429 `rate_limited`. |
| `RESEND_API_KEY` | Chave do Resend para os e-mails de confirmação e recuperação de senha. Sem ela, confirmar e recuperar respondem 503 `mail_unavailable`. |
| `MAIL_FROM` | Remetente dos e-mails, de um domínio verificado no Resend. |
| `APP_URL` | Base dos links dos e-mails (`/convite`, `/confirmar`, `/redefinir-senha`). Esses caminhos abrem `landing/link.html`, que leva ao app pelo esquema `training://`. |
| `DATA_KEY` | Chave de 32 bytes em base64url que cifra a sessão da Garmin (e os dados de saúde, nos próximos módulos). Gerar com `node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"`. Sem ela, as rotas da Garmin respondem 503. Trocar a chave invalida o que já foi cifrado. |
| `MAX_ACCOUNT_BYTES` | Cota de payload por conta em bytes (padrão 52428800, 50 MB). Push que passa da cota responde 413 `quota_exceeded` e não grava nada. |

## Comandos

```
npm --prefix server ci
npm --prefix server test          # Vitest contra PGlite, sem rede
npm --prefix server run typecheck
npm --prefix server run test:concurrency   # push concorrente em Postgres 17 real (Docker, imagem postgres:17-alpine já baixada)
DATABASE_URL=... npm --prefix server run migrate
```

## Rotas

Todas exigem `Authorization: Bearer <32 bytes em base64url sem padding>`. A conta é o `sha256` desses bytes. As rotas de conta usam a chave de conta; só o `GET /api/v1/watch/readiness` usa o token do relógio.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/account` | 201 `{"created":true}`, 200 `{"created":false}`, 429 depois de 10 contas novas por IP em uma hora ou com `MAX_ACCOUNTS` atingido |
| `DELETE /api/v1/account` | 204; 401 se a conta não existe |
| `GET /api/v1/changes?since=<seq>` | `{"records":[...],"cursor":n,"hasMore":bool}`, em ordem de `seq`, até 500 registros e 3 MB de payload por página (sempre pelo menos 1) |
| `POST /api/v1/changes` | `{"cursor":n,"ignored":[{"kind","id"}]}`; até 100 registros, payload até 1 MB, corpo até 4 MB; 413 `quota_exceeded` acima de `MAX_ACCOUNT_BYTES` (push que não aumenta o uso, como tombstone, sempre passa) |
| `PUT /api/v1/watch/token` | Corpo `{"tokenHash":"<sha256 hex minúsculo dos 32 bytes do token do relógio>"}`. 204; troca o token anterior da conta (um por conta). 400 `invalid_token_hash`, 409 `token_conflict` se o hash já é de outra conta |
| `DELETE /api/v1/watch/token` | 204, com ou sem token cadastrado |
| `PUT /api/v1/watch/readiness` | Corpo `{"day":"YYYY-MM-DD","score":63,"verdict":"Moderado"}`. 204; upsert da nota da conta. 400 `invalid_day`, `invalid_score` (inteiro 0–100) ou `invalid_verdict` (1 a 24 caracteres) |
| `GET /api/v1/watch/readiness` | `Authorization: Bearer <token do relógio>`. 200 `{"day","score","verdict"}`, 404 `no_readiness` sem nota, 401 token desconhecido ou chave de conta. Sempre `Cache-Control: no-store` |

Erros voltam como `{"error":"<código>"}`.

A criação de conta roda numa transação com advisory lock global: o limite por IP e o `MAX_ACCOUNTS` são checados e gravados sem corrida.

O token do relógio tem o mesmo formato da chave de conta e o servidor guarda só o `sha256` dele em `watch_tokens`. A troca roda numa transação com `pg_advisory_xact_lock(hashtext('watch_token:' || account_id))`, então duas trocas simultâneas deixam um token só. O `GET` do relógio, chamado a cada 15 minutos, resolve token, nota e `request_log` numa única query. Apagar a conta apaga token e nota em cascata.

O push roda numa transação que começa com `pg_advisory_xact_lock(hashtext(account_id))`. Pushes da mesma conta ficam em série, então os `seq` de uma conta aparecem na ordem do commit e o pull nunca passa o cursor por cima de um `seq` menor ainda não commitado.

## Log de requisições

Cada request autenticado das rotas v1 grava uma linha em `request_log` (401 e 429 não gravam): método, rota, status, contagem de registros e os 8 primeiros caracteres da conta. Payload, Bearer e IP não entram. Linhas com mais de 7 dias são apagadas na gravação seguinte.

## Deploy

`.vercelignore` envia só `api/`, `src/`, `public/`, `landing/`, `migrations/`, `scripts/`, `package.json`, `package-lock.json`, `tsconfig.json` e `vercel.json`. O `vercel.json` fixa `framework: null` e `outputDirectory: "public"`, que recebe a landing (`landing/`) no build, incluindo `link.html` para os links dos e-mails. Sem isso, o preset "Other" serve a raiz do projeto como arquivo estático.

Depois de cada deploy de preview:

```
curl -i https://<preview>/package.json    # esperado: 404
curl -i https://<preview>/src/db.ts       # esperado: 404
```

## Conta (e-mail e senha)

Spec: `tasks/conta-spec.md`. O token de sessão tem o formato da chave de conta (32 bytes base64url) e vale em todas as rotas de conta, sync e relógio. A chave antiga continua aceita até o app migrar. Sessão expira após 90 dias sem uso.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/auth/signup` | Corpo `{"name","email","password","device","legacyKey"?}`. 201 `{"token","user"}`; 409 `email_taken` ou `legacy_unavailable`; 400 `invalid_*`; 429 com `MAX_ACCOUNTS` atingido |
| `POST /api/v1/auth/login` | Corpo `{"email","password","device"}`. 200 `{"token","user"}`; 401 `invalid_credentials`; 429 depois de 10 tentativas erradas por IP em 15 min |
| `POST /api/v1/auth/logout` | 204 |
| `GET`/`PATCH /api/v1/auth/me` | 200 `{"user"}`; o `PATCH` troca o `name` |
| `POST /api/v1/auth/password` | Corpo `{"current","next","endOtherSessions"?}`. 204; 401 `invalid_credentials` |
| `POST /api/v1/auth/forgot` | Corpo `{"email"}`. Sempre 204; só envia para conta confirmada |
| `POST /api/v1/auth/reset` | Corpo `{"token","password"}`. 204 e encerra as sessões; 400 `invalid_token` |
| `POST /api/v1/auth/verify` | Corpo `{"token"}`. 204; 400 `invalid_token` |
| `POST /api/v1/auth/resend-verification` | 204; 503 `mail_unavailable` |
| `GET`/`DELETE /api/v1/auth/sessions` | Lista as sessões; `DELETE ?id=` encerra uma |

## Provas e metas

As provas, as metas e as decisões de resultado ficam na tabela `records`, no mesmo protocolo de sync. Registros com `"format":"plain"` chegam em JSON e o servidor cifra com `DATA_KEY` antes de gravar; no pull eles voltam decifrados com `format`. Registros sem `format` são os antigos, cifrados no aparelho, e passam intactos. Com o mesmo `updatedAt`, `plain` substitui o antigo, para o reenvio do app atualizado valer. Previsão, estratégia e análise são calculadas só no app.

## Pedido de convite

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/invite-requests` | Pública. Corpo `{"name","email","watch":"garmin"|"apple"|"other"|"none","message"}`. 202; cifra e guarda o pedido e avisa os `ADMIN_EMAILS` por e-mail. 400 `invalid_name`, `invalid_email`, `invalid_watch`, `invalid_message`; 429 com mais de 3 pedidos por hora do mesmo IP ou 100 pendentes. O campo `website` é isca para robô: preenchido, responde 202 sem guardar |
| `POST /api/v1/admin/invite-requests/action` | Administrador. `{"id","action":"invite"|"decline"}`. Convidar cria o convite com nome e e-mail do pedido e envia como os outros convites |

Os pedidos pendentes aparecem em `GET /api/v1/admin/overview`, no campo `requests`.

## Garmin

O login é o mesmo do app (SSO mobile da Garmin, com código por e-mail quando a conta pede). Entre o login e o código, os cookies do SSO ficam cifrados em `garmin_pending_logins` por 10 minutos. A sessão fica cifrada (AES-256-GCM com `DATA_KEY`) em `garmin_connections` e é renovada quando faltam menos de 15 minutos para vencer. A senha da Garmin não é guardada.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/garmin/connect` | Corpo `{"email","password"}`. 200 `{"status":"connected"}` ou `{"status":"needs_code","method"}`; 400 `garmin_invalid_credentials`; 429 `garmin_rate_limited`; 502 `garmin_unavailable` |
| `POST /api/v1/garmin/verify` | Corpo `{"code"}`. 200 `{"status":"connected"}`; 400 `garmin_invalid_code`; 409 `garmin_login_expired` |
| `GET`/`DELETE /api/v1/garmin/status` | `{"connected","connectedAt"}`; `DELETE` desconecta |
| `GET /api/v1/garmin/session` | A sessão da Garmin para o app (`accessToken`, `refreshToken`, `clientId`, `expiresAt`); 404 `garmin_not_connected` |

## Convites e administração

O cadastro é só por convite. Criam conta sem convite apenas os e-mails de `ADMIN_EMAILS` e quem envia a chave antiga de sync (`legacyKey`). Quem entra por convite vira `guest` e usa o app normalmente. O app instala só pelo Mac do administrador (conta Apple gratuita), então convite só faz sentido para quem tiver o app no aparelho.

| Rota | Resposta |
| --- | --- |
| `GET /api/v1/admin/overview` | Métricas, contas e convites. Só administrador (403 `forbidden` para os outros) |
| `POST /api/v1/admin/invites` | Corpo `{"name","channel":"email"|"whatsapp"|"link","email"?}`. 200 `{"invite","link","message","mailed"}`; o canal e-mail envia pelo Resend |
| `POST /api/v1/admin/invites/action` | Corpo `{"id","action":"cancel"|"renew"}` |
| `DELETE /api/v1/admin/users?id=` | Remove a conta de um convidado e os dados dela; 409 para administrador |
| `GET /api/v1/invites/preview?c=` | Nome, e-mail e quem convidou, para a tela de convite do app; 404 `invalid_invite` |

O convite vale 7 dias e uma conta. `POST /api/v1/auth/signup` aceita `inviteToken`; sem ele, responde 403 `invite_required`.

## MCP

O endpoint `/mcp` serve o Claude Desktop e o Claude Code com o token gerado em Ajustes › Claude. As ferramentas de força são `contexto_forca`, `validar_treinos` e `salvar_treinos`. Só para contas administradoras, `avaliacoes_imagens` lista as avaliações "Não corresponde" das imagens dos exercícios e `resolver_avaliacao` registra a resolução, com a nota do que mudou.
