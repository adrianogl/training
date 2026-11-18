# Regras de análise

Como o app lê um treino feito, a prontidão do dia e o texto que mostra sobre eles. As regras de prescrição estão em [prescricao.md](prescricao.md).

Toda mudança em uma regra daqui atualiza este arquivo no mesmo commit.

A análise roda em dois lugares, que precisam ficar iguais:

- **App:** pacote `Packages/TrainingKit` (módulos `WorkoutAnalysis`, `Insights`, `Narrative`, `Metrics`).
- **Servidor:** `server/src/analysis`, usado pelo app web em `activityRoutes.ts`.

## Prontidão do dia

| Regra | Valor | Onde |
| --- | --- | --- |
| Pesos da nota | HRV 35%, sono 25%, Body Battery 20%, carga 20% | `Metrics/ReadinessConstants.swift` |
| Componente que falta | sai da média e os pesos dos outros são redistribuídos | `Metrics/Readiness.swift` |
| Mínimo para ter nota | HRV ou sono | `Metrics/Readiness.swift` |
| HRV | 0 abaixo da faixa baixa, 0 a 60 até a faixa equilibrada, 60 a 100 dentro dela | `hrvComponent` |
| Carga (aguda/crônica) | 100 entre 0,8 e 1,3; cai até 0 em 0,5 e em 1,8 | `loadComponent` |
| Veredito | ≥ 70 forte, ≥ 40 moderado, abaixo disso descanso | `readinessVerdict` |
| Média pessoal | 30 dias, com pelo menos 14 dias de dado | `ReadinessConstants` |

| Sem dados de hoje | usa a nota de ontem, avisando "de ontem", e não manda essa nota ao relógio nem ao treinador | `todaySummary` |
| Noite sem dados | já tem dado do dia (Body Battery ou estresse), passou das 10h e não veio HRV nem sono: o Hoje mostra "Sem dados desta noite", o relógio mostra "SEM DADOS", e o treinador e o aviso da manhã não usam a prontidão. A nota do Garmin, que conta o sono como zero, também não entra | `InsightsConstants.missingNightHour` |

Testes: `MetricsTests/ReadinessTests.swift`, `ReadinessBreakdownTests.swift`, `InsightsTests/MissingNightTests.swift`.

## Zonas de FC no Garmin

As zonas de corrida do app partem do limiar do relógio: Z2 a partir de 85%, Z3 90%, Z4 95% e Z5 no limiar. Depois de cada sincronização, se o limiar mudou ou se as zonas de corrida do Garmin estão diferentes, o app grava essas faixas no Garmin, com o interruptor "Manter iguais às do app" em Ajustes › Garmin. Só mexe no perfil de corrida, e o início da Z1 continua o do Garmin. Depois de gravar, o app lê de volta e avisa se não bater. Arquivos: `GarminAPI/HeartRateZoneProfiles.swift`, `App/Garmin/GarminZonesModel.swift`. Testes: `GarminAPITests/HeartRateZoneProfilesTests.swift`.

## Divisão do treino em blocos e voltas

| Regra | Valor | Onde |
| --- | --- | --- |
| Pausa | intervalo de mais de 10 s andando a menos de 0,5 m/s | `AnalysisConstants.pauseGapSeconds`, `pauseMaximumSpeed` |
| Bloco dividido por km | bloco de pelo menos 3 km ou 15 min | `splitBlockMinimumDistance`, `splitBlockMinimumSeconds` |
| Volta cheia | pelo menos 500 m | `fullLapMinimumDistance` |
| Regras de volta | só em bloco ativo com pelo menos 3 voltas cheias | `minimumFullLaps` |
| Bloco completo | 95% do prescrito | `completionRatio` |

Testes: `WorkoutAnalysisTests/BlocksTests.swift`, `KilometersTests.swift`, `ContinuityTests.swift`.

## Itens da análise do treino

Arquivo: `WorkoutAnalysis/Assessment.swift`. Constantes: `WorkoutAnalysis/AnalysisConstants.swift`. Testes: `WorkoutAnalysisTests/AssessmentTests.swift`.

