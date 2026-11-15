# Análise de fim de ciclo

## Por quê

Quando um ciclo termina, o atleta escolhe o volume do próximo plano no chute. O treinador já tem os dados para dizer se o volume deve subir, ficar ou cair: o que foi cumprido, como a prontidão se comportou e se a forma melhorou.

## O que é um ciclo

- Plano com prova: do início do plano até o dia da prova.
- Plano sem data: cada bloco de 12 semanas (`openHorizonWeeks`), contado a partir da primeira semana do plano.
- Em qualquer plano, o atleta pode encerrar o ciclo antes. A análise passa a considerar só as semanas concluídas até ali.

## O que muda

**TrainingKit (`Insights`)**
- `TrainerPlan.endedOn: Day?` guarda o encerramento manual. Decodificado com `decodeIfPresent`, então plano antigo continua abrindo no app e no site.
- `TrainerEngine.cycleReview(plan:history:today:) -> TrainerCycleReview?` devolve a análise quando o ciclo terminou (prova passou, bloco de 12 semanas fechou ou `endedOn` preenchido) e `nil` caso contrário.
- `TrainerCycleReview` tem: período e semanas analisadas, volume feito e previsto por semana (reaproveita `scoreboard`), treinos-chave feitos/previstos (longão, limiar, VO2, média-longa), maior longão feito, prontidão média nas 4 primeiras e nas 4 últimas semanas, dias com prontidão abaixo de 60 (`lowReadiness`), semanas leves fora do previsto (`lightWeeks`), longões não fechados, previsão de 10 km e da distância da prova no início e no fim, resultado da prova (corrida `.race` no dia da prova, ou a maior corrida do dia), veredito, volumes sugeridos e motivos.

**Regra do veredito**
- Aumentar: cumpriu ≥ 90% do volume, a prontidão não caiu mais de 3 pontos, a previsão melhorou e houve no máximo 1 semana leve extra. Início e pico × 1,08, arredondados para baixo em km.
- Diminuir: cumpriu < 75%, ou a prontidão caiu 8 pontos ou mais, ou 2 ou mais semanas leves extras. Início e pico × 0,90, arredondados para baixo em km.
- Manter: o resto.
- Sem dado de prontidão ou de previsão, o critério que falta é ignorado. Com menos de 4 semanas concluídas, não há sugestão: a análise mostra os números e o veredito fica "Manter", com o motivo "ciclo curto demais para mudar o volume".

**App**
- Treinador: com ciclo concluído, aparece o banner "Ciclo concluído" (formato do "Plano atualizado"). O card do plano troca o placar semanal por "Resultado do ciclo" e mostra a sugestão em uma linha. Abaixo, "Ver análise do ciclo" e "Novo plano".
- Menu `…` do Treinador ganha "Encerrar ciclo agora", com confirmação. Grava `endedOn` = hoje. Ao encerrar, só contam as semanas que já terminaram.
- Tela "Análise do ciclo" (rota `TrainerRoute.cycle`) com as seções do mockup: Próximo ciclo, Prova (só plano com data), Volume, Treinos-chave, Como o corpo respondeu, Forma e "Como a sugestão é decidida" (recolhido).
- "Criar próximo plano com esse volume" abre `TrainerNewPlanView` com início e pico sugeridos. "Escolher outro volume" abre o mesmo formulário com os volumes do ciclo atual. Em plano sem data, se o atleta não encerrou, o botão é "Aplicar ao plano" e refaz o plano a partir da próxima semana com o volume novo.
- "Ciclos anteriores": ao criar o próximo plano, um resumo do ciclo (título, período, veredito, volume antes e depois, resultado) vai para uma lista em `TrainerStore`, por conta. A lista aparece no Treinador. Ela não abre uma análise detalhada.

## Fora

- Site: continua mostrando o plano como hoje. A análise no site fica para depois.
- Notificação de fim de ciclo.
- Leitura do ritmo da prova por trecho: a tela mostra tempo, meta e diferença.

## Abordagens consideradas

- **Análise no motor (escolhida):** a regra fica em `Insights`, testável com `swift test`, e no futuro o site lê a mesma análise.
- Análise só na view do app: mais rápida de fazer, mas não dá para testar a regra nem reaproveitar no site.
- Pedir o veredito ao modelo do chat: texto mais rico, só que a sugestão de volume deixa de ser previsível e passa a depender de rede.

## Validação

- Testes em `Insights` para cada veredito, para o plano sem data em 12 semanas, para o encerramento antes e para o ciclo com menos de 4 semanas.
- Teste de decodificação de plano antigo sem `endedOn`.
- Testes de texto no app para os rótulos da análise.
- `swift test`, `xcodebuild test` e vitest/typecheck do web, mesmo sem mudança no site, porque `types.ts` espelha o plano.
