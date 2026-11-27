# Regras de análise

Como o app lê um treino feito, a prontidão do dia e o texto que mostra sobre eles. As regras de prescrição estão em [prescricao.md](prescricao.md).

Toda mudança em uma regra daqui atualiza este arquivo no mesmo commit.

A análise roda só no app, no pacote `Packages/TrainingKit` (módulos `WorkoutAnalysis`, `Insights`, `Narrative`, `Metrics`).

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
| A noite não chegou | com o aviso da manhã ligado, notificação "A noite não chegou" às 10h quando a prontidão de hoje ainda não tem HRV nem sono, pedindo para abrir o app ou o Garmin Connect. Fica agendada desde o dia anterior e é cancelada quando os dados da noite chegam num sync; desligar o aviso da manhã cancela. Abre Hoje › Prontidão | `MissingNightNotifier` |

Testes: `MetricsTests/ReadinessTests.swift`, `ReadinessBreakdownTests.swift`, `InsightsTests/MissingNightTests.swift`.

### Ajuste para hoje

O card "Treino de hoje" recalcula o ritmo de cada passo ativo que tem pace-alvo. Passo de aquecimento, trote e descanso não mudam. A conta sai de três fatores, somados em s/km, em `Insights/DayAdjust.swift`.

| Fator | Regra | Constante |
| --- | --- | --- |
| Prontidão ≥ 70 | sem ajuste | `DayAdjustConstants.readinessSteps` |
| Prontidão 60 a 69 | + 3 s/km | `readinessSteps` |
| Prontidão 50 a 59 | + 6 s/km, e encurta o treino (tabela abaixo) | `readinessSteps`, `shortenShare` |
| Prontidão abaixo de 50 | sem faixa: o card mostra a frase de descanso | `restBelow` |
| Calor | `WeatherAdjustment.heatShare(temperatura + sol, ponto de orvalho, aclimatação)` × pace médio do bloco, arredondado. O sol vem da radiação prevista para a hora. A aclimatação conta as corridas quentes dos últimos 14 dias (`hotSessions`). Abaixo de 3 s/km no bloco, o calor é ignorado; se nenhum bloco chega a 3 s/km, o calor não entra como motivo | `WeatherAdjustment`, `RunWeatherConstants.minimumHeatSeconds` |
| Perna pesada no dia anterior | + 3 s/km em qualquer treino | `heavyLegsSeconds` |

A perna pesada vem de `StrengthModel.legDay`, com uma sessão de força feita ontem. Conta quando a sessão casa com um treino conhecido do MFIT com pelo menos 50% das séries em perna, ou quando o treino de força planejado para ontem era de perna pesada: do treinador com foco pernas moderada ou pesada, ou corpo inteiro pesada (`TrainerModel.plannedLegs`), ou o treino do Claude aplicado para ontem com perna pesada (`ClaudeStrengthValidator.isHeavyLegs`).

| Tipo | Encurtamento com prontidão 50 a 59 |
| --- | --- |
| Intervalado | uma repetição a menos. Sem grupo de repetição, sai o último bloco ativo e a recuperação antes dele; bloco ativo único não é cortado |
| Contínuo | 20% mais curto |
| Longão | último bloco 20% mais curto |

O tipo vem de `PlanText.shape`: intervalado tem repetição ou mais de um bloco ativo; longão não é intervalado e o nome fala em longão ou a distância chega a 14 km (`isLongRun`); contínuo é o resto.

