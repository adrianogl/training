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
| Calor de 24 °C ou mais | ritmo + 5 s/km | `heatThreshold`, `heatPaceOffset` |
| Calor de 28 °C ou mais | ritmo + 10 s/km e 1 km a menos de bloco | `heatStrong`, `heatStrongPaceOffset`, `heatBlockReduction` |
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
- **Foco do dia do treinador:** superiores, pernas, corpo inteiro ou mobilidade e core, com intensidade (leve, moderada, pesada), duração e local (academia, casa, só peso do corpo). Pernas moderada ou pesada e corpo inteiro pesado contam como dia de perna pesada.

### Sugestão de dias e foco

Arquivo: `Insights/StrengthSessions.swift`. Testes: `InsightsTests/StrengthDayTests.swift`.

| Situação | Foco sugerido |
| --- | --- |
| Semana com dias do MFIT | mobilidade e core, leve, 25 min, para complementar o professor |
| Dia de qualidade (limiar, VO2, longão, prova) ou véspera | mobilidade e core, leve, 25 min |
| Qualidade em 2 dias, ou perna pesada já na semana | superiores, moderada |
| Sem qualidade nas 48 h seguintes | pernas, pesada |

### Treino gerado

Arquivos: `Insights/StrengthGenerator.swift`, `Insights/StrengthCatalog.swift`, `Insights/StrengthProgression.swift`. Constantes: `StrengthGeneratorConstants`. Testes: `InsightsTests/StrengthGeneratorTests.swift`, `StrengthCatalogTests.swift`.

- **Catálogo:** só exercícios do catálogo, todos com a categoria do Garmin. Sem nome de exercício confirmado no Garmin, vai a categoria e o nome na descrição.
- **Duração:** o treino fecha na duração escolhida com 5 min de tolerância. Com poucos exercícios disponíveis, sobe até 4 séries a mais por exercício.
- **Dia de qualidade:** pernas ou corpo inteiro viram mobilidade e core, leve. Superiores e mobilidade ficam como estão. "Manter original" desfaz.
- **Semana de recuperação:** duração e séries a 70%.
- **Semana da prova:** nos 3 dias antes da prova, sem força; de 4 a 7 dias antes, só mobilidade, 15 min.
- **Prontidão abaixo de 50:** só mobilidade, 20 min. "Manter original" desfaz.
- **Dor marcada:** sai todo exercício que carrega a região (joelho, panturrilha e aquiles, lombar, quadril, ombro). Sem nada que sobre, cai para mobilidade.
- **Complemento ao MFIT:** padrões de movimento que o MFIT já trabalhou na semana vão para o fim da fila.
- **Progressão de carga:** com a última carga registrada e todas as séries fechadas, sobe 2,5% arredondado, no mínimo 1 kg. Sem fechar as séries, repete a carga. Sem histórico, sem carga sugerida.
- **Séries e repetições:** principal com barra ou máquina pesada 4 × 6 (150 s), moderada 3 × 10 (90 s), leve 2 × 12 (60 s); acessório pesado 3 × 8, moderado 3 × 10, leve 2 × 12; panturrilha 2–3 × 10–12; pliometria 3 × 6 (90 s); core 2–3 × 10–12 ou 30–45 s; mobilidade 2 × 8 por lado.

## Envio ao Garmin

Arquivos: `GarminAPI/GarminPlannedPayload.swift`, `App/Trainer/Send/*`. Testes: `GarminAPITests/GarminPlannedUploadTests.swift`, `AppTests/TrainerSendTests.swift`.

- **O que vai:** os próximos 7 dias, por tipo (corrida, força ou os dois), com dias desmarcáveis. Força só dos dias do treinador; os do MFIT seguem pelo fluxo do MFIT.
- **Corrida:** só entra com "Corrida do treinador" ligado. Enquanto a corrida vier da assessoria, fica desligado. Aquecimento e blocos por distância, alvo de pace e descanso parado por tempo.
- **Força:** cada exercício vira um grupo repetido pelo número de séries, com repetições ou tempo, descanso e carga em kg quando houver. A descrição vai sem acento.
- **Status:** novo (nunca enviado), mudou (o treino gerado ficou diferente do enviado) ou no Garmin.
- **Só o que o app criou:** o app guarda o id de cada treino que enviou e só substitui ou apaga esses. Treino que saiu do plano dentro dos 7 dias é apagado do Garmin.
- **Falhas:** se apagar no Garmin falhar (exceto "não encontrado"), o registro fica e o treino novo daquele dia não é criado, para não sobrar treino duplicado. Se o agendamento falhar, o treino recém-criado é apagado. Só um envio roda por vez, e ele não é cancelado ao sair da tela.
- **Envio automático:** desligado, só corrida, só força ou os dois. Quando ligado, roda ao abrir o treinador e quando o plano muda.

## Força nos avisos

- **Aviso da manhã:** depois da prontidão, cita a força do dia de qualquer fonte: "Força: MMII." para o MFIT e "Força: mobilidade e core, 25 min." para o treinador. Quando uma regra mudou o treino do treinador (dia de qualidade, recuperação, prova ou prontidão), vira "Força ajustada:". Dia sem força ou nos 3 dias antes da prova não cita nada (`MorningStrengthText`).
- **Relatório de domingo:** o bloco de força mostra as sessões feitas contra as planejadas por fonte, como "MFIT 3 de 3 · Treinador 1 de 2", quando a semana tem dias do treinador (`StrengthTally`).
