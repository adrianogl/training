# trAIning — Pendências do plano 3 (Hoje, Evolução e Provas)

Saída do review final da branch `feat/hoje-evolucao-provas` (ab64561..e8ab265). Nada aqui bloqueia o merge, exceto a verificação no aparelho.

Estado ao fim do plano 4 (`feat/zonas-limiar-e-provas`): itens com "Resolvido no plano 4" entraram nessa branch, com o commit entre parênteses. Os demais seguem abertos; o que sobrou do plano 4 está em `2026-11-12-pendencias-plano-4.md`.

## Verificação no aparelho (antes do merge)

- BGTask real: o simulador do iOS 27 recusa `submitTaskRequest` (Code=1). Falta ver a execução de madrugada, a entrega do aviso e o toque abrindo `training://hoje/prontidao`.

## Background e aviso

- Resolvido no plano 4 (`65d623e`): `todayReadinessComplete` passou a guardar o dia e só vale quando é hoje. Descrição original: sync `.launch` que falha mantém `todayReadinessComplete` do dia anterior. Se o app for para background depois das 4h, perde o retry de +1h (`AppModel.swift`).
- Resolvido no plano 4 (`65d623e`, `BackgroundSyncTests`): descrição original: falta teste de "execução em background falha com o dia anterior completo, reagenda em +1h". Hoje só a inspeção cobre o reset no início de `syncNow(.background)`, porque a flag é `private(set)`.
- O retorno antecipado por 429 em background pula `updateReadiness`, e o `readinessScore` gravado de hoje atrasa até o próximo sync completo. Hoje e o aviso calculam ao vivo e não são afetados. `hardOnLowReadiness` usa o valor gravado.
- `notifiedDay` é gravado mesmo quando o `add` da notificação falha, e a permissão é pedida em paralelo no primeiro launch (`UserNotificationScheduler.swift`).

## Desempenho

- Resolvido no plano 4 (`d94321d`, `f906a24`): a nota passou a ser guardada em `ActivityRecord`, com chave que acompanha zonas e treinos anteriores. Descrição original: a lista de treinos recalcula a nota de todas as corridas a cada mudança em `records.count` e decodifica samples dos prescritos (`kilometerSplits`). Opções: guardar a nota (a spec permite) ou calcular só as linhas visíveis.
- Resolvido no plano 4 (`6f9965f`, `e1650bd`): o backfill roda fora da main. Descrição original: `NarrativeBackfill` é `@MainActor` e decodifica samples dos prescritos na main depois do sync de abertura. Mover a análise para fora da main.

## Provas

- Aberto: selo PR vem do flag `pr` da atividade, que também vale para best effort interno. Pode marcar como PR uma prova que não foi recorde na distância.
- O checklist é calculado no app (`NextRaceModel`), não no pacote, e as regras não têm teste.
- O picker de atividade do resultado não exclui corrida já ligada a outra prova.

## Previsões e VO2max

- Parcial no plano 4 (`c575c62`, `a2a3071`, `4a02250`): o app reconhece corridas que parecem prova, pergunta em "Parece prova?" e a prova confirmada pesa por um ano na previsão. Falta dado: sem histórico de limiar e com poucas corridas de base, poucas corridas viram candidatas. A previsão de 5 km só muda depois da recalibração (ver plano 4).
- Aberto: margens curtas no alvo (5 km perto de +3%, VO2max perto de −1,5). A Task 13 do plano 4 não rodou; ver plano 4.
- A série e a projeção de VO2max na Evolução ficam mais ruidosas com a suavização menor, e não têm teste. O nome `vo2SmoothingDays` não descreve o fator.

## Narrativa

- Resolvido no plano 4 (`0c4da50`, `c1066d9`): o validador confere a direção pela lista de palavras do veredito. Descrição original: o validador de frases conferia números, mas não a direção (acima/abaixo, melhor/pior).

## Nota do treino e análise por km

- Os pontos por parte não somam o badge normalizado e a tela não explica. Os testes são rasos (`value > 0`).
- O bucket inicial do bloco pode ser descartado (até 5 s), há `try! #require` em testes que não são `throws` e as linhas de km não usam `accessibilityElement(children: .combine)`.
- `pauseMaximumSpeed` fixo em 0,5 m/s trata caminhada muito lenta, em buraco de samples maior que 10 s, como pausa.

## Decisões do Adriano (2026-11-11)

- Parciais sem o tempo parado (Ruling 16): decidido, os splits por km de corrida livre, prova e bloco continuam excluindo pausa, como o tempo em movimento do Garmin. A pausa só conta quando a distância quase não avança no intervalo. Sem mudança.
- Prova no dia dela (Ruling 19): decidido, Hoje e a sidebar mostram a prova do dia como prova-alvo. `targetRace` passa a usar `day >= today` e a prova vira concluída a partir do dia seguinte. Na manhã da prova a previsão do dia é a de hoje, sem projeção, e o contador diz "hoje". Feito no commit `fix(insights): mostra a prova do dia em hoje`.

## Adiado

- Gráfico de relação HRV × carga no Detalhe de métrica (a spec diz "quando fizer sentido").
