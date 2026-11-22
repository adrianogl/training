# Regras de prescrição

O que o treinador beta monta e como ajusta o plano. As regras de leitura dos treinos e da prontidão estão em [analise.md](analise.md).

Toda mudança em uma regra daqui atualiza este arquivo no mesmo commit.

Constantes: `Packages/TrainingKit/Sources/Insights/TrainerEngine*Constants.swift`. Testes: `Packages/TrainingKit/Tests/InsightsTests/Trainer*Tests.swift`.

## Princípios

- **Distância:** tudo é prescrito por distância. Aquecimento em km, blocos em km ou metros, recuperação em metros. Nunca "10 min".
- **Descanso entre blocos:** é a única exceção, em tempo, porque é parado e sem trote.
- **Aquecimento e desaquecimento:** aquecimento sempre de 3 km, também depois de força de pernas, e sem desaquecimento.
- **Limites de tamanho:** são definidos por tempo, como na literatura (Daniels, método norueguês), e convertidos em km inteiro no ritmo atual, nunca fracionado.
- **Metas de prova:** continuam em tempo, porque são resultado, não prescrição.
- **Referências:** o padrão de qualidade segue o histórico real do atleta: 41 treinos de março a novembro de 2026 no Garmin.

## Ritmos

| Regra | Valor | Constante |
| --- | --- | --- |
| Janela do histórico | 90 dias | `paceWindowDays` |
| Ritmo de limiar | mediana dos blocos dos últimos 4 limiares | `workPaceRuns` |
| Sem histórico de limiar | previsão de 10 km + 8 s/km | `thresholdAbovePrediction` |
| Ritmo de VO2 | mediana dos blocos dos últimos treinos de VO2; sem histórico, 15 s/km mais rápido que o limiar | `vo2BelowThreshold` |
| Faixa de qualidade | ± 3 s/km | `qualityBand` |
| Faixa da rodagem | ± 7 s/km | `easyBand` |
| Ritmo do longão | mediana dos longões; sem histórico, 5 s/km mais rápido que a rodagem | `longBelowEasy` |
| Rodagem sem histórico | 6:00/km | `fallbackEasyPace` |
| Mudança mínima para atualizar ritmo | 2 s/km | `paceChangeSeconds` |

### Sem corridas no histórico

Quando a pessoa não tem nenhuma rodagem nos 90 dias, o plano novo pede um tempo recente (5 km, 10 km ou 21 km) e calcula os ritmos pela fórmula de Riegel (expoente 1,06). Os ritmos entram como ajuste manual do plano; depois o treinador recalcula pelas corridas.

| Ritmo | Regra | Constante |
| --- | --- | --- |
| VO2 | pace previsto para 5 km − 5 s/km | `recentRaceVo2BelowFiveK` |
| Limiar | pace previsto para 15 km | `recentRaceThresholdMeters` |
| Rodagem | pace previsto para 5 km × 1,27 | `recentRaceEasyFactor` |
| Longão | rodagem − 5 s/km | `longBelowEasy` |

Arquivos: `Insights/TrainerEngineRecentRace.swift`, `App/Trainer/TrainerRecentRaceCard.swift`. Testes: `InsightsTests/TrainerRecentRaceTests.swift`.

## Tempo estimado

Treino de corrida prescrito e ainda não feito mostra o tempo mínimo e o máximo: na semana e no dia do treinador, no card do Hoje, na lista de Treinos e no detalhe do treino do Garmin. Treino feito mostra o tempo real.

- Cada trecho é somado à parte: distância vezes o ritmo mais rápido da faixa dá o mínimo; vezes o mais lento, o máximo.
- Trecho por tempo e descanso entram iguais nos dois lados.
- Trote de recuperação sem ritmo usa a faixa do aquecimento. A distância do treino que não está em nenhum trecho (desaquecimento) também.
- Trecho por distância sem ritmo (alvo por FC ou zona, subida) usa a faixa de rodagem: a do plano ou, sem plano, a da mediana das rodagens dos últimos 90 dias. O tempo aparece com "≈". Sem plano e sem corrida nesse período, o treino fica sem tempo.
- Trecho sem fim definido (até apertar volta) não soma e marca o tempo com "≈".
- O mínimo arredonda para baixo e o máximo para cima, no minuto. No detalhe do Garmin, cada tiro com distância e ritmo mostra o próprio tempo ("1:40–1:44 cada").

