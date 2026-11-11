# trAIning — Zonas pelo limiar, provas reconhecidas e ajustes internos (plano 4) — Design

Data: 2026-11-11. Complementa a spec principal `docs/superpowers/specs/2026-11-07-training-design.md` e o design do plano 3 `docs/superpowers/specs/2026-11-09-hoje-evolucao-provas-design.md`. O que não está aqui continua valendo como está. Pendências herdadas: `docs/superpowers/plans/2026-11-11-pendencias-plano-3.md`.

Mockups da conversa (não versionados): `.superpowers/brainstorm/71658-1794396631/content/` no repositório principal — `zonas-lado-a-lado.html` e `zonas-barras-v2.html` (opção escolhida: A1).

## Por que

Depois de usar o plano 3 no iPhone e no iPad, duas coisas não batiam com o que o Adriano sabe do próprio treino.

- **Zonas.** O relógio classifica os treinos com zonas abaixo do limiar: a Z5 do relógio começa alguns bpm abaixo da FC de limiar que o próprio Garmin mede. Resultado: longões ficam com dezenas de minutos em "Z5", e corridas fáceis caem em Z3 e Z4. A nota do treino herda o erro, porque usa as zonas do relógio para decidir se a corrida fácil foi fácil.
- **Previsão de prova.** A previsão usa os melhores esforços dos últimos 150 dias. Nenhuma prova real está ligada a uma atividade: o Adriano não cadastra as provas no app e não marca nada no Garmin, só muda o nome da atividade, e às vezes nem isso. A previsão de 5 km depende de um único trecho de treino e fica perto do limite de 3% em relação ao Garmin.

O resto do plano resolve pendências internas do plano 3 que o Adriano não vê diretamente, mas que podem travar a tela ou gerar frase errada.

## Objetivos

1. **Zonas pelo limiar** calculadas pelo app, mostradas ao lado das zonas do relógio no detalhe do treino.
2. **Nota do treino julgada pelas zonas do limiar.**
3. **Provas reconhecidas no histórico**, com confirmação do Adriano, entrando na previsão com peso de prova.
4. **Desempenho:** nota do treino guardada, backfill de narrativa fora da main thread.
5. **Validador de frases com direção** e os dois casos do retry do aviso de manhã.

## Não objetivos

- Mudar as zonas no relógio ou no Garmin Connect. A Personal API é só leitura.
- Estimar a FC de limiar pelo app. O limiar vem do Garmin.
- Zonas de pace ou de potência. Só FC.
- README e landing page. A spec do plano 3 os deixou para o plano 4; ficam para o plano seguinte (decisão minha, para manter este plano no que o Adriano pediu).
- Marcar prova automaticamente sem perguntar.

## Anti-objetivos (decisão minha, o Adriano não detalhou)

O plano falhou, mesmo funcionando, se:

- o app perguntar "foi prova?" mais de uma vez sobre a mesma corrida, ou perguntar sobre treinos claramente comuns;
- um treino antigo mudar de cor ou de nota sem que nada daquele treino tenha mudado;
- a previsão pular de um dia para o outro sem uma prova nova confirmada ou um treino novo que explique.

## Zonas

### Decidido pelo Adriano

- O detalhe do treino mostra **as duas zonas lado a lado**: as do relógio e as calculadas pelo limiar.
- Formato **A1 (régua de FC)**: duas barras horizontais na mesma escala de bpm, uma por critério ("Relógio (Garmin)" e "Pelo limiar (N bpm)"). As divisas de cada zona aparecem como marcas com o valor em bpm embaixo da barra. Abaixo de cada barra, uma linha com o tempo em cada zona ("Z1 1:24 · Z2 6:43 · …"). Mesmas cores por zona nas duas barras.
- A **nota do treino julga pelas zonas do limiar**. As zonas do relógio ficam só para comparação na régua.
- **Todo o app passa a usar as zonas do limiar**: a faixa de Z2 citada em Hoje e na Evolução (`zone2Range` em `InsightsStore`), os minutos por zona da semana, o foco da carga (`loadFocus`) e as séries de `MetricSeries` e `OverallState` que dependem de zona. As zonas do relógio aparecem só na régua do detalhe do treino.

### Decisões minhas

