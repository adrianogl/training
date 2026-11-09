# trAIning — Hoje, Evolução, Provas e sync em background (plano 3) — Design

Data: 2026-11-09. Complementa a spec principal `docs/superpowers/specs/2026-11-07-training-design.md` e o design do plano 2 `docs/superpowers/specs/2026-11-08-app-pos-treino-design.md`. Identidade visual, plataforma, sync, Keychain e a tela do treino continuam valendo como estão. Onde este documento diverge da spec principal, vale este. Pendências herdadas: seção "Estado ao fim do plano 2" de `docs/superpowers/plans/2026-11-08-pendencias-plano-2.md`.

Mockups da conversa (não versionados): `.superpowers/brainstorm/56511-1794262242/content/` — `hoje-v3.html`, `prontidao-v2.html`, `evolucao-v2.html`, `provas-v1.html`.

## Por que

O plano 2 cobriu o uso logo depois do treino. O plano 3 cobre os outros dois momentos:

- **De manhã, antes de treinar:** o Adriano quer saber se o dia é para treino forte ou leve, como está o fitness, quanto falta para a meta da próxima prova e como vai a semana.
- **Olhando a evolução:** quer saber, em poucos segundos, se está melhor ou pior que há 3 meses e quão perto está da meta da prova.
- **Perto da prova:** quer a previsão comparada à meta e a estratégia de pace por km.

## O que não é possível (verificado)

O plano do Treinus não chega ao app antes do treino. O Treinus envia os treinos ao calendário do Garmin Connect pela Training API da Garmin, e a Personal API (a chave que o app usa) não expõe calendário nem treinos agendados; caminhos fora da lista liberada respondem 404. O Treinus não tem API pública nem exportação iCal. Consequências:

- Não existe "volume semanal previsto": a semana mostra só o realizado.
- Não existe "treino de hoje" antes de correr: Hoje mostra o **último treino** comparado com os semelhantes.
- A projeção de fitness até a prova usa uma suposição de carga, não o plano real (ver Métricas).

## Objetivos

1. **Hoje** com prontidão e veredito, fitness até a prova, previsão da prova-alvo, semana realizada, previsões por distância e último treino comparado.
2. **Detalhe da prontidão** mostrando o que puxa a nota para cima e para baixo em relação ao normal dos últimos 30 dias.
3. **Evolução** com um bloco "estado geral" (melhor, estável ou pior que há 3 meses, e distância da meta) e os cards de métrica da spec principal.
4. **Detalhe de métrica** genérico, como descrito na spec principal.
5. **Provas** completa: lista, cadastro com GPX, próxima prova com previsão × meta, estratégia de pace por km, bloco semana a semana, checklist, prova concluída.
6. **Sync em background** com `BGAppRefreshTask` e **aviso de manhã** com a prontidão do dia.
7. **Nota do treino** de 0 a 100 juntando execução e esforço adequado, com decomposição.

## Não objetivos

- Volume semanal previsto, treino do dia antes de correr, qualquer leitura do plano do Treinus.
- Gerar plano de treino (continua v2 da spec principal).
- Anotações manuais nos gráficos (v2).
- Tema claro.
- README e landing page (plano 4).

## Anti-objetivos

- Número que parece real mas é suposição sem aviso. Toda projeção aparece tracejada e com a palavra "projeção" ou "no dia da prova"; a projeção de fitness diz que supõe a carga recente.
- Aviso de manhã com nota parcial ou de ontem. Se o sono ou o HRV da noite ainda não chegaram, não avisa.
- Texto que inventa fato. Frases geradas (veredito da prontidão, resumo do estado geral) seguem a regra do plano 2: o código calcula os fatos, o modelo só redige, e o validador de números descarta frase com número fora dos fatos, com fallback por template.
- Tela vazia no primeiro uso. Sem prova cadastrada, sem 30 dias de histórico ou sem GPX, cada card cai para uma versão reduzida com o motivo em uma linha, nunca some sem explicação.

## Hoje

Ordem dos cards (iPhone: rolagem; iPad: grade com a mesma ordem de leitura). Mockup: `hoje-v3.html`.