## Semana padrão

Segunda rodagem, terça limiar, quarta rodagem, quinta VO2, sexta opcional, sábado longão, domingo folga (`defaultStructure`). As trocas de dia evitam dois treinos fortes seguidos e qualidade a menos de 4 dias da prova (`raceQualityGapDays`).

## Volume e fases

| Regra | Valor | Constante |
| --- | --- | --- |
| Volume de partida | média das últimas 4 semanas | `volumeWindowDays` |
| Sem histórico | 15 km por semana | `fallbackWeeklyMeters` |
| Crescimento | 5% por semana | `weeklyGrowth` |
| Pico | 125% do volume atual | `defaultPeakShare` |
| Semana leve fixa | a cada 4 semanas, 80% do volume e longão a 75% | `recoveryEvery`, `recoveryVolumeShare`, `recoveryLongShare` |
| Polimento | 70% e 50% nas 2 últimas semanas; 1 semana para prova de até 10 km | `taperShares`, `taperWeeks`, `shortRaceTaperWeeks` |
| Fases | base 30%, construção 35%, o resto específico | `baseShare`, `buildShare` |
| Tamanho do bloco | 18 semanas para prova de 30 km ou mais, 14 para 15 km ou mais, 12 nas outras | `blockWeeksLimits`, `defaultBlockWeeks` |

## Tamanho de cada corrida

| Corrida | Regra | Constante |
| --- | --- | --- |
| Rodagem | 40 a 75 min, entre 6 e 14 km, pelo tamanho das rodagens das últimas 6 semanas | `easyMinimumSeconds`, `easyMaximumSeconds`, `minimumEasyMeters`, `maximumEasyMeters`, `easyWindowDays` |
| Opcional | 70% da rodagem, só com prontidão de pelo menos 60 e até 50 min | `optionalEasyShare`, `optionalReadiness`, `optionalMaximumSeconds` |
| Longão | até 150 min e até 30% da semana, mínimo de 10 km, sobe de 2 em 2 km | `longMaximumSeconds`, `longWeekShare`, `minimumLongMeters`, `longStep` |
| Teto do longão pelo volume | até 7,5 km/sem: 14 km; até 15: 16 km; até 30: 22 km; acima: 32 km | `longCaps` |
| Semana da prova | trotes de 5 km | `raceWeekEasyMeters` |

## Limiar

- **Blocos:** o bloco cresce em escada, 1 → 2 → 3 → 4 km e depois contínuo, com o volume quase fixo (`thresholdBlocks`).
- **Volume do bloco:**
  - base: 8 km;
  - construção: 9 a 10 km;
  - específica: 10 a 12 km;
  - semana leve: 6 km.
- **Variações:** pirâmide 3-2-1 km, e 6 + 3 km a partir de 9 km de volume.
- **Descanso parado:** 60 s por km de bloco, entre 60 e 240 s, em degraus de 30 s (`thresholdRestSecondsPerKm`).

## VO2

- **Formatos em rotação:** 12 × 400 m, 5 × 1 km, 3 ou 4 × 1,5 km e pirâmide.
- **Volume:** até 10 km de trabalho e 8% da semana.
- **Descanso parado:** 0,7 do tempo do tiro, com no mínimo 150 s. Em tiros de até 600 m, o mínimo é 60 s.
- **Fechamento:** 3 × 200 m forte com 200 m de trote.

## Ritmo de prova

- **Para quem:** provas de 21 km ou mais.
- **Blocos:** de 4 km, começando com 8 km no total e subindo 4 km por vez. O teto é 70% da prova e 20 km.
- **Descanso:** entre 90 e 150 s.
- **Frequência:** a cada 2 semanas.
- **Ritmo-alvo:** segue a escada `goalPaceLadder`, de 4 × 2 km até 1 × 15 km.