- O ajuste mostrado e o teto de 15 s/km (`maximumSeconds`) usam o bloco mais ajustado. Acima do teto, o card mostra a frase de troca.
- O horário do clima é a hora habitual daquele treino (`UsualHour`): no longão, a mediana da hora de saída dos longões (15 km ou 75 min) das últimas 8 semanas, se houver pelo menos 3; senão, a mediana das corridas do mesmo tipo de dia (dia útil nos últimos 30 dias, fim de semana nas últimas 8 semanas), com pelo menos 2; senão, a de todas as corridas dos últimos 30 dias; sem corrida, 7h. A mediana é a de baixo com número par. Usa a hora mais próxima com previsão. A notificação da manhã usa a mesma hora.
- Sem previsão, ou sem ponto de orvalho na hora escolhida, o calor não entra e o motivo aparece como "sem previsão do tempo".
- O card mostra a faixa nova com "era …", o aviso "Ajuste para hoje · +N s/km nos tiros/no ritmo/no longão" e um chip por motivo. Sem mudança, não há aviso. A sugestão própria do treinador por prontidão tem prioridade.
- A notificação da manhã acrescenta, antes da linha de força, algo como "Tiros em 4:10–4:18 por calor e prontidão.". Usa o mesmo treino do card: o primeiro treino do dia que ainda não foi feito (`TodayWorkoutPicker.pending`). Só entra quando o aviso é enviado e espera no máximo 5 s pela previsão. Se o app for aberto durante a espera, o aviso não sai.
- Quando o treinador mudou o treino de hoje entre 22h e 7h, a linha da corrida começa com "Treino de hoje mudou:" e segue com a linha do ajuste ou, sem ela, o treino novo. Nesse caso não sai push separado (`TrainerChangeNotifier.morningLine`, regra em `prescricao.md`).

Frases de troca e de descanso:

- **Troca** (ajuste acima de 15 s/km): "O pace subiria mais de 15 s/km por <motivos>: troque por rodagem leve em Z1–Z2 ou descanse.", com os motivos na mesma ordem da notificação ("por calor e prontidão") e os chips embaixo.
- **Descanso** (prontidão abaixo de 50), por tipo de treino:

| Prontidão abaixo de 50 | Contínuo | Intervalado | Longão |
| --- | --- | --- | --- |
| Frase | encurtar e ficar em Z1–Z2, ou descansar | trocar por rodagem leve em Z1–Z2, ou descansar | trocar o longão por rodagem leve em Z1–Z2, ou descansar |

#### Pace do dia no relógio

Com "Corrida do treinador" ligado e relógio Garmin conectado, o relógio recebe o mesmo ajuste do card. Treino da assessoria e Apple Watch continuam como acima.

- De manhã, no sync em segundo plano, e no fim de cada sync com o app aberto, o app grava as entradas do ajuste de hoje: prontidão, temperatura, orvalho e sol da previsão na hora habitual, corridas quentes, perna pesada, hora e origem (`DayAdjustEntries`, `TrainerDayAdjustStore`). Isso roda antes do envio automático, que troca o treino de hoje no relógio pelo treino ajustado (`TrainerDayAdjust`). Os fatores, o teto de 15 s/km, o descanso abaixo de 50 e o encurtamento com 50 a 59 são os mesmos do card (`DayAdjust.factors`, `DayAdjust.decide`). Passos ativos são blocos e ritmo (`work`, `steady`); aquecimento, trote, desaquecimento e descanso não mudam. No longão o pace muda do mesmo jeito; o "1 km a menos" do card "Calor no longão" fica só na tela.
- Troca, descanso ou nenhum ajuste: o relógio recebe o plano como está.
- Regra dos 3 s/km: uma entrada nova da hora habitual só substitui a de hoje quando o total muda 3 s/km ou mais, ou quando muda o encurtamento, a troca ou o descanso. Sem previsão, fica a entrada que já existe. Entrada com origem "agora" não é trocada pelo sync. A sugestão própria do treinador por prontidão apaga a entrada e o plano vai como está.
- O registro do envio (`TrainerSentRecord`) guarda as entradas usadas, a fração de calor incluída no alvo e o título enviado. Ele sincroniza entre iPhone e iPad pelo ledger do envio e é a fonte das entradas de hoje: uma entrada local só vale no lugar da do registro quando é mais nova e muda o relógio pela regra dos 3 s/km, ou quando veio do "Vou correr agora". Ledger remoto com entradas mais novas substitui as locais. Com os dois aparelhos na mesma versão, os dois montam o mesmo treino e nenhum reenvia.
- Quando o treino de hoje no Garmin é o que o app enviou com essas entradas, o card mostra o que está no relógio sem ajustar de novo, com "era …" do plano, o aviso e os chips das entradas guardadas e a linha "No relógio desde 6h05 · clima das 7h".
- Se o ajuste com a previsão da hora atual mudar 3 s/km ou mais (ou mudar encurtamento ou troca) em relação ao do relógio, o card mostra o botão "Vou correr agora · clima das <HH>h". O toque grava as entradas com origem "agora" e envia só o treino de hoje. O botão mostra o ajuste total que vai para o relógio ("· +13 s/km").
- Treinos › dia de hoje mostra o mesmo bloco (linha do relógio e botão de agora) e, embaixo, "Vai correr mais tarde?": até 3 horas depois da atual e até as 21h, com a hora que está no relógio fixa e o resto pelas de menor ajuste. Cada hora mostra o pace do bloco principal e o ajuste. "Enviar para as <h>h" recalcula com a previsão daquela hora, mantendo prontidão, perna pesada e corridas quentes do envio, grava com origem "agora" (o sync não troca) e envia só o treino de hoje. Com a hora e o ajuste iguais aos do relógio, o botão fica desligado (`DayAdjustWatchRules.laterOptions`, `DayAdjustWatchPanel`).
- A notificação da manhã usa as mesmas entradas gravadas, então a linha bate com o relógio.
- Em Treinos, a linha de hoje e o dia de hoje mostram o pace ajustado; o dia mostra "Ajuste do dia · +N s/km · era …". Os outros dias seguem com o pace do plano. Em "Enviar ao Garmin", o treino de hoje que mudou só pelo ajuste mostra "Ajuste do dia: +N s/km".