| Item | Grupo | Quando aparece |
| --- | --- | --- |
| Blocos no alvo | bom | pelo menos um bloco com alvo ficou no alvo |
| Ritmo constante | bom | volta mais lenta e mais rápida do bloco a no máximo 6 s/km, no equivalente no plano |
| FC menor que antes | bom | mesmo bloco do treino anterior, FC 3 bpm menor com velocidade dentro de 2% |
| Boa recuperação | bom | FC cai pelo menos 25 bpm do pico do bloco até a média da recuperação |
| Fora do alvo | corrigir | bloco mais rápido, mais lento, acima ou abaixo do alvo |
| Incompleto | corrigir | bloco abaixo de 95% do prescrito, ou não feito |
| Perda de ritmo | corrigir | última volta pelo menos 8 s/km mais lenta que a mediana das voltas do bloco, no equivalente no plano; se houve desnível, cita a subida da última volta |
| Ritmo mais lento nas subidas | esperado | km seguidos em que a subida deixou o ritmo pelo menos 3 s/km mais lento que o equivalente no plano |
| Ritmo mais lento pelo calor ou pelo frio | esperado | bloco com alvo de ritmo que ficou no alvo pelo equivalente em clima ameno (ver Temperatura) |
| Ritmo mais rápido na descida | esperado | km seguidos em que a descida deixou o ritmo pelo menos 3 s/km mais rápido que o equivalente no plano |
| Deriva cardíaca | atenção | FC do último terço 5% acima do primeiro terço, com velocidade variando até 2%. No calor, vai para esperado (ver Temperatura) |
| Zona acima | atenção | aquecimento ou desaquecimento com zona dominante 3 ou mais. Recuperação entre blocos não entra: a FC depois de um tiro não depende só do atleta, mesmo parado |
| Forte com prontidão baixa | atenção | treino forte com prontidão abaixo de 50 |
| Carga alta | atenção | carga aguda/crônica acima de 1,5 |

Quando um bloco fica incompleto, a análise procura a causa e cita só o que encontrou:

- **Queda de ritmo:** o primeiro km pelo menos 8 s/km mais lento que a média dos 3 primeiros km, e que continua lento até o fim, no equivalente no plano.
- **FC subindo:** a FC média dos 3 últimos km pelo menos 3 bpm acima da dos 3 primeiros.
- **Pausas:** quantas houve, em que km começou a primeira e o tempo parado. A dica "beba água ou tome gel" só aparece em treino planejado de pelo menos 15 km.
- **Prontidão:** abaixo de 50.
- **Carga:** aguda/crônica acima de 1,5.

## Acima do esperado

Arquivo: `WorkoutAnalysis/AboveExpected.swift`. Constantes: `WorkoutAnalysis/AnalysisConstants.swift`. Testes: `WorkoutAnalysisTests/AboveExpectedTests.swift`.

Compara o treino com a média dos treinos iguais usados na nota (até 4). Precisa de pelo menos 2 (`aboveExpectedMinimumComparisons`). Ritmo acima do alvo nunca conta aqui: continua em "corrigir".

| Sinal | Quando aparece | Constante |
| --- | --- | --- |
| FC no mesmo ritmo | FC média dos blocos ativos pelo menos 3 bpm menor que a média dos treinos iguais, com velocidade igual ou até 2% menor | `aboveExpectedHeartRateMargin`, `sameSpeedTolerance` |
| Queda de FC na recuperação | queda média do pico do bloco até a recuperação de pelo menos 25 bpm e 5 bpm maior que a média dos treinos iguais | `goodRecoveryDrop`, `aboveExpectedRecoveryMargin` |

Quando um sinal aparece, o item equivalente sai do grupo "bom": "FC menor que antes" no primeiro, "Boa recuperação" no segundo.

## Subida e descida

Arquivos: `WorkoutAnalysis/Elevation*.swift`, `server/src/analysis/elevation.ts`. Testes: `WorkoutAnalysisTests/ElevationPaceTests.swift`, `server/test/elevation.test.ts`.

| Regra | Valor | Constante |
| --- | --- | --- |
| Fonte | altitude que o relógio grava, somada por km | `ElevationCounter` |
| Ruído do altímetro | só conta mudança de pelo menos 2 m | `elevationNoise` |
| Desnível que conta | pelo menos 5 m de subida ou de descida no km | `elevationMinimum` |
| Custo da subida | cada 1% de subida deixa o ritmo 3,3% mais lento | `climbCost` |
| Ajuda da descida | cada 1% de descida deixa o ritmo 1,8% mais rápido | `descentGain` |
| Citar o km | efeito de pelo menos 3 s/km | `elevationEffectSeconds` |