## Longão em estágios

O longão de quem quebra no fim é montado em estágios, até ficar contínuo:

1. 4 blocos de 20%;
2. 3 blocos de 25%;
3. 2 blocos de 35%;
4. 1 bloco de 50%;
5. 1 bloco de 70%;
6. contínuo.

O descanso é de 60 s, e de 30 s no último estágio. O longão avança de estágio depois de 2 longões bons e volta um estágio depois de 2 falhas (`longStageShares`, `longStageAdvanceStreak`, `longStageBackMisses`).

## Ajustes do plano

| Situação | Ajuste | Constante |
| --- | --- | --- |
| Prontidão abaixo de 50 no dia | treino forte vira rodagem de 8 km | `readinessTrigger`, `readinessEasyMeters` |
| Média da semana abaixo de 55 | volume × 0,9 | `readinessWeek`, `readinessScale` |
| Dor | volume × 0,7 por 7 dias, mínimo 3 km e qualidade de até 6 km | `painScale`, `painPeriodDays` |
| Viagem | corrida de 6 km por 1 dia | `travelRunMeters` |
| Calor no longão | ritmo + fator de calor (temperatura + ponto de orvalho, sem aclimatação) × pace do longão; com fator de 0,045 ou mais, 1 km a menos de bloco. Abaixo de 3 s/km, o calor é ignorado e o longão fica como está. Sem ponto de orvalho, sem ajuste | `TrainerHeat`, `heatBlockFactor`, `heatBlockReduction`, `RunWeatherConstants.minimumHeatSeconds` |
| Treino feito | pelo menos 90% do prescrito | `doneShare` |
| Longão falho | abaixo de 85% do prescrito; abaixo de 70%, o próximo longão fica 2 km menor | `longFailShare`, `longReduceShare`, `longReduceMeters` |
| Gel no longão | só em longão de pelo menos 15 km, 2 km antes do km em que o último longão quebrou | `gelMinimumMeters`, `gelBeforeFadeKm` |

## Avaliação do ciclo

Depois de pelo menos 4 semanas (`TrainerEngineCycleConstants.swift`):

- **Aumenta:** o volume sobe 8% se pelo menos 90% dos treinos foram feitos e a prontidão ficou estável, com tolerância de 3 pontos.
- **Reduz:** o volume cai 10% se menos de 75% dos treinos foram feitos ou se a prontidão caiu 8 pontos.

## Semana leve por sinais

Constantes: `TrainerEngineSignalsConstants.swift`. Testes: `TrainerSignalsTests.swift`, `TrainerSignalWeekTests.swift`.

- **Base:** a base continua 3:1, com a semana leve fixa da tabela de volume, que nunca é adiada.
- **Seis sinais:** cada um é medido contra a média pessoal de 60 dias:
  - HRV das 7 noites abaixo da média − 0,5 desvio padrão;
  - FC de repouso dos 7 dias 3 bpm acima;
  - sono dos 7 dias 45 min abaixo;
  - carga dos 7 dias acima de 1,3 × a média semanal de 28 dias;
  - desempenho: 2 qualidades seguidas fora do alvo, ou FC 5 bpm acima no mesmo ritmo de rodagem;
  - prontidão média dos 7 dias abaixo de 55.
- **Fechamento da semana:**
  - 0 ou 1 sinal: segue;
  - 2 sinais: a próxima semana tem 10% a menos e nada de acelerações;
  - 3 ou mais sinais, ou HRV e FC juntos: antecipa a semana leve, se a última foi há pelo menos 3 semanas, e o 3:1 recomeça.
- **Tipo da leve:**
  - sinais do corpo: 75% do volume, com 1 qualidade curta;
  - sinais do treino: 85% do volume, com a qualidade trocada por rodagem com acelerações.
- **Perto da prova:** a 21 dias da prova ou menos, a semana leve não é antecipada.

## Força