1. **Prontidão.** Nota 0–100 grande, veredito em uma frase (descanso / moderado / forte, limites 40 e 70 do código atual), régua vermelho/amarelo/verde e quatro números de apoio: HRV vs base, nota do sono, razão aguda:crônica, stress. Toque abre o Detalhe da prontidão.
2. **Fitness até a prova** (formato da imagem enviada pelo Adriano). Três números: fitness hoje, pico projetado até a prova, forma no dia da prova. Gráfico: fitness (azul) e forma (amarelo), histórico sólido e projeção tracejada, linha vertical em hoje e no dia da prova. Sem prova-alvo: título "Fitness", projeção de 30 dias sem polimento e sem "forma no dia".
3. **Previsão da prova-alvo** (formato da imagem enviada pelo Adriano). Título com a distância e "prova A em N dias". Dois tempos grandes: previsão hoje e previsão no dia da prova. Linha de apoio: faixa da projeção no dia da prova e a previsão de 12 meses atrás. Gráfico: histórico da previsão, projeção tracejada com faixa, linha horizontal da meta e marca vertical no dia da prova. Frase embaixo com a data estimada em que a meta é alcançada, inclusive quando é depois da prova ("Meta de 1:45 deve chegar em meados de janeiro, 4 semanas depois da prova."). Sem prova-alvo: meia maratona, sem meta, sem marca de prova.
4. **Semana.** Km por dia da semana corrente (segunda a domingo), só realizado. Linha de apoio: total da semana passada e média das 4 semanas anteriores.
5. **Previsões por distância.** 5 km, 10 km, 21,1 km e 42,2 km de hoje.
6. **Último treino.** Nome, quando, e a tabela de comparação com os semelhantes que a tela do treino já monta no plano 2 (mesmo `WorkoutAnalysisContext`), mais a frase de evolução. Toque abre a tela do treino.

Saem de Hoje em relação à spec principal: sinais vitais com sparkline, HRV de 30 noites, sono com fases e distribuição de intensidade por zona. Viram cards de Evolução com Detalhe de métrica (decisão minha; o Adriano não pediu esses itens em Hoje).

A prova-alvo segue a spec principal: a próxima prova A; sem prova A, a próxima de qualquer prioridade.

## Detalhe da prontidão

Abre pelo card de Hoje e pelo aviso de manhã. Mockup: `prontidao-v2.html`.

- Nota, veredito e régua no topo.
- Linha de resumo: "+6 sobre o seu normal (68)" e uma frase gerada sobre os fatores.
- Lista "Puxando para cima" e "Puxando para baixo", ordenada pelo tamanho do efeito. Cada fator mostra nome, valor real do dia, o normal do Adriano, peso e os pontos com sinal: HRV da noite (ms), Sono (nota e duração), Body Battery ao acordar, Carga da semana (razão aguda:crônica, com a faixa ideal 0,8–1,3).
- Fator sem dado hoje aparece como "sem dado" no fim da lista.
- Stress aparece como contexto, sem pontos, porque não entra na nota.

Cálculo em Métricas.

## Evolução

Mockup: `evolucao-v2.html`.

- **Estado geral** no topo. Título com o veredito ("Melhor que há 3 meses" / "Estável" / "Pior que há 3 meses"), frase de resumo gerada e tabela com seis indicadores, cada um com valor de hoje, variação em relação a 90 dias atrás e distância da meta quando existe:
  1. Previsão da prova-alvo (sem prova: meia maratona). Única linha com coluna "vs meta".
  2. VO2max.
  3. Fitness.
  4. Pace na Z2.
  5. Pace de limiar.
  6. Volume mensal (escolha do Adriano, no lugar da durabilidade).
- Embaixo, o que a spec principal já previa: seletor de período (6M, 1 ano, 2 anos, Tudo), seletor de horizonte da projeção, destaque da previsão da prova-alvo, e os cards com projeção. Entram também os cards que saíram de Hoje (HRV, sono, FC de repouso, Body Battery, distribuição por zona). Todo card abre o Detalhe de métrica.

## Detalhe de métrica

Como na spec principal, sem mudança: valor atual, média, mínimo, máximo e tendência do período; série diária com média móvel de 7 dias, faixa normal quando existe, marcos de prova e projeção de 60 dias com faixa; valor projetado para o dia da prova-alvo; leitura em texto, médias mensais, comparação com o mesmo período do ano anterior e gráfico de relação quando fizer sentido.

## Provas

Tudo o que a spec principal descreve fica (decisão do Adriano): lista de próximas e concluídas com selo PR, cadastro/edição em sheet com importação de GPX e aviso tranquila/desafiadora/agressiva, próxima prova com contagem, prioridade, meta, previsão hoje, projeção no dia, bloco semana a semana (feito e projeção), checklist de prontidão, leitura do bloco, e prova concluída com resultado × meta × previsão da véspera.

Mudanças e detalhes deste plano. Mockup: `provas-v1.html`.

