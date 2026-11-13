# Servidor de sincronização

API da sincronização entre aparelhos do trAIning: Vercel Functions (Node 22) com Postgres no Neon. Guarda só `id`, `updatedAt`, a marca de apagado e o payload cifrado no aparelho. Spec: `tasks/sync-servidor-spec.md`.

## Variáveis de ambiente

| Nome | Uso |
| --- | --- |
| `DATABASE_URL` | Connection string do Neon. Usada pelas funções e pelo `npm run migrate`. |
| `ADMIN_TOKEN` | Token do painel `/admin`, com 32 caracteres ou mais. Ausente ou mais curto, o painel responde 503. |
| `MAX_ACCOUNTS` | Limite total de contas (padrão 3). Acima dele, `POST /api/v1/account` responde 429 `rate_limited`. |
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

Todas exigem `Authorization: Bearer <32 bytes em base64url sem padding>`. A conta é o `sha256` desses bytes.

| Rota | Resposta |
| --- | --- |
| `POST /api/v1/account` | 201 `{"created":true}`, 200 `{"created":false}`, 429 depois de 10 contas novas por IP em uma hora ou com `MAX_ACCOUNTS` atingido |
| `DELETE /api/v1/account` | 204; 401 se a conta não existe |
| `GET /api/v1/changes?since=<seq>` | `{"records":[...],"cursor":n,"hasMore":bool}`, em ordem de `seq`, até 500 registros e 3 MB de payload por página (sempre pelo menos 1) |
| `POST /api/v1/changes` | `{"cursor":n,"ignored":[{"kind","id"}]}`; até 100 registros, payload até 1 MB, corpo até 4 MB; 413 `quota_exceeded` acima de `MAX_ACCOUNT_BYTES` (push que não aumenta o uso, como tombstone, sempre passa) |

Erros voltam como `{"error":"<código>"}`.

A criação de conta roda numa transação com advisory lock global: o limite por IP e o `MAX_ACCOUNTS` são checados e gravados sem corrida.

O push roda numa transação que começa com `pg_advisory_xact_lock(hashtext(account_id))`. Pushes da mesma conta ficam em série, então os `seq` de uma conta aparecem na ordem do commit e o pull nunca passa o cursor por cima de um `seq` menor ainda não commitado.

## Painel

`/admin` (rewrite para `/api/admin` no `vercel.json`) mostra status e latência do banco, contas, registros por tipo e apagados, última escrita e `seq`, erros e requisições por hora nas últimas 24 h e as 20 requisições mais recentes. Aceita `Authorization: Bearer <ADMIN_TOKEN>` ou o formulário da própria página, que grava um cookie de sessão `HttpOnly` com o horário de emissão e um HMAC do token. O servidor recusa cookie com mais de 7 dias, e trocar o token derruba as sessões.

Cada request autenticado das rotas v1 grava uma linha em `request_log` (401 e 429 não gravam): método, rota, status, contagem de registros e os 8 primeiros caracteres da conta. Payload, Bearer e IP não entram. Linhas com mais de 7 dias são apagadas na gravação seguinte.

## Deploy

`.vercelignore` envia só `api/`, `src/`, `public/`, `package.json`, `package-lock.json`, `tsconfig.json` e `vercel.json`. O `vercel.json` fixa `framework: null` e `outputDirectory: "public"`, que tem só um `robots.txt` (`Disallow: /`). Sem isso, o preset "Other" serve a raiz do projeto como arquivo estático.

Depois de cada deploy de preview:

```
curl -i https://<preview>/package.json    # esperado: 404
curl -i https://<preview>/src/db.ts       # esperado: 404
```
