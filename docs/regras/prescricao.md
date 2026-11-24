# Regras de prescrição

O que o treinador beta monta e como ajusta o plano. As regras de leitura dos treinos e da prontidão estão em [analise.md](analise.md).

Toda mudança em uma regra daqui atualiza este arquivo no mesmo commit.

Constantes: `Packages/TrainingKit/Sources/Insights/TrainerEngine*Constants.swift`. Testes: `Packages/TrainingKit/Tests/InsightsTests/Trainer*Tests.swift`.

## Princípios

- **Distância:** tudo é prescrito por distância. Aquecimento em km, blocos em km ou metros, recuperação em metros. Nunca "10 min".
- **Descanso entre blocos:** é a única exceção, em tempo, porque é parado e sem trote.
- **Aquecimento e desaquecimento:** aquecimento de 3 km, também depois de força de pernas, e sem desaquecimento. A exceção é o plano com "Ida e volta": o aquecimento pode ir a 5 km e entra uma volta leve de até 2 km (ver [Ida e volta](#ida-e-volta)).
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

## Zonas dos blocos

A zona de cada bloco é de FC, nas faixas do app (a partir do limiar do relógio: Z2 de 85%, Z3 de 90%, Z4 de 95% e Z5 no limiar). O pace continua o alvo principal do bloco; a zona mostra a FC esperada para ele. Arquivos: `Insights/TrainerZones*.swift`, `App/Workouts/ZoneChip.swift`, `App/Trainer/TrainerZoneGuideCard.swift`. Testes: `InsightsTests/TrainerZonesTests.swift`.

| Bloco | Zona | Pace da zona |
| --- | --- | --- |
| Descanso e trote | sem zona | trote |
| Aquecimento, rodagem, longão, volta leve | Z2 | rodagem ± 7 s/km |
| Pace-alvo e ritmo de prova | Z3 | ritmo de prova ± 3 s/km |
| Tempo e limiar | Z4 | limiar ± 3 s/km |
| VO2 e tiros curtos | Z5 | VO2 ± 3 s/km |

- **Treino planejado do Garmin:** a zona sai do alvo do passo: zona → ela mesma; FC → zona da média; pace → zona do ritmo do treinador mais próximo. Sem alvo, aquecimento e volta leve são Z2. A cor da barra e dos quadradinhos segue essa zona.
- **Onde aparece:** Hoje (lista de passos), Treinador › dia, detalhe do planejado ("Como fazer") e detalhe do treino feito (zona dominante ao lado da FC média). A semana do treinador, as listas e o mostrador ficam só com a cor.
- **Zonas e ritmos:** card na aba Treinador com FC, pace e uso de cada zona, e o pace real em cada zona de FC nas corridas dos últimos 42 dias (pelo menos 2 min na zona). Mostra um aviso quando o pace real fica mais de 8 s/km fora da faixa prescrita.

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
| Volume de partida | média das semanas normais das últimas 6: ficam de fora as que o plano marcou como recuperação, semana leve (fixa ou por sinais), polimento ou semana da prova, e as abaixo de 75% da mediana das outras (ou sem corrida). Com menos de 2 semanas normais, média simples das últimas 4 | `normalWindowWeeks`, `normalLowShare`, `volumeWindowDays` |
| Sugestão de volume | com avaliação do ciclo anterior, o volume dela. Sem avaliação: começa no volume de partida; o pico é o menor entre 1,25 × o começo, o fim da faixa confortável do número de corridas e o que dá para subir até a prova (5% por semana, recuperação a cada 4, sem contar a fase geral e o polimento). O card "Volume semanal" mostra a sugestão, o motivo e "Usar", e o formulário já abre com ela | `volumeSuggestion`, `defaultPeakShare` |
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
| Longão | até 150 min e até 30% da semana, mínimo de 10 km, sobe de 2 em 2 km; fica pelo menos 2 km acima de qualquer rodagem da semana | `longMaximumSeconds`, `longWeekShare`, `minimumLongMeters`, `longStep`, `easyLongGapMeters` |
| Teto do longão | o maior entre o teto da prova e 25% da semana. O teto pela semana para em 120 min de longão para prova até 15 km, 135 min até 30 km e 150 min acima ou sem distância | `longCaps`, `longVolumeShare`, `longTimeCaps` |
| Teto da prova | prova até 7,5 km: 14 km; até 15 km: 16 km; até 30 km: 22 km; acima: 32 km | `longCaps` |
| Maior longão do bloco | a cada 3 semanas de progressão, a segunda tem o maior longão: até 1,2 × o longão, 1,1 × o teto, 35% da semana e 150 min. As outras ficam em 85% dele | `longestGrowth`, `longestOverRaceCap`, `longestWeekShare`, `stimulusShare` |
| Média-longa | com 65 km ou mais na semana de progressão, a rodagem entre limiar e VO2 vira média-longa: 20% da semana, entre 14 e 16 km, no máximo 75% do longão | `mediumLongWeekMeters`, `mediumLongShare`, `mediumLongMinimumMeters`, `mediumLongMaximumMeters`, `mediumLongLongShare` |
| Semana da prova | trotes de 5 km | `raceWeekEasyMeters` |

## Nome do treino

Todo treino de corrida tem o nome no formato "tipo + distância total", igual no app e no Garmin: Rodagem, Opcional, Fartlek, Média-longa, Longão, Limiar, Tempo, Limiar progressivo, Ritmo de prova, VO2, Pace-alvo, Subidas e Prova, seguidos dos km do treino inteiro (aquecimento e volta leve incluídos). Ex.: "Limiar 11 km", "Longão 18 km". A estrutura (4 × 2 km, blocos, progressivo, tiros curtos) fica nos passos e no detalhe do treino. Ao carregar o plano, os treinos de hoje em diante recebem o nome nesse formato (`TrainerEngine.retitled`), e o envio troca os que já estão no Garmin. A força usa o foco (Superiores, Pernas, Corpo inteiro, Mobilidade e core, Mobilidade); o MFIT usa o nome do professor. `TrainerEngineText.title`.

## Ida e volta

Saiu do app: a opção não aparece mais em Dias da semana, e um plano que estava com ela é refeito sem as duas metades na primeira abertura do app depois da atualização (`TrainerModel.dropOutAndBack`), com os treinos reenviados ao Garmin como alterados. O motor ainda lê planos antigos com a opção; as regras abaixo descrevem esse comportamento antigo.

- **Corrida contínua:** rodagem, opcional, média-longa e longão em km par. O treino vai em duas metades iguais, e o relógio avisa na troca de passo. O longão arredonda para cima, ou para baixo se passar de 150 min ou de 35% da semana.
- **Treino com blocos:** limiar, VO2 e ritmo de prova terminam um tiro exatamente na metade. Para isso, o aquecimento cresce até 2 km ou entra uma volta leve de até 2 km no fim; escolhe o que precisar de menos, e no empate, a volta leve. Os blocos não mudam. Se nenhum tiro fecha a conta (tempo contínuo, por exemplo), a meia-volta fica no meio do bloco.
- **Exceções:** o trote da semana da prova fica em 4 km. A rodagem encurtada por pedido (dor, cansaço) pode ficar em km ímpar, mas a meia-volta continua na metade. Longão limitado depois de um longão falho arredonda para baixo.
- **No relógio e na tela Hoje:** as duas metades seguidas, com o mesmo alvo, contam como um bloco só. O treino continua contínuo, e o ajuste do dia encurta as duas metades por igual.
- **Volume:** o km a mais da qualidade sai das rodagens. Com as rodagens já no mínimo de 40 min, a semana pode passar até 2 km do planejado.
- **Longão em estágios, progressivo e com final forte:** a meia-volta cai no km da metade, dentro do bloco se for preciso.
- **Na tela:** a lista de passos mostra "Meia-volta: vire aqui" com o km, e o gráfico do treino tem um traço no ponto.
- **Edição do treino:** ao mudar a distância ou os tiros, a meia-volta é recalculada.

`TrainerEngineOutAndBack`, `outAndBackUnitMeters`, `outAndBackTailMaximumMeters`.

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
| Calor no longão | na hora habitual do longão (mesma regra do card "Treino de hoje", ver `analise.md`): ritmo + fator de calor (temperatura + sol, ponto de orvalho e adaptação às corridas quentes) × pace do longão; com fator de 0,045 ou mais, já com a adaptação, 1 km a menos de bloco. O card "Calor no longão" mostra as horas das 5h às 21h e deixa escolher outra para ver a condição e o pace na tela; o plano e o envio ao Garmin não mudam. Sugere uma hora entre 5h e 10h quando o ajuste cai pelo menos 3 s/km. Abaixo de 3 s/km, o calor é ignorado. Sem ponto de orvalho, sem ajuste | `TrainerHeat`, `TrainerHeatDayBuilder`, `heatBlockFactor`, `heatBlockReduction`, `RunWeatherConstants.minimumHeatSeconds` |
| Treino feito | pelo menos 90% do prescrito | `doneShare` |
| Longão falho | abaixo de 85% do prescrito; abaixo de 70%, o próximo longão fica 2 km menor | `longFailShare`, `longReduceShare`, `longReduceMeters` |
| Gel no longão | só em longão de pelo menos 15 km, 2 km antes do km em que o último longão quebrou | `gelMinimumMeters`, `gelBeforeFadeKm` |

## Avaliação do ciclo

Depois de pelo menos 4 semanas (`TrainerEngineCycleConstants.swift`):

- **Aumenta:** o volume sobe 8% se pelo menos 90% dos treinos foram feitos e a prontidão ficou estável, com tolerância de 3 pontos.
- **Reduz:** o volume cai 10% se menos de 75% dos treinos foram feitos ou se a prontidão caiu 8 pontos.

## Dias e volume

Constantes: `TrainerEngineDaysConstants.swift`. Testes: `TrainerDaysTests.swift`.

- **Faixa por número de corridas:** para cada número de corridas, a tela de dias mostra a faixa de volume semanal. O início é a semana com rodagens de 40 min (`easyMinimumSeconds`); o confortável vai até rodagens de 60 min (`easyComfortSeconds`); o limite usa rodagens de 75 min e longão de 150 min, o mesmo do pico possível.
- **Sugestão na escolha:** se o pico ficar fora do confortável, o texto indica o número de corridas mais próximo em que ele fica no confortável.
- **Um dia a mais:** na análise do ciclo, com o pico sugerido, se a rodagem média passar de 60 min, houver dia livre e a corrida a mais encurtar a rodagem ou fizer a semana caber mais do volume planejado, aparece "Um dia a mais de corrida?" com a semana atual e a semana com uma corrida a mais. "Ver com N" abre a edição dos dias já com a corrida a mais; nada muda sem salvar. "Manter" esconde a sugestão até o próximo ciclo.

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

- **Sem plano do treinador:** a força funciona do mesmo jeito no app (mas não vai para o relógio), guardada à parte (`TrainerStrengthStandaloneStore`) e levada para o plano quando ele é criado. O dia de corrida forte vem do nome do treino da assessoria no Garmin (`ExternalDayKind`): limiar, ritmo e tempo contam como limiar; VO2, intervalado, tiro e fartlek como VO2; longo, longão ou 18 km ou mais como longão; "prova" sem "ritmo" como prova. Semana de recuperação e semana da prova só se aplicam com plano.

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

- **O que vai:** do dia de hoje até o fim do plano de corrida (no mínimo os próximos 7 dias), por tipo (corrida, força ou os dois), com dias desmarcáveis. Força dos dias do treinador e, com "Enviar os treinos do MFIT" ligado, os do MFIT.
- **Corrida:** só entra com "Corrida do treinador" ligado. Enquanto a corrida vier da assessoria, fica desligado. Aquecimento e blocos por distância, alvo de pace e descanso parado por tempo. Com limiar no relógio, o aquecimento vai com alvo de FC em Z2, e rodagem, longão e blocos de tempo ou limiar de 2 km ou mais levam a faixa de FC da zona como segundo alvo. VO2 e tiros curtos ficam só com pace, porque a FC não chega à zona antes de o tiro acabar. Cada bloco vai como uma série só, "repetir N vezes (tiro + descanso)", com o descanso também depois do último tiro, para o bloco não se partir em dois no relógio. Se depois do bloco vier um descanso parado igual ou menor que o da série, ele não vai, porque a série já termina descansando. Com "Corrida do treinador" ligado, o app ignora os treinos que o Garmin marca como vindos da Treinus (`workoutProvider`): eles saem do Hoje, de Treinos, da nota, do mostrador e dos dias de corrida forte da força. No calendário do Garmin eles continuam.
- **Força:** cada exercício vira um grupo repetido pelo número de séries, com repetições ou tempo, descanso e carga em kg quando houver. A descrição vai sem acento.
- **Status:** novo (nunca enviado), mudou (o treino gerado ficou diferente do enviado) ou no Garmin.
- **Apagar o plano:** apaga do relógio as corridas e a força do treinador que o app enviou, de hoje em diante. Os treinos do MFIT ficam. Sem plano de corrida, a força do treinador não é enviada ao relógio.
- **Só o que o app criou:** o app guarda o id de cada treino que enviou e só substitui ou apaga esses. Treino que saiu do plano dentro desse período é apagado do Garmin. Ao abrir "Enviar ao Garmin" e antes do envio automático, o app confere o calendário do Garmin: treino enviado que não está mais lá (apagado no Garmin Connect ou no relógio) volta a "novo" e é enviado de novo.
- **Falhas:** se apagar no Garmin falhar (exceto "não encontrado"), o registro fica e o treino novo daquele dia não é criado, para não sobrar treino duplicado. Se o agendamento falhar, o treino recém-criado é apagado. Só um envio roda por vez, e ele não é cancelado ao sair da tela.
- **Envio automático:** desligado, só corrida, só força ou os dois. Quando ligado, roda ao abrir o treinador e quando o plano muda.
- **MFIT:** com "Enviar os treinos do MFIT" ligado (só no Garmin), entram os treinos do professor de hoje até o fim da prescrição do MFIT, ou 4 semanas à frente quando o programa não tem fim. No Garmin, todos os treinos vão só com o título (o do MFIT é o nome do treino do professor), sem prefixo. Cada exercício usa o exercício do catálogo da Garmin quando o nome do MFIT tem par no mapa `mfit` do `exercise-media.json`; sem par, vai com o nome do professor e a categoria que o parser do MFIT adivinha (`TOTAL_BODY` se nenhuma). Dia em que o Claude substituiu o MFIT fica de fora. Desligar a opção apaga do Garmin os treinos do MFIT que o app enviou. Testes: `AppTests/MFITSendTests.swift`.
- **Categoria da Garmin:** exercício sem par no catálogo vai com a categoria tirada do nome, traduzida para uma que a Garmin aceita (adução → `HIP_STABILITY`, cadeira extensora → `SQUAT`, crucifixo inverso → `FLYE`). Categoria fora do catálogo vira `TOTAL_BODY`; a Garmin recusa o treino inteiro (código 400) com uma categoria que não conhece. O mapa de músculos da força continua usando a categoria original.
- **Erro no envio:** o resultado mostra o motivo do primeiro erro: sessão do Garmin vencida, limite de envios ou o código que a Garmin devolveu.

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

## Força ao vivo

Arquivos: `Insights/LiveStrengthPlans*.swift`, `MFIT/MFITParser.swift` (`target(in:)`), `Insights/LiveStrengthSessionTypes.swift`, `Insights/LiveStrengthQueue*.swift`, `Insights/LiveStrengthReport*.swift`, `Insights/LiveStrengthWatch*.swift`, `Insights/LiveStrengthLive*.swift`, `Insights/LiveStrengthUpload*.swift`, `Widgets/StrengthLive*.swift`, `App/Strength/WatchLink/`, `GarminAPI/ExerciseSetsUpload*.swift`, `ForcaApp/`. Testes: `InsightsTests/LiveStrengthPlansTests.swift`, `LiveStrengthQueueTests.swift`, `LiveStrengthReportTests.swift`, `LiveStrengthWatchTests.swift`, `LiveStrengthLiveTests.swift`, `LiveStrengthUploadTests.swift`, `MFITTests/MFITTargetTests.swift`, `GarminAPITests/ExerciseSetsUploadTests.swift`. No relógio: `ForcaApp/source/SessionQueue.mc`, testes em `ForcaApp/test/` (`ForcaApp/test-local.sh`).

- **Treino do relógio:** o treino do dia, do MFIT ou do treinador, vira uma lista de blocos. No MFIT, cada bloco do professor é um bloco, e bloco com mais de um exercício é bi-set (A1 → A2 sem descanso, descanso no fim da rodada). No treinador, cada exercício é um bloco. Ids estáveis: `b1`, `b1e1`, `b1e2`.
- **Tipo da série:** com segundos e sem repetições, é por tempo. "cada lado", "cada perna", "cada braço", "por lado" ou "unilateral" na instrução do MFIT marcam unilateral, e os dois lados contam como uma série. No bi-set do MFIT, o alvo e o unilateral saem da instrução do bloco, porque o professor escreve uma só para a dupla. Peso corporal ("PC"): no treinador, vem do equipamento do catálogo, e a carga planejada é a do treino ou a sugerida; no MFIT, a carga planejada é a do professor e, sem ela (o bi-set do MFIT não traz carga), a da última série com carga da última vez; sem nenhuma das duas, é peso corporal.
- **Última vez:** quando a última vez só tem a carga, aparece "23 kg". A chave de carga é o id do catálogo (`CATEGORIA/EXERCICIO`) no treinador e a mesma chave do histórico do MFIT (`MFITParser.exerciseKey`: nome sem o trecho entre parênteses, sem acento e em minúsculas) no MFIT. A carga real volta pela mesma chave: no treinador, para a progressão; no MFIT, para o histórico de cargas do MFIT.
- **Eventos:** o relógio manda cada ação como evento com id e número de sequência: série feita, ajuste de uma série, pular, fazer agora e deixar de fora. O estado sai de aplicar os eventos em ordem de sequência; evento repetido (mesmo id) conta uma vez, e evento atrasado entra na posição certa.
- **Próxima série:** no bloco atual, o exercício com menos séries feitas (empate: a ordem do bloco). A carga planejada é a da última série feita daquele exercício; sem série feita, a do plano. Ajustar a carga de uma série muda o plano das seguintes.
- **Pular · fazer depois:** o bloco vai para o fim da fila com as séries que faltam e entra na fila pendente. Parar um exercício no meio usa o mesmo pular.
- **Fazer agora:** o bloco escolhido sai da fila pendente e entra no lugar do atual, e o atual vai para o fim e para a fila pendente. No exercício que já é o atual (o pendente que voltou no fim do treino), ele só sai da fila pendente.
- **Deixar de fora:** o bloco sai da fila pendente e o que foi feito fica registrado.
- **Resumo:** volume = repetições × carga (unilateral conta os dois lados; peso corporal conta 0). A variação compara só os exercícios que têm última vez e alguma série feita hoje, com o mesmo conjunto dos dois lados. Séries feitas contra as planejadas. "Fora do plano" conta as séries com repetições (ou segundos) diferentes do alvo.
- **Chip por exercício:** carga máxima feita acima da planejada → "+X kg"; abaixo → "−X kg"; mesma carga e repetições abaixo do total planejado → "−N reps"; exercício sem nenhuma série feita (deixado de fora, esquecido na fila ou não alcançado antes de salvar) → "pulado"; senão, "=". Carga diferente ganha das repetições.
- **Carga real:** a carga registrada de cada exercício é a da última série com carga, com "todas as séries fechadas" quando fez todas as séries com pelo menos as repetições do alvo. No treinador, esse registro alimenta a progressão e a carga sugerida do próximo treino; no MFIT, vai para o histórico de cargas do MFIT.
- **Relógio:** o `trAIning Força` guarda o treino do dia e roda sem o iPhone. Botões: o de baixo (LAP no 965) conclui a série e pula o descanso; o de cima (START) pausa com Retomar / Salvar / Descartar; UP/DOWN ou deslizar troca a visão (série, exercício, treino), que volta sozinha à principal em 8 s; no descanso, UP/DOWN abre o ajuste da série que acabou, em que START passa de campo e grava e o botão de baixo cancela; segurar UP (ou o botão de baixo no Venu 3) abre "Fazer agora" e "Pular · fazer depois". O ajuste de carga anda de 2,5 kg; de repetições, 1; de tempo, 5 s. O descanso vibra com dois pulsos aos 10 s e três no zero, e no zero o relógio vai sozinho para a próxima série (a série por tempo espera o botão para começar a contagem). Se o ajuste estiver aberto no zero, o relógio vai para a série quando o ajuste fecha. Bi-set vai de A1 para A2 sem descanso. Na série por tempo, o botão de baixo começa a contagem e a série fecha sozinha no zero. Pausar congela o descanso e a contagem.
- **Eventos do relógio:** cada ação vira um evento `{id, sequence, action}` com o id `<início do treino>-<sequência>`, no formato que `LiveStrengthQueue.decodeWatchEvents` lê (início da série em segundos desde 1970). Os eventos e as séries ficam no armazenamento do relógio a cada série.
- **Treino para o relógio:** depois de cada sync e sempre que o app abre, o iPhone manda ao relógio o treino de força de hoje e o de amanhã (`LiveStrengthWatch.message`). O MFIT do dia vem primeiro, a não ser que o treinador tenha trocado o dia; sem MFIT, vai o do treinador. A última vez do MFIT é o registro de cargas mais recente antes do dia do treino. Cada plano leva uma versão (hash do conteúdo), e o iPhone guarda os planos enviados por versão só depois que o relógio confirma o recebimento; o envio e a confirmação são por relógio. Ao abrir, o app de força no relógio pede o treino do dia (`needPlans`), e o iPhone reenvia na hora, porque uma mensagem que chega com o app fechado se perde. No início do treino, o relógio manda a versão do plano que está usando e o próprio plano. O iPhone monta a sessão com o plano daquela versão; se não conhece a versão, monta com o plano que veio do relógio, completando categoria e chave de carga pelo nome do exercício. Sem nenhum dos dois (treino de exemplo do build de debug), o iPhone não monta sessão e não envia séries ao Garmin. Se chegar série sem sessão aberta, o iPhone pede ao relógio (`resync`), no máximo uma vez a cada 30 s, que reenvie o início e as séries. O iPhone só reenvia quando o conteúdo muda. O relógio guarda os dois e abre o do dia; se o treino ainda não começou, troca na hora.
- **Canal relógio ↔ iPhone:** Bluetooth pelo Connect IQ Mobile SDK. O relógio manda cada evento na hora, em lotes de até 10, e repete a cada 5 s até o iPhone confirmar (`ack` com a maior sequência recebida, enviado só depois que o iPhone consegue ler o lote). No início do treino, o relógio avisa o iPhone, que mostra a notificação "Treino de força começou" quando o app não está na tela. Com o app fechado pelo sistema, o iOS relança o app pelo Bluetooth; fechado pelo usuário, os eventos esperam no relógio até o app abrir.
- **Live Activity:** o relógio manda a fase (série, descanso, fim do descanso, pausa), a FC e o fim do descanso quando a fase muda e a cada 15 s. O iPhone junta isso com os eventos (`LiveStrengthLive.card`): fazendo mostra a próxima série com o alvo, a última vez e as séries do exercício; descanso mostra a série feita, a próxima e a contagem; fim do descanso mostra o tempo extra ("+0:22"). O card da aba Hoje mostra os números do treino num card e, em outro, o exercício da vez com uma faixa do momento (fazendo, descanso ou hora da série). O topo traz as séries do treino e a FC. O iOS só deixa criar o Live Activity com o app na tela: ele aparece quando o app abre (pela notificação de início ou à mão) e fecha quando todas as séries terminam.
- **Card Relógio:** no dia com treino de força, antes de o treino começar, Treinador › Força abre com o card "Relógio": com o treino de hoje já confirmado pelo relógio (a versão do plano de hoje está entre os planos entregues), "salvo no relógio · funciona sem o iPhone" e como começar; sem confirmação, "ainda não chegou ao relógio" e "Enviar de novo", que reenvia a todos os relógios; sem relógio escolhido, "Escolher relógio". O card some quando o treino começa ou depois do resumo do dia.
- **Tela ao vivo:** durante o treino, Treinador › Força abre com o acompanhamento (`LiveStrengthLive.screen`): tempo, FC e séries do treino; o exercício da vez em dois cards, o momento (fazendo com o alvo, descanso com a contagem ou hora da série) e as séries em tabela Série / Feito / Plano / Última (repetição abaixo do alvo ou carga diferente do plano em amarelo, a próxima com contorno lime); e os outros exercícios em três seções: "A seguir" (na ordem da fila), "Para depois" (os pulados, com quantas séries faltam e "Fazer agora") e "Feitos" (recolhida, abre com um toque). Os exercícios são numerados em sequência. No bi-set, o card Agora mostra a rodada inteira ("Bi-set B · rodada 2 de 4", B1 + B2 e o descanso no fim) e a tabela vira Rodadas, uma coluna por exercício; o bi-set não se repete em A seguir. Na lista, o bi-set aparece agrupado ("BI-SET A · 3 rodadas · desc. 0:45", com A1 e A2 e as rodadas feitas). A aba Hoje mostra um card "Ao vivo · Força" com o mesmo resumo, que abre essa tela. Os dois somem quando todas as séries terminam ou 4 h depois do início.
- **Ações no iPhone:** na tela ao vivo, o card Agora tem "↻ Pular · fazer depois" e cada pulado da lista tem "Fazer agora". Com séries já feitas, pular pede confirmação dizendo quantas vão para o fim. O iPhone só manda o pedido (`command`); o relógio aplica com as mesmas regras do menu dele (pular só o exercício da vez, nada durante a pausa) e devolve o evento, e a tela mostra "Relógio atualizado" quando o evento volta. Com o relógio desconectado, os botões ficam apagados. Concluir, ajustar, pausar e salvar continuam só no relógio.
- **Carga pelo iPhone:** um toque no exercício (no card Agora ou em A seguir) abre o ajuste: carga em passos de 2,5 kg, "Peso corporal" e se vale para as séries que faltam ou só para a próxima. O iPhone manda o pedido (`setWeight`); o relógio aplica, grava o evento e devolve. A carga pedida passa na frente da carga da última série feita; "só a próxima" vale para uma série. Ajustar a carga de uma série no relógio desfaz o pedido. Peso corporal fica guardado pela chave de carga e vale para os próximos treinos com o exercício (o plano enviado ao relógio sai sem carga).
- **Correção depois do treino:** no resumo, um toque no exercício abre as séries feitas para corrigir repetições e carga. A correção entra como ajuste da série, atualiza o resumo, a carga do próximo treino e o histórico de cargas, e reenvia as séries para a mesma atividade no Garmin Connect, que já é do app.
- **Séries no Garmin Connect:** o Garmin conta séries pelos registros de série do `.FIT`, que um app Connect IQ não grava. Ao salvar, o relógio avisa o iPhone (`finished`, com duração e FC média). O iPhone procura nas últimas atividades a de força que começou até 3 min do início no relógio (`LiveStrengthUpload.match`), confere que ela não tem nenhuma série e envia as séries com os descansos entre elas (`LiveStrengthUpload.sets`, `PUT /activity-service/activity/{id}/exerciseSets`): início em UTC, duração, repetições e carga em gramas. O envio troca a lista inteira, por isso atividade que já tem série nunca recebe o envio. Como a atividade leva um tempo para chegar ao Garmin Connect, o iPhone tenta de novo depois de 1, 2 e 5 min, a cada sync e ao abrir o app, por até 24 h. Com as séries enviadas, a carga de cada série com carga vai para o histórico de cargas (`LiveStrengthReport.realLoads`), marcada como do relógio e ligada à atividade, para não ser importada de novo: no MFIT pela chave do MFIT, no treinador pela chave do nome, que a progressão do treinador lê pelo catálogo. A atividade no Garmin leva o nome do treino ("Superiores").
- **Resumo:** depois de salvar, Treinador › Força mostra o resumo do dia: volume e variação contra a última vez, duração e FC média, séries feitas contra as planejadas e quantas ficaram fora do plano, e cada exercício com as repetições (abaixo do alvo em amarelo), a carga e o chip da mudança. No fim, o card "Próximo <treino> · <dia>" mostra a próxima vez do mesmo treino (até 14 dias) e a carga de cada exercício com carga pela progressão do treinador: com todas as séries fechadas, "sobe para" (+2,5%, no mínimo 1 kg); sem fechar, "fica em" (`LiveStrengthReport.nextLoads`).
- **Carga do próximo treino:** ao salvar, a próxima carga de cada exercício fica guardada pela chave de carga. No envio ao relógio, o treino do treinador usa essa carga; o do MFIT usa a maior entre a do professor e a guardada, para não desfazer uma subida do professor.
