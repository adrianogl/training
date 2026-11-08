# trAIning — App, pós-treino (plano 2) — Design

Data: 2026-11-08. Complementa a spec principal `docs/superpowers/specs/2026-11-07-training-design.md`, que continua valendo para identidade visual, plataforma, métricas, sync e Keychain. Onde este documento diverge, vale este. Pendências herdadas do núcleo: `docs/superpowers/plans/2026-11-08-pendencias-plano-2.md`.

## Por que

O uso principal do app é logo depois de cada treino: o Adriano abre para ver como o treino foi, o que deu certo, o que deu errado, se cumpriu a prescrição e se está evoluindo em relação às vezes anteriores. E quer compartilhar o treino nas redes com uma imagem bonita.

Os treinos são prescritos no app **Treinus**, que cadastra o treino estruturado no Garmin Connect. O relógio executa passo a passo, e o `.FIT` traz a prescrição completa. Por isso a leitura do treino segue os **blocos da prescrição**, não o km a km.

## Divisão do trabalho

- **Plano 2 (este):** fundação do app, leitura da prescrição, lista e tela do treino, compartilhar, textos com Foundation Models.
- **Plano 3:** Hoje, Evolução, Detalhe de métrica, Provas, sync em background (`BGAppRefreshTask`).
- **Plano 4:** README e landing page (antes era o plano 3).

## Objetivos

1. Abrir o app no simulador com os dados reais do Adriano desde a primeira tarefa e manter o simulador aberto durante todo o desenvolvimento, para ele acompanhar o app tomando forma.
2. Ler do `.FIT` a prescrição do Treinus (passos, alvos, repetições) e o que foi executado em cada passo.
3. Tela do treino com: resumo, positivos / negativos / atenção, blocos contra o prescrito, km a km como detalhe, mapa, zonas, comparação com o mesmo treino feito antes.
4. Compartilhar o treino como imagem, com editor de modelo e toggles.
5. Textos gerados no aparelho com Foundation Models a partir de fatos calculados, com fallback por template.

## Não objetivos

- Telas Hoje, Evolução, Detalhe de métrica, Provas (plano 3).
- Sync em background (plano 3). No plano 2 o sync roda ao abrir o app e pelo botão em Ajustes.
- Criar ou editar treino, mandar treino para o relógio, integrar com a API do Treinus.
- Natação e força ganham só a lista e um resumo simples (tempo, FC, carga); a tela rica é para corrida.
- Tema claro.

## Anti-objetivos

- Texto que inventa fato. Todo ponto positivo, negativo ou de atenção vem de uma regra calculada no código; o modelo só redige.
- Tela vazia ou com "—" demais num treino real. Se não há prescrição, a tela cai para o modo sem prescrição (abaixo), nunca fica sem blocos.
- Imagem compartilhada sem a logo.

## O que o `.FIT` traz (verificado num treino real)

Treino de 03/11/2026, "Corrida Limiar Anaeróbio Fracio", do Treinus:

- Mensagem `workout`: `wkt_name` (nome do Treinus) e `wkt_description` (texto do Treinus, truncado pelo tamanho do campo).
- Mensagens `workout_step` (4): `message_index`, `intensity` (warmup / active / recovery / cooldown), `duration_type` (distance / time / ...), `duration_distance` ou `duration_time`, `target_type` (speed / heart_rate / open / ...), e para `speed` os limites `custom_target_speed_low/high` em m/s.
- Mensagens `lap` (15): o relógio fecha volta automática a cada 1 km dentro de cada passo; cada volta tem `wkt_step_index` ligando ao passo, `intensity`, `lap_trigger`, tempo, distância, velocidade e FC média/máx. A última volta (`session_end`, ~2 s) não tem passo.
- Exemplo real: aquecimento 3 km a 5:30–5:11/km → feito 5:21/5:20/5:17; bloco 7 km a 4:15–4:01 → 4:07–4:12; recuperação 4 min sem alvo → 145 m; bloco 3 km a 4:15–4:01 → 4:07–4:12. FC do bloco de 7 km subiu de 155 para 169 com pace estável.

Ainda não verificado num arquivo real: passo de repetição (`repeat_until_steps_cmplt`, ex. 6×800 com recuperação), alvo por FC (`heart_rate` com zona ou bpm custom) e treino sem prescrição. O builder deve tratar os três pelo FIT SDK e cobrir com fixture sintética; quando aparecer um real, conferir.

## Modelo de blocos