### Melhor horário no detalhe do treino planejado

- Cada hora do card mostra quanto o calor tira do ritmo, pela mesma conta do ajuste do dia: fração de calor da hora (temperatura, orvalho, sol e corridas quentes) × pace de referência, zerada abaixo de 3 s/km (`PlannedHourHeat`, `DayAdjust.heatOffset`). Cor: até 4 s no acento, 5 a 11 s em laranja, 12 s ou mais em vermelho.
- Pace de referência: o meio do primeiro alvo de pace ativo; sem alvo, a média dos treinos parecidos; sem eles, a faixa leve do treinador. Hora sem ponto de orvalho fica sem número.
- A comparação é entre o mais fresco e a hora de saída de agora (hoje) ou a hora mais quente da lista (outro dia). Com diferença de 3 s/km ou mais, a nota diz "Sair às 20h em vez das 12h poupa N s/km na mesma FC." e, se o treino tem alvo de pace, aparecem as linhas "Principal às <h>h" com o pace somado. Sem número em nenhuma hora, a nota volta ao "5 a 10 s/km" genérico.
- O aviso "Calor e umidade" usa a mesma conta na hora quente: "aceite 8 s/km mais lento". Abaixo de 3 s/km diz "menos de 3 s/km"; sem orvalho ou sem pace de referência, "5 a 10 s/km".

Arquivos: `Insights/DayAdjust.swift`, `Insights/TrainerDayAdjust.swift`, `App/Today/DayAdjustText.swift`, `App/Today/TodayConstants.swift`, `App/Trainer/DayAdjust/`, `App/Workouts/Planned/PlannedHourHeat.swift`, `App/Workouts/Planned/PlannedHoursCard.swift`. Testes: `InsightsTests/DayAdjustTests.swift`, `InsightsTests/TrainerDayAdjustTests.swift`, `AppTests/DayAdjustTextTests.swift`, `AppTests/DayAdjustWatchTests.swift`, `AppTests/PlanAdjustTests.swift`.

## Zonas de FC no Garmin

As zonas de corrida do app partem do limiar do relógio: Z2 a partir de 85%, Z3 90%, Z4 95% e Z5 102%. O tempo em zona da análise usa as mesmas faixas. O aviso de zonas do relógio diferentes no detalhe do treino compara o início da Z5 do relógio com os 102% do limiar. Depois de cada sincronização, se o limiar mudou ou se as zonas de corrida do Garmin estão diferentes, o app grava essas faixas no Garmin, com o interruptor "Manter iguais às do app" em Ajustes › Garmin. Só mexe no perfil de corrida, e o início da Z1 continua o do Garmin. Depois de gravar, o app lê de volta e avisa se não bater. Arquivos: `GarminAPI/HeartRateZoneProfiles.swift`, `App/Garmin/GarminZonesModel.swift`. Testes: `GarminAPITests/HeartRateZoneProfilesTests.swift`.

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