- **Previsão × meta** no topo da próxima prova: meta (com pace), previsão hoje e no dia da prova, cada uma com a diferença para a meta, e a classificação tranquila/desafiadora/agressiva calculada contra a projeção no dia da prova.
- O sheet de cadastro/edição usa a mesma referência (projeção no dia da prova; sem projeção, previsão de hoje) e diz contra o que comparou, para a mesma prova não aparecer com rótulos diferentes em dois lugares (decisão minha).
- **Estratégia de pace por km** usa como alvo a **previsão no dia da prova** (decisão do Adriano), não a meta. Fallback quando não há projeção (poucos dados): previsão de hoje. Sem previsão nenhuma: a meta. O alvo usado aparece escrito no card.
- **O alvo congela na véspera** (decisão do Adriano): até o dia anterior à prova, a estratégia segue a projeção mais recente; no dia anterior, o alvo é gravado na prova e não muda mais. O card mostra "alvo congelado em <data>". Exige um campo novo em `RaceRecord` (no `SchemaV3`) e entra na exportação/importação de provas.
- A estratégia vem de `paceStrategy` (Minetti pela inclinação do GPX, +5 s nos 2 primeiros km, −3 s nos 3 últimos, paces manuais fixados pelo Adriano e os outros ajustados para fechar o total). Tabela com km, trecho, inclinação, pace e tempo acumulado, sobre a altimetria. Tocar num km fixa um pace manual, gravado em `manualPacesData`. Se `paceStrategy` devolver vazio (paces manuais inviáveis), o card diz isso e oferece limpar os manuais.
- Sem GPX: estratégia plana pela mesma regra, com aviso "sem altimetria".

## Nota do treino

Pedido do Adriano no fim da conversa: uma nota para cada treino realizado que junte **execução** e **esforço adequado**. Cumprir 100% do prescrito com esforço extremamente alto ou extremamente baixo não é treino bom.

- A decomposição mostra, para cada parte, os pontos obtidos sobre o máximo dela (ex.: "Execução 46/50", "Custo 18/25") e o motivo principal de cada perda.
- Nota de 0 a 100 por corrida, calculada no pacote a partir do que o plano 2 já monta (`WorkoutBlock`, `BlockStatus`, `WorkoutComparison`).
- Aparece na tela do treino (topo, ao lado do resumo), na lista de treinos e no card "Último treino" de Hoje. Toque na nota abre a decomposição no mesmo formato do detalhe da prontidão: o que somou e o que tirou, com pontos.
- Natação e força não têm nota.

Composição (pesos são decisão minha, em constantes):

- **Execução (50%)**: só com prescrição. Fração do tempo dos blocos ativos com alvo que ficou `.inTarget`; bloco incompleto ganha crédito igual à fração executada, sem olhar o alvo (o `status` atual não guarda o alvo de bloco incompleto e a regra não muda isso); bloco não executado conta zero. Corrida livre não tem execução e a nota vem só do esforço.
- **Esforço adequado (50%)**, em duas partes iguais:
  - **Intenção do treino** (só com prescrição, pela média de FC de cada bloco):
    - aquecimento e desaquecimento: média até o teto da Z2;
    - treino prescrito como leve (nenhum bloco ativo com alvo acima da Z2): blocos ativos até o teto da Z2;
    - blocos ativos com alvo de FC: dentro do próprio alvo;
    - blocos ativos com alvo de pace: média abaixo do piso da Z2 tira pontos (esforço de menos para um bloco forte); excesso de esforço nesses blocos fica para a parte de custo;
    - recuperação entre tiros fica fora da conta, porque a FC fica alta por inércia.
    Corrida sem prescrição (inclusive prova e longão livre) não tem parte de intenção; a nota vem de custo, e os pesos são redistribuídos.
  - **Custo comparado com você mesmo:** razão velocidade/FC dos blocos ativos (ou do treino inteiro, sem prescrição) contra a mediana das ocorrências anteriores do mesmo treino ou de corridas semelhantes (o mesmo critério da comparação do plano 2). Escala linear: igual à mediana vale 50 dessa parte, 5% mais eficiente vale 100, 5% menos eficiente vale 0. Sem ocorrência anterior, essa parte fica de fora e os pesos são redistribuídos. Com isso, um treino cumprido à risca, no esforço certo e igual às vezes anteriores fica perto de 87; 100 exige também melhora de eficiência.
- Sem zonas de FC, a parte de intenção fica de fora e o card diz o motivo.
- A nota é recalculada ao abrir o treino; não precisa de coluna nova, mas pode ser guardada para a lista se o cálculo pesar (decisão de quem implementa).