Equivalente no plano = ritmo ÷ (1 + 3,3 × subida/distância − 1,8 × descida/distância). Ritmo constante, perda de ritmo, causa de bloco incompleto e, na análise detalhada, queda a partir do km X e saída rápida usam o equivalente no plano. A análise detalhada também passa os km com desnível para o texto do treinador. As voltas curtas de tiros não têm o desnível calculado e seguem pelo ritmo real.

## Temperatura

Arquivos: `TrainingCore/RunWeather*.swift`, `WorkoutAnalysis/WeatherBlocks.swift`, `server/src/analysis/weatherEffect.ts`. Testes: `TrainingCoreTests/RunWeatherTests.swift`, `WorkoutAnalysisTests/WeatherAnalysisTests.swift`, `server/test/weatherEffect.test.ts`.

| Regra | Valor | Constante |
| --- | --- | --- |
| Fonte | Open-Meteo, na coordenada da largada arredondada a 0,1°, média das horas que o treino cobre. Até 85 dias, endpoint de previsão; antes disso, arquivo | `ActivityWeatherConstants`, `WEATHER` |
| Treinos preenchidos | corridas ao ar livre dos últimos 120 dias, até 40 consultas por sincronização; falha tenta de novo depois de 6 h. Esteira e treino sem GPS ficam sem clima | `backfillDays`, `requestsPerRefresh`, `retryInterval` |
| Calor | soma temperatura + ponto de orvalho em °F: até 100 nada; 110 0,5%; 120 1%; 130 2%; 140 3%; 150 4,5%; 160 6%; 170 8%; 180 ou mais 10%, interpolando | `RunWeatherConstants.heatBands`, `HEAT.bands` |
| Frio | só a temperatura, de 5 °C para baixo: 0 °C 0,5%; −5 °C 1%; −10 °C ou menos 2% | `coldBands` |
| Equivalente em clima ameno | ritmo ÷ (1 + ajuste) | `WeatherAdjustment.mildPace` |
| Bloco com alvo de ritmo | mais lento que o alvo, mas dentro dele no equivalente em clima ameno, conta como no alvo e gera "Ritmo mais lento pelo calor" (ou "pelo frio") no grupo esperado. Mais rápido continua fora do alvo | `adjustForWeather` |
| Deriva cardíaca | com calor de pelo menos 2%, sai de atenção e vai para esperado, citando os graus | `driftHeatFactor` |
| Zona acima | com calor de pelo menos 3%, o limite do aquecimento e do desaquecimento sobe de Z3 para Z4 | `zoneHeatFactor` |
| Perda de ritmo | com calor de pelo menos 3%, o texto cita o calor | `fadeHeatFactor` |
| Custo, FC menor que antes, Acima do esperado | velocidade de cada treino ajustada pelo clima daquele treino | `WorkoutBlock.weatherSpeed` |
| Alvo de FC | não muda | — |

| Sol | radiação solar média das horas do treino, de 0 a 800 W/m², soma de 0 a 4 °C à temperatura do ajuste de calor; "sol forte" a partir de +2 °C | `fullSunRadiation`, `fullSunBoost`, `sunnyBoost` |
| Adaptação ao calor | cada corrida com calor de pelo menos 2% nos 14 dias anteriores tira 5% do ajuste de calor, até 40% | `hotSessionFactor`, `adaptationPerSession`, `maxAdaptation` |

O detalhe da corrida mostra os graus, o ponto de orvalho, o sol, a adaptação e o ajuste. Sem clima, a análise fica como antes. O clima de cada treino tem versão (`weatherVersion`); a versão 2 trouxe vento e sol, e os treinos dos últimos 120 dias são consultados de novo.

## Vento

Arquivos: `WorkoutAnalysis/Wind.swift`, `WorkoutAnalysis/AssessmentConditions.swift`, `server/src/analysis/conditions.ts`. Testes: `WorkoutAnalysisTests/ConditionsAnalysisTests.swift`, `server/test/conditions.test.ts`.