Arquivos: `WorkoutAnalysis/Elevation*.swift`. Testes: `WorkoutAnalysisTests/ElevationPaceTests.swift`.

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

Arquivos: `TrainingCore/RunWeather*.swift`, `WorkoutAnalysis/WeatherBlocks.swift`. Testes: `TrainingCoreTests/RunWeatherTests.swift`, `WorkoutAnalysisTests/WeatherAnalysisTests.swift`.

| Regra | Valor | Constante |
| --- | --- | --- |
| Fonte | Open-Meteo, na coordenada da largada arredondada a 0,1°, média das horas que o treino cobre. Até 85 dias, endpoint de previsão; antes disso, arquivo | `ActivityWeatherConstants`, `WEATHER` |
| Treinos preenchidos | corridas ao ar livre dos últimos 120 dias, até 40 consultas por sincronização. Resposta sem dados tenta de novo depois de 6 h; sem rede ou com erro 5xx, tenta de novo na próxima atualização. Esteira e treino sem GPS ficam sem clima | `backfillDays`, `requestsPerRefresh`, `retryInterval` |
| Calor | cresce com a temperatura e com o ponto de orvalho, sem ajuste até 20 °C somados e até 10% (veja a tabela abaixo). Internamente a régua é a soma em °F (`heatBands`), interpolada | `RunWeatherConstants.heatBands`, `HEAT.bands` |
| Frio | só a temperatura, de 5 °C para baixo: 0 °C 0,5%; −5 °C 1%; −10 °C ou menos 2% | `coldBands` |
| Equivalente em clima ameno | ritmo ÷ (1 + ajuste) | `WeatherAdjustment.mildPace` |
| Bloco com alvo de ritmo | mais lento que o alvo, mas dentro dele no equivalente em clima ameno, conta como no alvo e gera "Ritmo mais lento pelo calor" (ou "pelo frio") no grupo esperado. Mais rápido continua fora do alvo. Quando o alvo do relógio já tinha o calor do pace do dia, o resgate usa só a diferença: fator medido menos fator incluído, no mínimo zero, e só nos blocos ativos. O fator do bloco para custo e comparação continua o medido inteiro. O calor incluído vale só para a primeira corrida do dia cujo nome de treino bate com o título enviado (`WorkoutTitle.comparisonKey`); outra corrida do dia fica com 0. O valor fica guardado por conta (`IncludedHeatStore`), então a nota não muda quando o ledger apaga o registro | `adjustForWeather(includedHeat:)`, `IncludedHeatStore` |
| Deriva cardíaca | com calor de pelo menos 2%, sai de atenção e vai para esperado, citando os graus | `driftHeatFactor` |
| Zona acima | com calor de pelo menos 3%, o limite do aquecimento e do desaquecimento sobe de Z3 para Z4 | `zoneHeatFactor` |
| Perda de ritmo | com calor de pelo menos 3%, o texto cita o calor | `fadeHeatFactor` |
| Custo, FC menor que antes, Acima do esperado | velocidade de cada treino ajustada pelo clima daquele treino | `WorkoutBlock.weatherSpeed` |
| Alvo de FC | não muda | — |

| Sol | radiação solar média das horas do treino, de 0 a 800 W/m², soma de 0 a 4 °C à temperatura do ajuste de calor; "sol forte" a partir de +2 °C | `fullSunRadiation`, `fullSunBoost`, `sunnyBoost` |
| Adaptação ao calor | cada corrida com calor de pelo menos 2% nos 14 dias anteriores tira 5% do ajuste de calor, até 40% | `hotSessionFactor`, `adaptationPerSession`, `maxAdaptation` |

Ajuste de pace pelo calor, antes da adaptação e sem sol:

| Temperatura | Orvalho 10 °C | Orvalho 15 °C | Orvalho 20 °C | Orvalho 24 °C |
| --- | --- | --- | --- | --- |
| 16 °C | 0,5% | 1,0% | — | — |
| 20 °C | 0,9% | 1,7% | 2,6% | — |
| 24 °C | 1,5% | 2,4% | 3,5% | 4,6% |
| 28 °C | 2,2% | 3,2% | 4,6% | 5,6% |
| 32 °C | 3,0% | 4,3% | 5,6% | 7,0% |

Num pace de 5:00/km, 1% são 3 s/km. A corrida conta como quente para a adaptação a partir de 2%.

O detalhe da corrida mostra os graus, o ponto de orvalho, o sol, a adaptação e o ajuste. Sem clima, a análise fica como antes. O clima de cada treino tem versão (`weatherVersion`); a versão 2 trouxe vento e sol, e os treinos dos últimos 120 dias são consultados de novo.

## Vento

Arquivos: `WorkoutAnalysis/Wind.swift`, `WorkoutAnalysis/AssessmentConditions.swift`. Testes: `WorkoutAnalysisTests/ConditionsAnalysisTests.swift`.

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

Arquivos: `App/Workouts/Detail/DayConditionBuilder.swift`, `WorkoutAnalysis/AssessmentConditions.swift`, `Narrative/NarrativeConditions.swift`.

Entram como "Causa provável" em fora do alvo (mais lento ou FC acima), incompleto, perda de ritmo e deriva fora do calor. Não mudam a nota nem o grupo do item.

| Sinal | Quando conta | Constante |
| --- | --- | --- |
| Sono | menos de 6 h, ou nota abaixo de 60 | `shortSleepSeconds`, `lowSleepScore` |
| HRV | última noite abaixo da faixa equilibrada | — |
| Body Battery | máximo da manhã abaixo de 40 | `lowBodyBattery` |
| Véspera | tiros, limiar ou longão no dia anterior; também dia de pernas no MFIT (pelo menos 50% das séries em pernas) | `PreviousDayLoad` |

## Dinâmica de corrida

Arquivos: `WorkoutAnalysis/AssessmentConditions.swift`.

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
- A Evolução mostra a previsão de 1 km, 3 km, 5 km, 10 km, meia maratona e maratona (`MetricKind.predictionKinds`), todas pelo mesmo Riegel. A de 1 km é a menos confiável, porque a fórmula extrapola mal para provas curtas.
- Cada card de previsão compara com o RP da mesma distância (`EvolutionText.recordComparison`): mais rápido que o RP sai "★ 7 s abaixo do RP 3:38" em dourado, com a borda do card dourada; mais lento, "1 s acima do RP" em cinza; empate, "igual ao RP"; sem RP, "sem RP ainda".
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

## Recorde pessoal e meta cumprida

| Regra | Valor | Onde |
| --- | --- | --- |
| Distâncias | 1 km, 3 km, 5 km, 10 km, meia maratona e maratona, as mesmas das previsões da Evolução | `PersonalRecordsConstants.distances` |
| Corrida inteira | distância entre 99% e 103% da distância do recorde; o tempo em movimento é ajustado para a distância exata | `wholeRunLow`, `wholeRunHigh` |
| Melhor trecho | 1, 3, 5 e 10 km e meia maratona pelas amostras do FIT, interpolando o início do trecho; buraco maior que 30 s entre amostras não vale. Sem amostras, 1 e 5 km usam o melhor trecho da Garmin | `bestSegment`, `segmentMaximumGap` |
| Recorde | mais rápido que o melhor tempo dos treinos anteriores na mesma distância. Empate não conta | `PersonalRecords.timeline` |
| Primeira vez | sem tempo anterior na distância: "Primeira meia maratona", não "Recorde" | `RecordHit.isFirst` |
| Quase recorde | até 2% acima do recorde, sem recorde no treino: "a 8 s do recorde" | `nearShare` |
| Treinos antigos | o histórico não gera aviso; os selos da lista e do detalhe valem para todo o histórico, comparando cada treino com os anteriores | `PersonalRecordsStore` |