- **Volume de corrida:** a força (segunda superiores, quarta pernas, sexta corpo inteiro) não reduz o volume de corrida. O plano só mostra a força.
- **Dias:** o treinador avisa quando limiar, VO2 ou longão cai no dia seguinte a um dia de pernas, e sugere trocar o dia.
- **Fonte por dia:** cada dia de força vem do MFIT (professor, só leitura) ou do treinador. Quando o MFIT muda, só os dias do MFIT são trocados; os do treinador ficam, exceto num dia que o MFIT passou a ocupar, em que o MFIT vence (`StrengthSessions.merge`). Na edição, os dias do MFIT não aparecem para escolha.
- **Foco do dia do treinador:** superiores, pernas, corpo inteiro, mobilidade e core ou só mobilidade, com intensidade (leve, moderada, pesada), duração e local (academia, casa, só peso do corpo). Pernas moderada ou pesada e corpo inteiro pesado contam como dia de perna pesada.

- **Sem plano do treinador:** a força funciona do mesmo jeito, guardada à parte (`TrainerStrengthStandaloneStore`) e levada para o plano quando ele é criado. O dia de corrida forte vem do nome do treino da assessoria no Garmin (`ExternalDayKind`): limiar, ritmo e tempo contam como limiar; VO2, intervalado, tiro e fartlek como VO2; longo, longão ou 18 km ou mais como longão; "prova" sem "ritmo" como prova. Semana de recuperação e semana da prova só se aplicam com plano.

### Plano de força

- **Plano:** objetivo (Performance na corrida, Força, Prevenção, Mobilidade para corrida ou Manutenção), dias com foco, minutos e local, validade, data de início e quem monta (Treinador ou Claude). Só um plano ativo por vez.
- **Validade:** até a prova, de 1 a 24 semanas ou até uma data. Os treinos do plano aparecem só entre o início e o fim; fora disso, nenhum dia do plano aparece.
- **MFIT em paralelo:** o MFIT nunca é substituído pelo plano. Num dia com os dois, a semana e o Hoje mostram dois cards, "MFIT" e "Plano".
- **Mobilidade:** foco próprio, só exercícios de mobilidade, sem carga.
- **Objetivo no gerador** (`StrengthContext.objective`, só nos dias do plano ativo):

| Objetivo | Dia novo | Efeito na escolha |
| --- | --- | --- |
| Performance na corrida | pernas, moderada, 40 min, academia | unilateral, pliometria, panturrilha e estabilidade de quadril antes de agachamento e terra (`performanceOrder`) |
| Força | corpo inteiro, moderada, 45 min, academia | ordem padrão do foco |
| Prevenção | corpo inteiro, leve, 30 min, academia | ordem padrão do foco |
| Mobilidade para corrida | mobilidade, leve, 20 min, casa | tornozelo, quadril e torácica só com exercícios dinâmicos: fica de fora alongamento (`STRETCH_`) e isometria |
| Manutenção | corpo inteiro, leve, 25 min, academia | ordem padrão sem pliometria |
- **Fim do plano:** a notificação "Plano de <objetivo> terminou" com "Foram X de Y treinos" sai às 21h do último dia de treino ou logo depois do último treino concluído, o que vier primeiro, uma vez por plano e só no iPhone. A tela Força oferece "Montar próximo plano" e "Repetir o mesmo plano" (mesmas sessões, a partir do próximo dia de treino).
- **Claude:** quando o plano é do Claude, o pedido usa o período e os dias do plano, e o resultado fora do plano é rejeitado.
- **Migração:** na primeira abertura, as sessões do treinador existentes viram um plano que termina junto com o plano de corrida (ou em 12 semanas, sem plano de corrida), com um aviso único para ajustar.

### Sugestão de dias e foco

Arquivo: `Insights/StrengthSessions.swift`. Testes: `InsightsTests/StrengthDayTests.swift`.

