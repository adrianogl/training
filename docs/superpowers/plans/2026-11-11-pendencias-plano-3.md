# trAIning — Pendências do plano 3 (Hoje, Evolução e Provas)

Saída do review final da branch `feat/hoje-evolucao-provas` (ab64561..e8ab265). Nada aqui bloqueia o merge, exceto a verificação no aparelho.

## Verificação no aparelho (antes do merge)

- BGTask real: o simulador do iOS 27 recusa `submitTaskRequest` (Code=1). Falta ver a execução de madrugada, a entrega do aviso e o toque abrindo `training://hoje/prontidao`.

## Background e aviso

- Sync `.launch` que falha mantém `todayReadinessComplete` do dia anterior. Se o app for para background depois das 4h, perde o retry de +1h (`AppModel.swift`).
- Falta teste de "execução em background falha com o dia anterior completo, reagenda em +1h". Hoje só a inspeção cobre o reset no início de `syncNow(.background)`, porque a flag é `private(set)`.
- O retorno antecipado por 429 em background pula `updateReadiness`, e o `readinessScore` gravado de hoje atrasa até o próximo sync completo. Hoje e o aviso calculam ao vivo e não são afetados. `hardOnLowReadiness` usa o valor gravado.
- `notifiedDay` é gravado mesmo quando o `add` da notificação falha, e a permissão é pedida em paralelo no primeiro launch (`UserNotificationScheduler.swift`).

## Desempenho

- A lista de treinos recalcula a nota de todas as corridas a cada mudança em `records.count` e decodifica samples dos prescritos (`kilometerSplits`). Opções: guardar a nota (a spec permite) ou calcular só as linhas visíveis.
- `NarrativeBackfill` é `@MainActor` e decodifica samples dos prescritos na main depois do sync de abertura. Mover a análise para fora da main.

## Provas

- Selo PR vem do flag `pr` da atividade, que também vale para best effort interno. Pode marcar como PR uma prova que não foi recorde na distância.
- O checklist é calculado no app (`NextRaceModel`), não no pacote, e as regras não têm teste.
- O picker de atividade do resultado não exclui corrida já ligada a outra prova.

## Previsões e VO2max

- A previsão de 5 km depende de um único esforço de meses atrás, porque nos últimos 90 dias não há prova vinculada nem esforço máximo. Caminhos: reconhecer e vincular provas automaticamente, ou ancorar a previsão no VO2max.
- Margens curtas no alvo (5 km perto de +3%, VO2max perto de −1,5). Recalibrar quando houver prova nova.
- A série e a projeção de VO2max na Evolução ficam mais ruidosas com a suavização menor, e não têm teste. O nome `vo2SmoothingDays` não descreve o fator.

## Narrativa

- O validador de frases confere números, mas não a direção (acima/abaixo, melhor/pior). Passar veredito e direção como `words`.

## Nota do treino e análise por km

- Os pontos por parte não somam o badge normalizado e a tela não explica. Os testes são rasos (`value > 0`).
- O bucket inicial do bloco pode ser descartado (até 5 s), há `try! #require` em testes que não são `throws` e as linhas de km não usam `accessibilityElement(children: .combine)`.
- `pauseMaximumSpeed` fixo em 0,5 m/s trata caminhada muito lenta, em buraco de samples maior que 10 s, como pausa.

## Decisões para o Adriano rever

- Parciais sem o tempo parado (Ruling 16). Os splits por km de corrida livre, prova e bloco excluem pausa, como o tempo em movimento do Garmin. A pausa só conta quando a distância quase não avança no intervalo. Se preferir o tempo total, é uma constante ou flag.
- Prova no dia dela (Ruling 19). A prova-alvo é a próxima a partir de amanhã, então na manhã da prova Hoje e a sidebar mostram a seguinte, e a prova do dia aparece só em Provas. Se Hoje deve mostrar a prova do dia, muda o filtro `targetRace > today`.

## Adiado

- Gráfico de relação HRV × carga no Detalhe de métrica (a spec diz "quando fizer sentido").