- **Bloco = um passo executado da prescrição.** Num passo de repetição, cada repetição gera os seus blocos (Tiro 1, Recuperação 1, Tiro 2...). O bloco agrega as voltas com o mesmo `wkt_step_index` na ordem em que aconteceram.
- Para cada bloco: tipo (aquecimento / ativo / recuperação / desaquecimento), prescrito (duração ou distância + alvo), feito (tempo, distância, pace médio, FC média/máx, zona de FC predominante), voltas internas (km a km dentro do bloco), e status contra o alvo: dentro / acima / abaixo / sem alvo / incompleto.
- **Dentro do alvo** = pace médio do bloco dentro da faixa prescrita (limites inclusivos). Para alvo de FC, a FC média dentro da faixa. Tolerância exata fica para o plano, calibrada com os treinos reais.
- **Sem prescrição** (corrida livre): blocos = voltas do relógio; se só houver auto-lap, km a km. A seção chama "Parciais" em vez de "Blocos × prescrito" e não mostra status de alvo.

## Positivos, negativos, atenção

Três grupos separados. Cada item é uma regra calculada com o fato concreto (número, bloco, comparação). Grupo sem item mostra "nenhum".

- **Positivos:** bloco dentro da faixa; pace constante entre as voltas de um bloco; FC menor que nas vezes anteriores do mesmo treino no mesmo pace; boa queda de FC na recuperação.
- **Negativos:** bloco fora da faixa, inclusive mais rápido que o prescrito; passo não completado; queda de pace no fim de um bloco.
- **Atenção:** desacoplamento (FC sobe com pace estável dentro de um bloco ativo); FC numa zona acima do que o alvo implica; treino forte em dia de prontidão baixa; A:C alto.

Os limites numéricos (quantos s/km contam como "constante", quantos % de subida de FC contam como desacoplamento, o que é "boa queda" na recuperação) ficam para o plano, com valor inicial razoável e calibração nos treinos reais.

## Comparação com treinos parecidos

- **Com prescrição:** treinos anteriores com o mesmo `wkt_name`. Compara bloco a bloco (pace, FC, status) e o total. Mostra até 4 ocorrências mais recentes e uma frase de evolução.
- **Sem prescrição:** spec principal (mesmo tipo e distância ±20%, últimos 90 dias).
- Se o mesmo nome aparecer com estrutura diferente (Treinus mudou o treino), compara só o que for comparável e avisa.

## Compartilhar

Mockups aprovados: `.superpowers/brainstorm/` (telas `treino-detalhe.html`, `compartilhar-variacoes.html`, `compartilhar-editor.html`).

- Botão Compartilhar no treino abre um editor com prévia ao vivo.
- **4 modelos:** Stories escuro (9:16, visual do app); Sem fundo (9:16, PNG transparente, percurso branco e números com sombra, para colar sobre foto); Blocos (1:1, barras dos blocos coloridas pela zona, para treino estruturado); Faixa (linha compacta transparente).
- **Toggles:** percurso, nome do treino e data, distância, tempo, pace médio, FC média, pace dos blocos ativos, desnível, frase da leitura. O app lembra a última escolha.
- **A logo aparece sempre**, em todos os modelos, sem toggle: TRAINING com "AI" em verde-limão, com o ícone "AI" e a frase "Inteligência do pulso à linha de chegada." quando couber.
- Saída: imagem renderizada no aparelho (`ImageRenderer`) pelo `ShareLink` do iOS. Sem fundo e Faixa saem como PNG com alfa.
- Percurso desenhado a partir da polilinha já guardada, sem mapa por baixo.
- Não existe arquivo de logo. A logo é um componente SwiftUI (texto TRAINING com "AI" em `#C8F05A`, frase opcional) e o ícone "AI" com brilho também é desenhado em SwiftUI, como nos mockups. O ícone do app é exportado desse mesmo componente. Arte final de ícone fica para depois.

## Textos (Foundation Models)

Como na spec principal: gerados no aparelho, no sync, guardados; o modelo recebe só fatos calculados e devolve frases curtas em pt-BR via `@Generable`; fallback por template quando o modelo não estiver disponível. No plano 2 os textos cobrem a tela do treino: um texto por item de positivo/negativo/atenção e a frase de evolução da comparação.

## Fundação (primeira tarefa)

Herdada do review do núcleo:

- Chave da Personal API no Keychain local; tela mínima de Ajustes: colar chave, ver validade, testar conexão, forçar sync, apagar dados.
- `SyncEngine` cancelável (cancelamento cooperativo entre janelas e páginas, `sleep` que respeita cancelamento).
- Modelo de zonas de FC persistido.
- `SchemaV1` = exatamente o schema que o `store.sqlite` do `trainingctl` já tem hoje. Os campos novos deste plano (zonas, `Day` local, versão do processamento, prescrição, blocos e voltas) entram em `SchemaV2` com migração leve (todos opcionais ou com padrão). O store copiado abre como V1 e migra. `cloudKitDatabase` continua `.none`.
- `Day` local guardado no `ActivityRecord`.
- `samplesData` e `routeData` com `.externalStorage`.

## Reprocessar os `.FIT` já baixados

Os 492 `.FIT` da primeira carga foram processados pela versão atual do `FITReader`, que descarta a prescrição e as voltas. Como a spec principal manda descartar o `.FIT` depois de processar, o app precisa baixá-los de novo:

- `ActivityRecord` ganha uma versão do processamento. Atividade com versão menor que a atual entra na fila de reprocessamento.
- Fila do mais recente para o mais antigo, uma por vez, parando no primeiro 429 e retomando no próximo sync (mesma política de rate limit do núcleo). Os treinos recentes ficam ricos primeiro.
- Continua sem guardar o `.FIT` bruto (decisão da spec principal).
- O `trainingctl` ganha um comando `reprocess --store <caminho> [--limit N]` com a mesma fila, para enriquecer o store local antes de copiá-lo para o simulador. Referência de cota: a primeira carga real baixou 492 `.FIT` em 15 min com as esperas de 429, então a fila é viável; o que não couber num run fica para o seguinte.

## Desenvolvimento e simulador

- Projeto Xcode gerado por **XcodeGen** a partir de `project.yml` no repositório; o `.xcodeproj` gerado não entra no git. App em `App/` consumindo o pacote `Packages/TrainingKit`.
- Simulador **iPhone 18 Pro com iOS 27.1** (não existe iPhone criado hoje; criar). Deployment target continua iOS 26.
- Script de dev (`scripts/dev-run.sh` ou equivalente) que gera o projeto, compila, instala e abre o app no simulador. O controlador roda o script depois de cada tarefa que muda a UI, e o simulador fica aberto.
- **Dados reais no simulador:** o script copia `garmin-data/store.sqlite` (já sincronizado pelo `trainingctl`) para o container do app no simulador, para não esperar 15 min de primeira carga. O app abre esse store normalmente. A cópia é só de dev; nada de `garmin-data/` entra no git.
- A chave no simulador é colada pela tela de Ajustes ou injetada pelo script a partir de `~/.config/garmin/connect-personal-api-key`, sem nunca ser impressa nem commitada.
- `.superpowers/` (mockups) entra no `.gitignore`.

## Restrições

- iOS/iPadOS 26 mínimo, SwiftUI, Swift Charts, SwiftData, só tema escuro, identidade visual da spec principal.
- Repositório público: nenhum dado real (JSON, `.FIT`, store, chave) no git. Fixtures sintéticas.
- Sem comentários no código; types e constantes em arquivos próprios; Swift Testing.
- Lógica (blocos, regras, comparação, renderização de dados do compartilhamento) testável no pacote, sem UI. As telas só consomem.

## Decisões minhas (para conferir)

- Ordem do plano 2: fundação + app no simulador → prescrição no núcleo → lista e tela do treino → compartilhar → textos.
- Bloco de repetição desdobrado em blocos individuais (Tiro 1, Recuperação 1...).
- "Dentro do alvo" pelo pace médio do bloco (ou FC média, se o alvo for FC), limites inclusivos.
- Comparação pelo `wkt_name`, até 4 ocorrências.
- Reprocessamento dos `.FIT` do mais recente para o mais antigo, sem guardar o bruto.
- XcodeGen para o projeto; iPhone 18 Pro / iOS 27.1 no simulador.
- Cópia do store do `trainingctl` para o simulador no dev, enriquecido antes pelo `trainingctl reprocess`.
- `SchemaV1` = schema atual do store; campos novos em `SchemaV2` com migração leve.
- Logo e ícone desenhados em SwiftUI, sem asset de imagem.

## Fica para o builder

- Estrutura de arquivos do app, navegação (tab bar no iPhone, split view no iPad, como na spec principal), componentes.
- Valores iniciais dos limites das regras (constância, desacoplamento, queda de FC, tolerância de alvo).
- Layout final das telas, seguindo os mockups e o estilo "Fusão".
- Prompt e schema `@Generable` dos textos.