| Situação | Foco sugerido |
| --- | --- |
| Semana com dias do MFIT | mobilidade e core, leve, 25 min, para complementar o professor |
| Dia de qualidade (limiar, VO2, longão, prova) ou véspera | mobilidade e core, leve, 25 min |
| Qualidade em 2 dias, ou perna pesada já na semana | superiores, moderada |
| Sem qualidade nas 48 h seguintes | pernas, pesada |

### Treino gerado

Arquivos: `Insights/StrengthGenerator.swift`, `Insights/StrengthCatalog*.swift`, `Insights/GarminStrengthCatalogData.swift` (gerado), `Insights/StrengthProgression.swift`, `scripts/garmin-catalog.py`. Constantes: `StrengthGeneratorConstants`, `StrengthCatalogConstants`. Testes: `InsightsTests/StrengthGeneratorTests.swift`, `StrengthCatalogTests.swift`, `scripts/test_garmin_catalog.py`.

- **Catálogo:** o catálogo oficial de exercícios da Garmin (`Exercises.json`), com o nome em pt-BR da própria Garmin. O id é `CATEGORIA/EXERCICIO` (por exemplo `SQUAT/GOBLET_SQUAT`) e todo exercício vai ao relógio com categoria e `exerciseName`. Os treinos do MFIT não passam pelo catálogo: seguem com os exercícios do professor.
- **Fora do catálogo:** as categorias de cardio e equipamento especial (bike, elíptico, corrida, escada, escada de agilidade, cardio, sled, pneu, marreta, battle rope, sandbag e levantamento olímpico), as entradas genéricas `CORE`, `HIP_STABILITY` e `SHOULDER_STABILITY`, ruck, snatch, kipping, handstand, muscle-up, rosca de punho e alongamentos de pescoço e antebraço.
- **Metadados:** a Garmin só informa os músculos. O script `scripts/garmin-catalog.py` deriva padrão de movimento, equipamento, focos, regiões que carregam, unilateral e isometria pelo nome e pela categoria; `scripts/garmin-catalog-overrides.json` corrige casos pontuais e nomes sem tradução. O catálogo não é editado à mão: muda pelo script.
- **Sincronização:** `python3 scripts/garmin-catalog.py` baixa a lista atual da Garmin, regenera o catálogo e imprime o que mudou (novos com a classificação derivada, removidos e alterados; `--report <arquivo>` grava o texto). Removido que aparece em `StrengthCatalogConstants` é marcado como atenção e precisa de um novo destino no mapa de ids antigos. O script também grava `server/src/garminCatalogSnapshot.ts`, o retrato da lista bruta da Garmin (id e nome pt-BR) com os ids usados no mapa de ids antigos.
- **Aviso mensal:** o servidor de sync roda `/api/cron/garmin-catalog` pelo Vercel Cron no dia 1 às 12h UTC (9h de Brasília), protegido por `CRON_SECRET`. Ele baixa a lista da Garmin e compara com o retrato. Sem diferença, não faz nada; com diferença, manda e-mail para `ADMIN_EMAILS` com novos, removidos (destacando os que estão no mapa de ids antigos) e renomeados. O aviso para de chegar depois que o script roda e o servidor recebe o deploy com o retrato novo. A classificação continua só no script.
- **Equipamento por local:** academia aceita tudo; casa, o que o atleta marcou em "Em casa você tem" (halteres, elástico, kettlebell, bola de pilates, medicine ball, fita de suspensão, barra e anilhas) mais peso do corpo, começando com halteres e elástico; só peso do corpo, só peso do corpo. O pedido ao Claude leva a lista em `equipamento_casa`, e o validador do app e o do MCP usam a mesma lista.
- **Ids antigos:** os 61 ids do catálogo anterior (`agachamento-livre` etc.) continuam aceitos e viram o id novo (`StrengthCatalogConstants.legacyIds`), inclusive em trocas salvas e treinos do Claude já aplicados. As últimas cargas do MFIT casam pelo nome pt-BR da Garmin e pelo nome antigo do exercício.
- **Escolha:** dentro de cada padrão, nesta ordem: exercício composto antes de isolado; equipamento preferido do local (barra, máquina, cabo, halter, kettlebell, elástico, peso do corpo, medicine ball, bola suíça, suspensão; puxada vertical começa pelo cabo; pliometria, anti-extensão e mobilidade começam pelo peso do corpo); exercício simples (até 4 palavras, sem combinação como "_TO_" ou "_AND_" e sem variação avançada) antes de variação com `WEIGHTED_` e antes de combinação; e por fim uma ordem embaralhada que muda a cada bloco de 4 semanas (blocos contados a partir de 05/01/2026). Dentro do bloco o exercício se repete e a carga progride.
- **Tamanho:** até 8 exercícios por treino, 12 em mobilidade e core; o resto do tempo vira série extra.
- **Duração:** o treino fecha na duração escolhida com 5 min de tolerância. Quando o limite de exercícios chega antes, sobe até 4 séries a mais por exercício.
- **Foco mobilidade:** escolhe só exercícios de mobilidade de quadril, tornozelo e torácica, leve, sem carga nem sugestão de carga; perna leve. O gerador usa o mesmo caminho da semana da prova.
- **Dia de qualidade:** pernas ou corpo inteiro viram mobilidade e core, leve. Superiores e mobilidade ficam como estão. "Manter original" desfaz.
- **Semana de recuperação:** duração e séries a 70%.
- **Semana da prova:** nos 3 dias antes da prova, sem força; de 4 a 7 dias antes, só mobilidade, 15 min.
- **Prontidão abaixo de 50:** só mobilidade, 20 min. "Manter original" desfaz.
- **Dor marcada:** sai todo exercício que carrega a região (joelho, panturrilha e aquiles, lombar, quadril, ombro). Sem nada que sobre, cai para mobilidade.
- **Complemento ao MFIT:** padrões de movimento que o MFIT já trabalhou na semana vão para o fim da fila.
- **Progressão de carga:** com a última carga registrada e todas as séries fechadas, sobe 2,5% arredondado, no mínimo 1 kg. Sem fechar as séries, repete a carga. Sem histórico, sem carga sugerida.
- **Carga sugerida:** exercício com carga (barra, máquina, polia, halter, kettlebell, medicine ball) sem registro próprio recebe 80% da carga de outro exercício do mesmo padrão de movimento ou da mesma categoria da Garmin, com o rótulo "sugerida". Base preferida: mesmo equipamento; só depois o par barra e halter/kettlebell (barra para halter ou kettlebell conta 50%, por mão). Base bilateral para alvo unilateral conta 50%; base unilateral nunca serve a alvo bilateral. Entre as bases, vale a de registro mais recente (empate: id em ordem alfabética). O resultado arredonda para baixo ao incremento (barra, máquina e polia 2,5 kg; halter e medicine ball 1 kg; kettlebell 2 kg) e, abaixo de um incremento, não sugere. Vale no treino gerado e nos treinos do Claude sem `kg`; o MFIT não muda.
- **Séries e repetições:** principal com barra ou máquina pesada 4 × 6 (150 s), moderada 3 × 10 (90 s), leve 2 × 12 (60 s); acessório pesado 3 × 8, moderado 3 × 10, leve 2 × 12; panturrilha 2–3 × 10–12; pliometria 3 × 6 (90 s); core 2–3 × 10–12 ou 30–45 s; mobilidade 2 × 8 por lado.