## Sync em background e aviso de manhã

- `BGAppRefreshTask` agendado para a madrugada e reagendado a cada execução; o sistema decide quando roda. O sync ao abrir o app continua.
- **Modo background** do `SyncEngine` (pendência do plano 2): não espera em 429; para, grava o cursor e retoma no próximo sync. Respeita o tempo da tarefa com o cancelamento que já existe. Processa poucos `.FIT` por execução e não gera narrativas.
- **Limite de tentativas de FIT com erro transitório** (pendência do plano 2): contador por atividade, com `SchemaV3` e migração leve. Depois do limite, a atividade sai da fila automática e só volta pelo reprocessamento manual em Ajustes.
- **Aviso de manhã** (notificação local):
  - Sai quando um sync (background ou não) calcula a prontidão de hoje com HRV e sono da noite presentes.
  - No máximo um por dia, nunca antes do horário mínimo (padrão 6h). Se a prontidão fica pronta antes do horário mínimo, o aviso é agendado (notificação local com gatilho de calendário) para o horário mínimo; abrir o app antes disso cancela o agendamento, e um recálculo da nota troca o texto agendado.
  - É de melhor esforço: o iOS decide quando o app acorda, e em alguns dias o aviso não sai (o Adriano aceitou esse limite na conversa).
  - Não sai se o Adriano já abriu o app hoje depois que a prontidão de hoje foi calculada.
  - Texto: nota, veredito e os dois fatores de maior efeito contra o normal ("Prontidão 74 · pode treinar forte. HRV acima do seu normal, sono abaixo."). Template, sem modelo de linguagem, para não depender de Foundation Models em background.
  - Toque abre o Detalhe da prontidão.
  - Ajustes ganha chave liga/desliga e o horário mínimo.

## Métricas

### Fatores da prontidão contra o normal

A nota atual é `Σ wᵢ·cᵢ / Σ wᵢ` sobre os componentes presentes (HRV 35%, sono 25%, Body Battery 20%, carga 20%), como em `Metrics/Readiness.swift`.

- Normal de cada componente: média da nota do componente (`cᵢ`, 0–100) nos 30 dias anteriores a hoje, sem contar hoje, usando só os dias em que o componente existe. Exige pelo menos 14 dias; abaixo disso o fator mostra só o valor do dia, sem pontos.
- Pontos de cada fator: `w̃ᵢ · (cᵢ hoje − normalᵢ)`, onde `w̃ᵢ` é o peso renormalizado entre os componentes presentes hoje.
- Normal da prontidão exibido no resumo: `nota de hoje − Σ pontos`. Assim a soma dos fatores fecha exatamente com a diferença mostrada (decisão minha; a média simples das notas dos 30 dias pode diferir alguns décimos quando houve dia parcial).
- O valor real exibido ao lado (ms, nota do sono, razão) e o normal real correspondente são médias dos valores brutos no mesmo período.

### Prontidão é o estado da manhã

A carga aguda:crônica que entra na prontidão de um dia vai só até o dia anterior (decisão minha). Hoje `updateReadiness` soma a carga do próprio dia, e a nota muda depois que o Adriano corre; o aviso diria 74 e o card mostraria outro número. Com a carga até D-1, a nota do dia fica estável depois da manhã e o normal de 30 dias passa a comparar manhãs com manhãs. Isso muda `DerivedMetrics.updateReadiness` e exige recalcular a prontidão de todo o histórico uma vez (no primeiro sync depois da atualização), além de ajustar os testes do plano 2 que dependem disso.

### Estado geral

- Variação de cada indicador: valor de hoje menos o valor calculado como se hoje fosse 90 dias atrás, com a mesma função.
- Margem mínima para contar como mudança (decisão minha, ajustável em constantes): previsão 0,5%; VO2max 0,5; fitness 2; pace na Z2 e de limiar 3 s/km; volume mensal 10%.
- Veredito: "Melhor" se os que melhoraram superam os que pioraram por 2 ou mais; "Pior" no inverso; senão "Estável". Indicador sem dado nos dois pontos fica fora da conta e aparece com "—".

### Projeção de fitness até a prova

Sem o plano do Treinus, a carga futura é suposta (decisão minha, apresentada ao Adriano sem objeção):

- Carga diária futura = média diária das últimas 4 semanas.
- Nas 2 semanas antes da prova, carga reduzida em 40% (polimento padrão).
- Fitness, fadiga e forma projetados com a mesma `fitnessFatigueForm` aplicada à série de carga estendida.
- "Pico" = maior fitness projetado entre hoje e a prova; "forma no dia" = forma no dia da prova.

