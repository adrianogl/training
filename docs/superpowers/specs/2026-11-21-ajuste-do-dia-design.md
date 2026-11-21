# Ajuste do dia com números e calor pela tabela da análise

## Por quê

O "Ajuste para hoje" do treino da assessoria é uma frase por veredito ("lado mais lento da faixa"). Quem está prestes a correr precisa do pace, não da frase. E a prescrição do treinador decide o calor só pela temperatura (24 °C e 28 °C), enquanto a análise do treino usa temperatura + ponto de orvalho. Um treino com 25 °C e orvalho de 22 °C sai sem ajuste e depois a análise desconta o calor.

## Objetivo

- O card "Treino de hoje" mostra a faixa de pace ajustada de cada bloco forte, a faixa original e o motivo em números.
- O aviso da manhã cita a faixa ajustada em uma linha.
- Prescrição e análise usam a mesma conta de calor.

Fora do escopo: mudar o treino no relógio (é da assessoria; o app só mexe no que criou), ajustar por FC ou zona, ritmos que acompanham a forma (projeto C).

## Regras

Valem para o treino de corrida do Garmin no dia, nos blocos com alvo de pace (`PlannedTarget.pace`) do tipo `active`. Aquecimento, recuperação e blocos sem pace não mudam.

| Fator | Ajuste nos blocos fortes |
| --- | --- |
| Prontidão 70 ou mais | nenhum |
| Prontidão 60–69 | +3 s/km |
| Prontidão 50–59 | +6 s/km; intervalado com um bloco a menos; contínuo 20% mais curto |
| Prontidão abaixo de 50 | sem faixa: rodagem em Z1–Z2 ou descanso (frase atual) |
| Calor | `RunWeather.heatFactor` × pace do bloco, com a aclimatação de `RunWeather.adaptation` |
| Perna pesada na véspera | +3 s/km, também no longão |

- **Hora do clima:** mediana da hora de início das corridas dos últimos 30 dias; sem corridas, 7h. Usa a previsão por hora que o app já busca (Open-Meteo).
- **Soma:** os ajustes somam, arredondados ao segundo, com teto de 15 s/km. Acima do teto, o card mostra a frase de troca por rodagem.
- **Longão:** recebe calor e perna pesada; prontidão 50–59 encurta o final em 20%, como a frase atual.
- **Sem previsão:** o calor fica de fora e o motivo diz "sem previsão do tempo".
- **Treinos do treinador:** o calor da prescrição passa a usar a mesma conta (`heatFactor` em vez de 24/28 °C). O corte de 1 km de bloco vale com fator de 4,5% ou mais, que corresponde ao antigo 28 °C com orvalho alto.

## Onde fica

- Cálculo: `Packages/TrainingKit/Sources/Insights/DayAdjust*.swift` (função pura: treino, prontidão, previsão, hora, perna pesada → blocos ajustados e motivos). Testes em `InsightsTests/DayAdjustTests.swift`.
- Calor do treinador: `TrainerHeat` passa a chamar `RunWeather.heatFactor`; constantes antigas saem.
- Tela: `App/Today/TodayWorkoutCard.swift` mostra cada bloco com a faixa nova e "era …", e a linha de motivos.
- Aviso da manhã: uma linha depois da prontidão, junto do texto de força.
- Regras: `docs/regras/analise.md` (Ajuste para hoje) e `docs/regras/prescricao.md` (calor) no mesmo commit.

## Abordagens consideradas

- **Função no TrainingKit usada pelo card e pelo aviso** (escolhida): uma conta só, testável sem o app.
- Calcular na tela: contraria `App/CLAUDE.md` e duplicaria a conta no aviso.
- Reescrever o treino no relógio: o treino é da assessoria; o app só altera o que criou.

## Antes do código

Mock do card "Treino de hoje" e do aviso da manhã, atual × proposta, aprovado antes da implementação.

## Decisões minhas (para conferir)

- Hora do clima pela mediana das últimas corridas, com 7h de reserva.
- Corte de bloco do treinador a partir de 4,5% de fator de calor.
- Contínuo 20% mais curto com prontidão 50–59.