## Envio ao Garmin

Arquivos: `GarminAPI/GarminPlannedPayload.swift`, `App/Trainer/Send/*`. Testes: `GarminAPITests/GarminPlannedUploadTests.swift`, `AppTests/TrainerSendTests.swift`.

- **O que vai:** os próximos 7 dias, por tipo (corrida, força ou os dois), com dias desmarcáveis. Força dos dias do treinador e, com "Enviar os treinos do MFIT" ligado, os do MFIT.
- **Corrida:** só entra com "Corrida do treinador" ligado. Enquanto a corrida vier da assessoria, fica desligado. Aquecimento e blocos por distância, alvo de pace e descanso parado por tempo. Com "Corrida do treinador" ligado, o app ignora os treinos que o Garmin marca como vindos da Treinus (`workoutProvider`): eles saem do Hoje, de Treinos, da nota, do mostrador e dos dias de corrida forte da força. No calendário do Garmin eles continuam.
- **Força:** cada exercício vira um grupo repetido pelo número de séries, com repetições ou tempo, descanso e carga em kg quando houver. A descrição vai sem acento.
- **Status:** novo (nunca enviado), mudou (o treino gerado ficou diferente do enviado) ou no Garmin.
- **Só o que o app criou:** o app guarda o id de cada treino que enviou e só substitui ou apaga esses. Treino que saiu do plano dentro dos 7 dias é apagado do Garmin.
- **Falhas:** se apagar no Garmin falhar (exceto "não encontrado"), o registro fica e o treino novo daquele dia não é criado, para não sobrar treino duplicado. Se o agendamento falhar, o treino recém-criado é apagado. Só um envio roda por vez, e ele não é cancelado ao sair da tela.
- **Envio automático:** desligado, só corrida, só força ou os dois. Quando ligado, roda ao abrir o treinador e quando o plano muda.
- **MFIT:** com "Enviar os treinos do MFIT" ligado (só no Garmin), entram os treinos do professor de hoje até o fim da prescrição do MFIT, ou 4 semanas à frente quando o programa não tem fim. O nome no Garmin é "trAIning · MFIT · <treino>". Cada exercício usa o exercício do catálogo da Garmin quando o nome do MFIT tem par no mapa `mfit` do `exercise-media.json`; sem par, vai com o nome do professor e a categoria que o parser do MFIT adivinha (`TOTAL_BODY` se nenhuma). Dia em que o Claude substituiu o MFIT fica de fora. Desligar a opção apaga do Garmin os treinos do MFIT que o app enviou. Testes: `AppTests/MFITSendTests.swift`.