| Regra | Valor | Constante |
| --- | --- | --- |
| Fonte | vento a 10 m do Open-Meteo, média das horas do treino (direção pela média dos vetores) | `ActivityWeatherConstants.fields` |
| Altura de quem corre | vento a 10 m × 0,75 | `windHeightFactor` |
| Direção do trecho | pelas posições do FIT, a cada 5 m percorridos | `minimumHeadingMeters` |
| Custo | 0,25% × (m/s contra)²; a favor devolve metade | `headwindCost`, `tailwindShare` |
| Bloco com alvo de ritmo | o ajuste do vento soma ao do clima: mais lento que o alvo e dentro dele sem o vento conta como no alvo | `WorkoutBlock.conditionsFactor` |
| Item "Vento contra do km X ao Y" | km seguidos com efeito de pelo menos 3 s/km, no grupo esperado | `windEffectSeconds` |
| Km a km | seta, velocidade na altura de quem corre e ritmo sem vento quando o efeito passa de 3 s/km, contra ou a favor | `KilometerWindBuilder` |

## Largada e véspera

Arquivos: `App/Workouts/Detail/DayConditionBuilder.swift`, `WorkoutAnalysis/AssessmentConditions.swift`, `Narrative/NarrativeConditions.swift`, `server/src/analysis/conditions.ts`.

Entram como "Causa provável" em fora do alvo (mais lento ou FC acima), incompleto, perda de ritmo e deriva fora do calor. Não mudam a nota nem o grupo do item.

| Sinal | Quando conta | Constante |
| --- | --- | --- |
| Sono | menos de 6 h, ou nota abaixo de 60 | `shortSleepSeconds`, `lowSleepScore` |
| HRV | última noite abaixo da faixa equilibrada | — |
| Body Battery | máximo da manhã abaixo de 40 | `lowBodyBattery` |
| Véspera | tiros, limiar ou longão no dia anterior; no app, também dia de pernas no MFIT (pelo menos 50% das séries em pernas). O servidor não tem os treinos do MFIT e olha só a corrida | `PreviousDayLoad` |

## Dinâmica de corrida

Arquivos: `WorkoutAnalysis/AssessmentConditions.swift`, `server/src/analysis/conditions.ts`.

| Regra | Valor | Constante |
| --- | --- | --- |
| Fonte | cadência e tempo de contato com o solo do FIT, em blocos de 5 s | `FITSample.cadence`, `stanceTime` |
| Onde | bloco ativo de pelo menos 15 min; em corrida livre, o treino inteiro | `formMinimumSeconds` |
| Comparação | último terço contra o primeiro, com o ritmo igual ou até 2% mais lento | `formSpeedTolerance` |
| Item "Forma caindo no fim" (atenção) | cadência caindo pelo menos 3 passos/min ou contato com o solo subindo pelo menos 4% | `cadenceDrop`, `stanceRise` |

A versão 4 do processamento do FIT passou a guardar a cadência, o contato com o solo e a posição de cada bloco de 5 s. Só as corridas dos últimos 120 dias são processadas de novo (`SyncConstants.reprocessWindowDays`).

### Previsão das provas

Arquivos: `App/Races/Weather/`, `Reports/ReportBuilder.swift`. Testes: `AppTests/RunWeatherTests.swift`.

- Os esforços que alimentam a previsão (melhor 1 km, melhor 5 km, sessões de limiar e VO2, provas) entram pelo equivalente em clima ameno.
- Prova com horário de largada e local (primeiro ponto do GPX ou a cidade, convertida em coordenada no aparelho) mostra a previsão no clima do dia, nas horas da largada até a chegada prevista.
- Até 16 dias antes vale a previsão do tempo, guardada por 3 h. Antes disso, a média das mesmas horas e data nos últimos 5 anos, guardada por 24 h (`RaceWeatherConstants`).
- A estratégia de ritmo por km usa o tempo-alvo ajustado só quando há previsão do tempo.

## Provas do Garmin

Arquivos: `GarminAPI/GarminRaceEvents*.swift`, `App/Races/Garmin/`. Testes: `GarminAPITests/GarminRaceEventsTests.swift`, `AppTests/GarminRaceSuggestionTests.swift`.

- Fonte: eventos de prova de corrida (`itemType` "event", `isRace`) do calendário do Garmin nos próximos 12 meses, lidos ao abrir a tela Provas, com cache de 1 h. Eventos repetidos entre meses são juntados pelo id.
- Vêm nome, data, horário de largada, distância e percurso, quando o Garmin tem. A prioridade entra como C; meta e cidade ficam com o atleta.
- Sugestão: só aparece se não houver prova no app no mesmo dia com distância até 10% diferente, e se o evento não foi importado nem ignorado.
- Adicionar abre o cadastro preenchido; prova com percurso baixa o GPX e tira a cidade do ponto de partida.
- Mudança de data, largada ou distância no Garmin depois de importar aparece como aviso, com "Atualizar" e "Manter". Nada muda sozinho.
- O vínculo com o evento e as provas ignoradas ficam no aparelho (`GarminRaceLinkStore`). O app só lê o calendário do Garmin.