- **Tempo por zona guardado:** `ActivityRecord.zoneSeconds` continua vindo do Garmin (zonas do relógio) e alimenta só a barra "Relógio" da régua. O tempo por zona pelo limiar é calculado dos samples de FC e guardado num campo novo, que alimenta todo o resto (nota, minutos por zona, foco da carga). Treino sem samples de FC fica sem tempo por zona pelo limiar e não entra nessas somas; a régua mostra só a barra do relógio.
- **Fonte do limiar:** `lactateThresholdHeartRateUsed` do endpoint de zonas de FC que o app já baixa (`HeartRateZonesRecord`). Quando o Garmin não informa limiar, o app usa as zonas do relógio para tudo e a régua mostra só a barra do relógio, com a linha "sem FC de limiar no Garmin".
- **Modelo:** Friel para corrida, a partir da FC de limiar (LTHR). Z1 abaixo de 85%, Z2 de 85% a 89%, Z3 de 90% a 94%, Z4 de 95% a 99%, Z5 a partir de 100%. Arredondamento para bpm inteiro. Percentuais em constantes.
- **Limiar da data do treino:** cada treino usa o limiar vigente no dia em que foi feito. `HeartRateZonesRecord` é uma linha por esporte, sobrescrita a cada sync, então o histórico precisa de um registro novo (dia, FC de limiar), gravado a cada sync em que o valor muda, num `SchemaV4` com migração leve, seguindo as regras de CloudKit da spec principal. O histórico começa vazio: treinos anteriores ao primeiro registro usam o registro mais antigo. Na instalação do plano 4 todo o histórico antigo muda de cor uma vez, o que é a mudança esperada; o anti-objetivo vale daí em diante.
- **Aviso de divergência:** compara o início da Z5 do relógio (`zone5Floor`) com a FC de limiar. Diferença de 3 bpm ou mais, em qualquer direção, mostra a linha "Zonas do relógio N bpm abaixo do limiar" (ou "acima"). Os dados reais do Adriano mostram o relógio abaixo; a fixture sintética do repositório tem o relógio acima, e as duas direções precisam de teste.
- **Onde aparece:** só no detalhe do treino. Lista e Hoje continuam só com a nota.
- **Tempo por zona pelo limiar:** calculado dos samples de FC do treino. Treino sem samples de FC mostra só a barra do relógio, que vem pronta do Garmin.

### Para quem constrói decidir

- Forma exata do registro de histórico do limiar e do campo de tempo por zona pelo limiar.
- Como a nota usa as zonas do limiar internamente. O teto de Z2 e o piso de Z2 da nota (Ruling 3 do plano 3) passam a vir das zonas do limiar.

## Provas reconhecidas

### Decidido pelo Adriano

- O app **pergunta** se uma corrida foi prova. Nunca marca sozinho.
- A pergunta fica **na tela de Provas**.

### Decisões minhas

- **Corrida com cara de prova:** todas as condições abaixo.
  - FIT já processado (`fitProcessed == true`). Corrida ainda não processada espera o reprocessamento antes de ser avaliada, porque a estrutura só existe depois do FIT.
  - Corrida sem treino estruturado (sem `workoutName`/estrutura prescrita).
  - Corrida contínua pela mesma regra de `isContinuous` que já existe (exclui tiros feitos sem treino do Garmin).
  - Distância a até 4% de 5, 10, 21,1 ou 42,2 km.
  - Ritmo em movimento pelo menos 6% mais rápido que a mediana das corridas não estruturadas de distância parecida (±20%) dos 180 dias anteriores. Sem base de comparação, usa a FC média ≥ 95% do limiar da data.
  - Nome com "run", "prova", "maratona", "meia", "K" depois de número ou o selo PR do Garmin reforça, mas não é necessário.
  Limites em constantes. Na base de hoje, essa regra acha quatro corridas no último ano (uma meia, dois 10 km e uma maratona). Os treinos de limiar e intervalado não entram porque são estruturados.