## Envio ao Apple Watch

Arquivos: `App/Trainer/Send/AppleWorkoutBuilder.swift`. Testes: `AppTests/AppleWorkoutBuilderTests.swift`.

- **Quando:** a conta usa Apple Watch (Ajustes › Relógio). Os treinos vão pelo WorkoutKit e aparecem no app Exercício, em Treinos personalizados, às 6h do dia.
- **Corrida:** sempre do treinador (não há assessoria no Apple Watch). Aquecimento e desaquecimento por distância; cada bloco vira um intervalo com alerta de faixa de velocidade (o pace mais lento e o mais rápido do bloco); repetições viram um bloco com o número de voltas; descanso parado por tempo.
- **Força:** treino de força com meta de tempo. Tempo = soma de séries × (tempo do exercício ou 4 s por repetição + descanso), arredondado para cima em minutos. Os exercícios ficam no app do iPhone.
- **Status, substituição e remoção:** os mesmos do Garmin, usando o id do plano agendado. Sem envio automático.

## Força nos avisos

- **Aviso da manhã:** depois da prontidão, cita a força do dia de qualquer fonte: "Força: MMII." para o MFIT e "Força: mobilidade e core, 25 min." para o treinador. Quando uma regra mudou o treino do treinador (dia de qualidade, recuperação, prova ou prontidão), vira "Força ajustada:". Dia sem força ou nos 3 dias antes da prova não cita nada (`MorningStrengthText`).
- **Relatório de domingo:** o bloco de força mostra as sessões feitas contra as planejadas por fonte, como "MFIT 3 de 3 · Treinador 1 de 2", quando a semana tem dias do treinador (`StrengthTally`).

## Treinos de força do Claude

Arquivos: `Insights/ClaudeStrength*.swift`, `App/Trainer/Claude/*`. Testes: `InsightsTests/ClaudeStrengthTests.swift`, `AppTests/ClaudeAppTests.swift`, `AppTests/StrengthPlanScheduleTests.swift`.