- **Aviso de treino:** com um recorde ou uma meta, o título nomeia a distância ou a meta. Com vários, conta ("3 recordes e 2 metas") e o corpo lista todos, do mais longo ao mais curto.
- **Lista:** pílula dourada "★ RP 5 km" ou "★ 3 RP" e borda dourada no card; meta cumprida em lime ("✓ Meta", "✓ 2 metas"). Se as pílulas não cabem, sai o chip "estruturado"/"do plano".
- **Detalhe:** card de recordes com o tempo, a diferença e os recordes anteriores na distância em barras; com vários, uma linha por recorde.
- **Compartilhar:** item "Recorde e meta" em Mostrar, ligado quando há recorde. O tempo do recorde fica dourado com "RP". O formato "Recorde" só aparece com recorde.
- **Evolução:** recorde dos últimos 7 dias fica dourado com "novo", e tocar na linha abre o treino.

Arquivos: `WorkoutAnalysis/PersonalRecords*.swift`, `App/Workouts/Records/*`, `App/Background/WorkoutNotice*.swift`. Testes: `WorkoutAnalysisTests/PersonalRecordsTests.swift`, `AppTests/WorkoutNoticeRecordsTests.swift`, `AppTests/RecordSnapshotTests.swift`.

## Nota do treino

| Parte | Peso | Onde |
| --- | --- | --- |
| Execução (feito contra o prescrito) | 50 | `WorkoutAnalysis/WorkoutScore*.swift` |
| Intenção (zona e ritmo de cada bloco) | 25 | idem |
| Custo (eficiência contra os treinos iguais) | 25 | idem |

Comparação com até 4 treinos iguais (`maxComparisons`). Treino planejado é igual a outro quando o nome bate sem o dia da semana e a data: "Corrida fácil seg 16/11" compara com "Corrida fácil qua 11/11". Um dia da semana cortado no fim do nome pelo limite do Garmin também sai (`WorkoutTitle.comparisonKey`).

Corrida sem treino planejado compara só com corridas também sem treino planejado e que não são prova, com distância até 20% diferente, nos últimos 90 dias.

### Nota de prova

Uma corrida é prova quando é o resultado de uma prova cadastrada ou, se a prova ainda não tem resultado e não foi desvinculada à mão, quando cai no dia dela, inclusive hoje, com distância até 10% diferente da prova (`RaceIndex.race(for:)`). Essa margem vale só para a nota; o vínculo automático (`autoLinkRaces`) continua com 4% e só liga depois do dia. Prova tem regra própria (`scoreRace`, em `WorkoutScoreRace.swift`), mesmo quando tem nome de treino:

| Parte | Peso | Regra |
| --- | --- | --- |
| Execução | 50 | Pace feito (duração ÷ distância medida) contra o pace do alvo (alvo ÷ distância da prova). Alvo é `frozenTargetSeconds` e, sem ele, `goalSeconds`. No alvo ou mais rápido vale 50; cai em linha reta até 0 com 10% mais lento (`raceSlowMargin`). Sem alvo, fica de fora. |
| Intenção | 25 | Fração dos km completos (a partir de 950 m) com pace a até 5 s/km da referência (`racePaceTolerance`). Referência é a mesma estratégia da tela da prova: o Pace Pro escolhido e, sem ele, a estratégia do app pelo alvo congelado. Sem estratégia, vale o pace do alvo. Sem km completos, fica de fora. |
| Custo | 25 | Eficiência contra até 4 provas anteriores de distância até 20% diferente, de qualquer data. Sem prova anterior, fica de fora. |

A chave guardada de uma prova inclui distância, alvo e pace de referência por km, então a nota é refeita quando a meta ou a estratégia mudam.

A nota só aparece quando o treino tem tudo o que pode ter (`ScoreReadiness`): o FIT processado, ou desistido depois de 5 falhas, e o clima do horário quando é corrida ao ar livre com GPS dos últimos 120 dias. Enquanto falta, a lista, o Hoje e o detalhe mostram "Calculando a nota" com o motivo, e o aviso de corrida nova e o resumo no Strava esperam. A comparação com treinos iguais não entra na espera: quando não existe treino igual, ela não chega nunca.

