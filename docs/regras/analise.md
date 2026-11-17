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
| Ritmo mais rápido na descida | esperado | km seguidos em que a descida deixou o ritmo pelo menos 3 s/km mais rápido que o equivalente no plano |
| Deriva cardíaca | atenção | FC do último terço 5% acima do primeiro terço, com velocidade variando até 2% |
| Zona acima | atenção | aquecimento, recuperação ou rodagem com zona dominante 3 ou mais |
| Forte com prontidão baixa | atenção | treino forte com prontidão abaixo de 50 |
| Carga alta | atenção | carga aguda/crônica acima de 1,5 |

Quando um bloco fica incompleto, a análise procura a causa e cita só o que encontrou:

- **Queda de ritmo:** o primeiro km pelo menos 8 s/km mais lento que a média dos 3 primeiros km, e que continua lento até o fim, no equivalente no plano.
- **FC subindo:** a FC média dos 3 últimos km pelo menos 3 bpm acima da dos 3 primeiros.
- **Pausas:** quantas houve, em que km começou a primeira e o tempo parado.
- **Prontidão:** abaixo de 50.
- **Carga:** aguda/crônica acima de 1,5.

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

## Nota do treino

| Parte | Peso | Onde |
| --- | --- | --- |
| Execução (feito contra o prescrito) | 50 | `WorkoutAnalysis/WorkoutScore*.swift`, `server/src/analysis/workoutScore.ts` |
| Intenção (zona e ritmo de cada bloco) | 25 | idem |
| Custo (eficiência contra os treinos iguais) | 25 | idem |

Comparação com até 4 treinos iguais (`maxComparisons`). A versão da nota está em `AnalysisConstants.scoreVersion`. Testes: `WorkoutScoreTests.swift`, `ComparisonTests.swift`.

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