- **Pedido:** a tela Força copia um pacote com instruções, contexto (dias do treinador e do MFIT, corrida do período, prontidão de 7 dias, dor, últimas cargas, catálogo, regras e prova) e o formato da resposta. O catálogo vai filtrado pelos locais dos dias do treinador e sem os exercícios que carregam região com dor, uma linha por exercício no formato `id|padrao|equipamento|regioes|focos|marcas` (`u` unilateral, `i` isometria). Período: próxima semana (segunda a domingo) ou até a véspera da prova-alvo; sem prova, 12 semanas.
- **Formato:** JSON `versao` 1, com `treinos` por `dia`, `foco`, `minutos`, `local`, `porque` e `exercicios` (`id` do catálogo, `series`, `reps` ou `segundos`, `descanso`, `kg`).
- **Erros que bloqueiam o dia:** data inválida, dia passado ou fora do período, dia do MFIT, dia sem força do treinador, exercício fora do catálogo ou do local, exercício em região com dor, séries fora de 1–6, reps fora de 1–30, segundos fora de 10–120, descanso fora de 0–240, mais de 12 exercícios, perna pesada (2 ou mais exercícios de agachamento, terra, unilateral ou pliometria com barra, máquina, halter ou kettlebell) nas 48 h antes de limiar, VO2 ou longão, e força nos 3 dias antes da prova.
- **Avisos:** duração estimada a mais de 10 min dos minutos do dia; carga mais de 5% acima da última.
- **Substituir o MFIT:** um dia do MFIT só é aceito com `"substitui_mfit": true` (aviso, não erro). Ao aplicar, aquela data fica só com o treino do Claude: o treino do professor some da semana, do card do Hoje e do aviso da manhã, e o app tira do calendário do Garmin o treino de força agendado naquele dia que não foi criado por ele (o treino continua na biblioteca). As outras datas do mesmo dia da semana seguem com o MFIT.
- **Uso:** os dias aplicados substituem o gerador naquela data. Prontidão abaixo de 50 e semana da prova trocam pelo treino do gerador com o aviso; dor marcada depois tira os exercícios afetados. Os treinos do Claude de um plano saem quando o dia da semana deixa o plano ou o plano termina. Mudar só o foco de um dia que continua no plano mantém o treino do Claude, e o card do dia avisa "Montado para <foco do treino>. O plano agora pede <foco do plano>." (`StrengthPlanText.claudeFocusChanged`). "Voltar ao gerador" apaga o daquele dia. Treinos de dias passados são descartados.

## MCP de força

Arquivos: `server/src/mcp/*`, `server/src/mcpTokens.ts`, `App/Trainer/Claude/ClaudeSync*.swift`, `App/Trainer/Claude/ClaudeSettingsSection.swift`. Testes: `server/test/mcpRoute.test.ts`, `server/test/mcpStrengthValidator.test.ts`, `server/test/mcpTokens.test.ts`, `AppTests/ClaudeSyncTests.swift`.

- **Conexão:** Ajustes › Claude gera um token só do MCP (32 bytes, o servidor guarda só o hash). Gerar outro invalida o anterior; revogar apaga. Endpoint `https://training.aglv.dev/mcp`, JSON-RPC por HTTP, `Authorization: Bearer <token>`.
- **Ferramentas:** `contexto_forca` (pacote do app), `validar_treinos` (mesmas regras do app, com o catálogo do próprio contexto) e `salvar_treinos` (grava para o app revisar).
- **Sincronização:** o app sobe o contexto como preferência `strengthContext` ao abrir a Força e quando os dias de força mudam, só se o conteúdo mudou. O servidor grava a resposta como preferência `strengthClaude`. O app mostra "O Claude enviou treinos", valida de novo em Swift e só aplica quando o atleta confirma.
- **Limite:** 60 chamadas por minuto por token; corpo até 256 KB.
- **Paridade:** `server/test/fixtures/strength-catalog.json` é gerado do catálogo Swift, nas mesmas linhas compactas do pacote (`WRITE_FIXTURES=1 swift test --filter StrengthCatalogFixtureTests`); o teste em Swift falha se o catálogo mudar sem atualizar a fixture. O validador do servidor aceita o catálogo em linhas e também em objetos, formato que as versões anteriores do app mandam.