Quando falta alguma parte (sem prescrição, sem FC, sem zonas ou sem treino igual para comparar), a nota é calculada com as partes que existem e vai no máximo a 95 (`incompleteScoreCap`). Só treino com as três partes chega a 100.

A versão da nota está em `AnalysisConstants.scoreVersion` (4, desde vento, sol e adaptação ao calor). A chave guardada inclui o ajuste do clima de cada treino, então a nota é refeita quando o clima chega. Também inclui o calor que já estava no alvo do relógio, então a nota é refeita quando o registro do envio chega por sync. Testes: `WorkoutScoreTests.swift`, `RaceScoreTests.swift`, `ComparisonTests.swift`, `RaceDetectionTests.swift` (`RaceIndexTests`) e, no app, `ComparisonSelectionTests.swift`.

## Análise detalhada

Arquivos: `Insights/DetailedAnalysis*.swift`. Testes: `InsightsTests/DetailedAnalysisTests.swift`, `DetailedCoachTests.swift`.

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

O texto do treinador é escrito pelo modelo do aparelho (Apple Intelligence) a partir dos fatos da análise. Além dos achados, os fatos trazem nota e partes, efeito do treino segundo o relógio, planejado × feito, custo do clima, carga comparada com os últimos 90 dias, treinos parecidos, metas, prontidão do dia, condição de performance no início, km da semana até o treino e dias desde o último treino forte (`WorkoutCoachFacts`). A análise detalhada recebe os mesmos fatos na parte "O treino". Arquivos: `Narrative/CoachFeedback*.swift`, `Narrative/NarrativeCheck.swift`. Testes: `NarrativeTests/CoachFeedbackTests.swift`, `NarratorTests.swift`.

- O texto só usa números que estão nos fatos e no mesmo formato. Um ritmo como `4:53` conta como um número só.
- "Hora", "minuto" e "segundo" só passam se estiverem nos fatos.
- Sem exclamação, lista ou título. No máximo 700 caracteres e 6 frases.
- O texto fala com uma pessoa só: "você". "Vocês" e "o atleta" reprovam o texto.
- Afirmações que o modelo costuma inventar só passam se estiverem nos fatos: fora, acima ou abaixo do alvo, não cumpriu, piorou, melhorou, eventos, lesão, dor, estresse, desconforto, doença, cansaço, fadiga, chuva, vento, calor, frio, sono, alimentação, hidratação. A lista fica em `CoachFeedbackConstants.backedClaims`.
- Quando as regras mudam, a versão do cache (`GeneratedTextConstants.version`) sobe e os textos já aprovados são gerados de novo.
- Se o texto não passa na checagem, o app mostra o texto padrão montado dos fatos.
- O texto aprovado vai pelo sync, cifrado, e os outros aparelhos usam o mesmo. Se dois aparelhos gerarem para os mesmos fatos, vale o mais recente (`GeneratedTextStore`, registro `narrative` no servidor).

## Força

Arquivos: `Insights/Strength*.swift`. Testes: `InsightsTests/StrengthTests.swift`.

- Os treinos de força vêm do MFIT. A Garmin só completa a FC e a duração.
- Séries por grupo muscular: o músculo principal conta 1 série e o secundário conta 0,5.
- Nível da sessão: 5 e 10 séries por grupo. Nível da semana: 7 e 15.
- Dia de pernas: pelo menos 50% das séries em pernas.
- Aviso quando limiar, VO2 ou longão cai no dia seguinte a um dia de pernas.

## Apple Watch e métricas por relógio

Arquivos: `HealthImport/*`, `App/Health/HealthKitReader.swift`, `App/Device/*`. Testes: `HealthImportTests/*`.

A conta escolhe o relógio (Garmin ou Apple Watch) no primeiro acesso ou em Ajustes › Relógio. Com Apple Watch, o sync lê do Apple Saúde neste iPhone, pelo mesmo caminho do Garmin; nada do Apple Saúde vai ao servidor.