## Nota do treino

| Parte | Peso | Onde |
| --- | --- | --- |
| Execução (feito contra o prescrito) | 50 | `WorkoutAnalysis/WorkoutScore*.swift`, `server/src/analysis/workoutScore.ts` |
| Intenção (zona e ritmo de cada bloco) | 25 | idem |
| Custo (eficiência contra os treinos iguais) | 25 | idem |

Comparação com até 4 treinos iguais (`maxComparisons`). Treino planejado é igual a outro quando o nome bate sem o dia da semana e a data: "Corrida fácil seg 16/11" compara com "Corrida fácil qua 11/11". Um dia da semana cortado no fim do nome pelo limite do Garmin também sai (`WorkoutTitle.comparisonKey`, `server/src/analysis/workoutTitle.ts`).

Quando falta alguma parte (sem prescrição, sem FC, sem zonas ou sem treino igual para comparar), a nota é calculada com as partes que existem e vai no máximo a 95 (`incompleteScoreCap`). Só treino com as três partes chega a 100.

A versão da nota está em `AnalysisConstants.scoreVersion` (4, desde vento, sol e adaptação ao calor). A chave guardada inclui o ajuste do clima de cada treino, então a nota é refeita quando o clima chega. Testes: `WorkoutScoreTests.swift`, `ComparisonTests.swift`.

## Análise detalhada

Arquivos: `Insights/DetailedAnalysis*.swift`, `server/src/analysis/detailed*.ts`. Testes: `InsightsTests/DetailedAnalysisTests.swift`, `DetailedCoachTests.swift`.

| Regra | Valor |
| --- | --- |
| Treinos parecidos | até 8, nos últimos 90 dias |
| Queda a partir do km X | km pelo menos 8 s/km mais lento que a mediana dos km anteriores, confirmado por 4 s/km no resto; só depois do km 3 |
| Tipos com regra de queda e de deriva | longão, rodagem, tempo e prova |
| Deriva normal | até 5%, medida a partir do km 4, ignorando o km 1 |
| Saída rápida | primeiros 5 km, com margem de 4 s/km contra os parecidos que não quebraram |
| Queda cedo | antes do km 10 |
| Prontidão baixa | abaixo de 60 |
| Semana pesada | 20% acima da média das 4 semanas anteriores |
| Completo / aceitável | 95% / 80% do planejado |
| FC no mesmo ritmo | longão e rodagem, com pelo menos 3 treinos |
| Limites da tela | até 5 itens e 3 recomendações |
| Recomendação de gel | só em treino de pelo menos 15 km, feitos ou planejados, quando houve queda; o gel vai 1 km antes da queda |

## Texto gerado no aparelho

O texto do treinador é escrito pelo modelo do aparelho (Apple Intelligence) a partir dos fatos da análise. Arquivos: `Narrative/CoachFeedback*.swift`, `Narrative/NarrativeCheck.swift`. Testes: `NarrativeTests/CoachFeedbackTests.swift`, `NarratorTests.swift`.

- O texto só usa números que estão nos fatos e no mesmo formato. Um ritmo como `4:53` conta como um número só.
- "Hora", "minuto" e "segundo" só passam se estiverem nos fatos.
- Sem exclamação, lista ou título. No máximo 700 caracteres e 6 frases.
- Se o texto não passa na checagem, o app mostra o texto padrão montado dos fatos.
- O texto aprovado vai pelo sync, cifrado, e os outros aparelhos usam o mesmo. Se dois aparelhos gerarem para os mesmos fatos, vale o mais recente (`GeneratedTextStore`, registro `narrative` no servidor).

## Força

Arquivos: `Insights/Strength*.swift`. Testes: `InsightsTests/StrengthTests.swift`.

- Os treinos de força vêm do MFIT. A Garmin só completa a FC e a duração.
- Séries por grupo muscular: o músculo principal conta 1 série e o secundário conta 0,5.
- Nível da sessão: 5 e 10 séries por grupo. Nível da semana: 7 e 15.
- Dia de pernas: pelo menos 50% das séries em pernas.
- Aviso quando limiar, VO2 ou longão cai no dia seguinte a um dia de pernas.