- **Seção "Parece prova?"** na tela de Provas, acima das concluídas. Uma linha por corrida: data, nome no Garmin, distância, tempo e FC média, com os botões "Foi prova" e "Não foi". Some quando não há nada pendente.
- **"Foi prova":** cria um registro de prova concluída já ligado à atividade (nome do Garmin como nome da prova, prioridade C, sem meta). Ela aparece nas concluídas, com selo PR quando for o caso, e o Adriano pode editar como qualquer prova.
- **"Não foi":** a corrida é marcada como recusada e nunca mais aparece.
- **Identidade da decisão:** a chave é o `activityId` do Garmin. "Foi prova" e "Não foi" ficam num registro próprio, separado do `ActivityRecord`, para sobreviver a re-sync e reprocessamento sem o sync sobrescrever. Apagar a prova criada por "Foi prova" não faz a pergunta voltar.
- **Primeira execução:** a detecção varre os últimos 365 dias. Depois disso, só corridas novas que chegam pelo sync.
- **Provas cadastradas em Provas:** quando o dia da prova passa, a prova sem atividade ligada se liga sozinha à corrida do dia com distância a até 4% da prova; com mais de uma, a de distância mais próxima. Nunca sobrescreve uma ligação feita à mão, e uma prova que o Adriano desligou à mão não é religada. Sem corrida compatível, continua como hoje, com o seletor.
- **Na previsão:** prova confirmada (ou cadastrada e ligada) entra como esforço `.race` com a **distância real da atividade** e o **tempo total** (`duration`), que é o tempo de relógio da prova. Hoje `ReportBuilder.efforts` usa a distância nominal da prova; isso muda, porque uma prova 4% mais curta que a nominal desvia a previsão na mesma ordem da tolerância de ±3%.
- **Janela das provas:** esforço `.race` perde peso linearmente até zero em 365 dias, em vez de 150. Os outros tipos de esforço continuam com 150 dias. As duas constantes `effortWindowDays` (Metrics e Insights) continuam iguais entre si e ganham a variante para prova.
- **Calibração:** refeita depois de confirmar as quatro provas do histórico. Alvo do plano 3 mantido: previsões a ±3% do Garmin Connect, VO2max a ±1,5.

## Desempenho

- **Nota do treino guardada.** A nota é calculada uma vez por treino e salva junto da atividade com uma chave das entradas usadas: versão do cálculo, FC de limiar usada, versão do processamento do FIT (samples e estrutura) e a lista de treinos anteriores usados na comparação. A lista lê o valor guardado e só recalcula quando a chave guardada difere da chave atual, fora da main thread. A prontidão do dia não entra na nota (ela só entra na leitura do treino, que não é guardada).
- **Backfill de narrativa fora da main thread.** A análise que alimenta `NarrativeBackfill` roda num `Task.detached` com `ModelContext` próprio, como as outras telas do plano 3. Só o resultado volta para a main.
- **Critério:** abrir o app e rolar a lista de treinos com o histórico completo não pode travar a tela. Medir o tempo da lista antes e depois e registrar no relatório.

## Frases e aviso

- **Validador com direção:** além dos números, o validador recebe o veredito e a direção de cada comparação (acima/abaixo, melhor/pior, subiu/caiu) e rejeita a frase gerada que diga o contrário. Rejeitada, vale o template, como hoje. O veredito estruturado já existe para a prontidão e o estado geral (`ReadinessVerdict`, `OverallVerdict`); se a narrativa do treino só tiver o veredito como texto, quem constrói cria a forma estruturada.
- **Retry do aviso de manhã** (casos parados no review final do plano 3):
  - sync `.launch` que falha não pode deixar `todayReadinessComplete` do dia anterior valendo;
  - teste do caso "execução em background falha com o dia anterior completo → nova tentativa em 1h".

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| O Garmin não informa `lactateThresholdHeartRateUsed` em parte do histórico | zonas pelo limiar ausentes em treinos antigos | registro mais antigo como fallback; régua só com o relógio quando não houver nenhum |
| A detecção pergunta sobre treinos comuns | Adriano perde a confiança na seção | limites conservadores em constantes; "Não foi" é definitivo; anti-objetivo acima |
| Confirmar as provas antigas muda a previsão de uma vez | previsão pula | é a mudança esperada; a calibração é refeita no mesmo plano |
| Nota guardada fica velha | nota errada na lista | regras de recálculo acima, com teste para cada gatilho |

## Verificação

- Testes do pacote com fixtures sintéticas para zonas pelo limiar (modelo, histórico do limiar, treino sem FC), detecção de prova (cada condição e os falsos positivos de treino estruturado), previsão com prova confirmada, nota guardada e seus gatilhos, validador com direção.
- Testes do app para a régua, a seção "Parece prova?" e a ligação automática da prova cadastrada.
- No simulador e no aparelho: a régua no detalhe de uma corrida fácil, a seção "Parece prova?" com as quatro corridas do último ano, a previsão depois de confirmar, comparada ao Garmin.
- Nenhum número real da conta no repositório.