### Previsão da prova ao longo do tempo

- Série diária da previsão para a distância da prova-alvo, calculada com `predict` como se cada dia fosse hoje (esforços dos 90 dias anteriores àquele dia).
- Projeção com `project` (regressão linear de 90 dias, faixa de 95%) até o dia da prova; "no dia da prova" é o `mid` desse dia e a faixa é `low`–`high`.
- Data em que a meta é alcançada: `targetCrossing`, inclusive depois da prova, com horizonte de 1 ano. Meta já batida na tendência (`targetCrossing` nil porque a tendência já passou da meta): a frase diz "a previsão já está abaixo da meta" (pendência do plano 2). Tendência indo para longe da meta: "na tendência atual, a meta não é alcançada".

## Restrições

As do plano 2 continuam:

- iOS/iPadOS 26, simulador iPhone 18 Pro (iOS 27.1), `scripts/dev-run.sh` depois de cada tarefa que muda UI.
- Identidade: fundo `#07080A`, destaque `#C8F05A`, laranja `#FF8A4C` só para prova, azul `#7FB2FF` para fitness/sono; números SF Pro condensados; só tema escuro; Liquid Glass nos cards.
- Repositório público: nenhum dado real no git; fixtures sintéticas.
- SwiftData compatível com CloudKit, `cloudKitDatabase: .none`.
- Sem comentários no código; types em `*Types.swift`, constantes em `*Constants.swift`.
- Testes: Swift Testing no pacote e `xcodebuild test` no app.
- Lógica nova no pacote `Packages/TrainingKit`; as telas só consomem.
- Capabilities novas: Background Modes (fetch) e notificações locais. Nada de push remoto.

## Textos gerados e por template

Decisão minha, para manter o plano no tamanho certo:

- **Foundation Models** (com validador de números e fallback, como no plano 2): só a frase do detalhe da prontidão e o resumo do estado geral.
- **Template**: leitura do Detalhe de métrica, leitura do bloco da prova, "o que a prova ensinou", aviso de manhã. Nenhum desses textos é guardado no schema; são montados ao abrir a tela.

## Calibração com o Garmin Connect

Entra neste plano como tarefa manual com o Adriano, antes das telas que mostram previsão (decisão minha, porque as previsões viraram o centro de Hoje, Evolução e Provas): comparar VO2max (alvo ±1,5) e previsões 5/10/21/42 (alvo ±3%) com o que o Garmin Connect mostra na conta real, e ajustar constantes de `Metrics` se ficar fora. Os números da conta real não entram no repositório; o commit leva só as constantes ajustadas.

## O que fica com quem implementa

- Layout fino de cada card e o desenho da grade no iPad, seguindo os mockups e a identidade.
- Como guardar ou recalcular as séries diárias (previsão, fitness, componentes da prontidão): cache em SwiftData ou cálculo sob demanda, desde que a abertura de Hoje não trave a main thread.
- Prompt e schema das frases geradas (veredito da prontidão, estado geral), seguindo o padrão do target `Narrative`.
- Itens do checklist de prontidão da prova e o texto da leitura do bloco, a partir do que a spec principal lista.
- Limite exato de tentativas de FIT e de `.FIT` por execução em background.
- Ordem das tarefas no plano.

## Decisões minhas (para conferir)

- Cards que saíram de Hoje vão para Evolução.
- Polimento padrão: carga média de 4 semanas, −40% nas 2 semanas finais.
- Normal da prontidão exige 14 dias de dado nos últimos 30; normal exibido = nota − soma dos pontos.
- Margens mínimas e regra do veredito do estado geral.
- Aviso: padrão 6h, um por dia, só com HRV e sono da noite, não sai se o app já foi aberto, texto por template.
- Estratégia sem projeção cai para previsão de hoje e depois para a meta; sem GPX vira estratégia plana.
- Coluna "vs meta" só na previsão da prova.
- Prontidão usa a carga até o dia anterior; recalcula o histórico uma vez.
- Aviso antes do horário mínimo vira notificação agendada para o horário mínimo.
- Classificação da meta usa a projeção no dia da prova também no cadastro.
- Só a frase da prontidão e o resumo do estado geral usam Foundation Models; o resto é template.
- Calibração com a conta real entra como tarefa manual antes das telas de previsão.
- Nota do treino: execução 50%, intenção 25%, custo 25%; custo linear com 50 na mediana e saturação em ±5%; recuperação e corridas sem prescrição fora da intenção; bloco incompleto vale a fração executada; decomposição em pontos sobre o máximo de cada parte.