| Regra | Valor | Constante |
| --- | --- | --- |
| Treinos lidos | corrida, caminhada e força (outros ficam de fora) | `HealthWorkoutKind` |
| Amostras do treino | a cada 5 s: FC, distância, velocidade, cadência, contato com o solo, rota e altitude | `sampleStep` |
| Voltas | segmentos do treino; sem segmentos, as voltas | `HealthKitReader.laps` |
| HRV da noite | média do SDNN entre 18h e 11h | `nightStartHour`, `nightEndHour` |
| Faixa de HRV própria | 60 noites anteriores, a partir de 14 noites; baixa abaixo de média − 1,5 DP; equilibrada de média − 0,5 DP a média + 1 DP | `hrvBaselineDays`, `hrvMinimumNights` |
| Nota de sono | até 70 pela duração (8 h = 70) + até 30 pela parte profunda + REM (40% = 30) | `sleepDurationPoints`, `sleepStagePoints` |
| Carga do treino | TRIMP: minutos × reserva de FC × 0,64 × e^(1,92 × reserva) | `trimpFactor`, `trimpExponent` |
| FC máxima e de repouso | maior FC dos treinos do último ano; mediana da FC de repouso de 30 dias | `restingWindowDays` |
| Zonas | 50, 60, 70, 80 e 90% da FC máxima | `zoneFloors` |
| Body Battery | não existe; a prontidão redistribui o peso entre HRV, sono e carga | `readiness` |

Nas primeiras 14 noites, a prontidão usa sono e carga, e Hoje avisa "Primeiras semanas".

## Corridas do Strava sem o relógio

Arquivos: `server/src/strava.ts`, `RemoteSync/StravaRunMatching*.swift`, `HealthImport/StravaRunMapping*.swift`, `Sync/ExternalRunImport.swift`, `App/Strava/StravaModel+Import.swift`. Testes: `server/test/strava.test.ts`, `RemoteSyncTests/StravaRunsTests.swift`, `HealthImportTests/StravaRunImportTests.swift`, `AppTests/StravaImportTests.swift`.

Corrida gravada só no Strava entra no app depois de aprovada e vale como uma corrida do Garmin: volume, carga, treinador, análise e nota. Nada entra sozinho.

| Regra | Valor | Constante |
| --- | --- | --- |
| Candidatas | Run, TrailRun e VirtualRun que não vieram de dispositivo Garmin (`device_name` ou `external_id` com "garmin") | `STRAVA_RUN_SPORTS`, `STRAVA_GARMIN_MARK` |
| Sem par no app | nenhuma corrida a ±15 min do início com distância a ±10% | `window`, `distanceTolerance` |
| Busca | Ajustes › Strava › Corridas sem o relógio olha 12 meses; o aviso olha 4 semanas, no máximo 3 por vez | `backfillDays`, `recentDays`, `recentNotifyLimit` |
| Aprovação | Importar ou Ignorar, na lista ou na notificação; ignorada não volta. O registro é por aparelho | `StravaImportConstants` |
| Id | id do Strava com o bit `0x2000_0000_0000_0000` | `StravaActivityIdConstants` |
| Tipo | sem GPS ou VirtualRun vira esteira (sem clima); TrailRun vira trilha | `StravaRunMappingConstants` |
| Amostras | a cada 5 s, pelo último ponto das séries do Strava; cadência × 2 (passos por minuto) | `sampleStep`, `stepsPerStride` |
| Carga | TRIMP pela FC média e tempo em movimento, com FC máxima e de repouso das zonas do Garmin (190 e 60 sem zonas); sem FC, sem carga e sem nota | `fallbackMaxHeartRate`, `fallbackRestingHeartRate` |
| Garmin prevalece | se a mesma corrida chegar pelo Garmin (±15 min, ±10%), a do Strava é apagada no sync | `externalMatchWindow`, `externalDistanceTolerance` |

Depois do import, prontidão dos dias seguintes, nota, clima e texto são recalculados como depois de um sync. A lista de Treinos marca a corrida com o selo "Strava".

**Métricas por relógio:** o app só mostra o que chegou. Tile ou grupo de Evolução sem valor no período some; número solto sem valor (`DSStat`) some em vez de mostrar "—"; Ajustes esconde Garmin e Mostrador para quem usa Apple Watch.

