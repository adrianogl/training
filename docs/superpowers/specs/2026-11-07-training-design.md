# trAIning — design

Data: 2026-11-07
Mockups de referência: https://claude.ai/artifact/DUEvUG9uEpVXkNUYYVaZ4B (linhas "Fusão" em diante valem; as linhas A/B/C e 1–4 foram exploração e estão superadas)

## Por que existe

O Adriano corre com um Garmin Forerunner 965 e quer acompanhar a evolução de forma mais completa do que o Garmin Connect e o Strava mostram: o histórico longo, a projeção de onde ele vai chegar, e a preparação para provas que ele mesmo cadastra. A referência inicial foi a série "Which Garmin dashboard are you?" (Kevin Rudd), da qual saíram as ideias de Commander, Recovery Nerd, Tinkerer, Racer e Archivist.

Em outubro de 2026 o Garmin abriu a **Personal API**: uma chave pessoal, só leitura, para acessar os próprios dados. Isso torna viável um app nativo sem backend.

## Objetivos

- App nativo iOS para **iPhone e iPad**, chamado **trAIning**.
- Mostrar o estado do dia (prontidão), a evolução de longo prazo e uma **projeção futura** de cada métrica, com faixa de incerteza.
- Cada gráfico abre um **detalhe** com seletor de período (7 dias até "tudo") e projeção.
- Cadastrar **provas-alvo** (e provas já feitas) e ver tudo em função da próxima prova: contagem, meta, previsão, projeção no dia, prontidão.
- Ler os treinos um a um, com parciais, zonas, mapa e uma leitura em texto.
- Funcionar só com os dados do próprio usuário, sem servidor.

## Não objetivos (v1)

- Gerar plano de treino automaticamente. O checkbox "Gerar plano de treino até a prova" dos mockups sai da v1; as barras "planejado" do bloco viram projeção por tendência (ver Métricas). Fica para a v2.
- Enviar treino para o relógio (a Personal API não permite).
- Endurance score e hill score do Garmin (não vêm na API e a fórmula é proprietária). No lugar entram duas métricas próprias com fórmula aberta, **Durabilidade** e **Força em subida** (ver Métricas).
- Multiusuário, treinador, painel web, Android.
- Publicar na App Store. É um app pessoal.
- Sync automático entre iPhone e iPad e widget. O usuário tem só conta gratuita de desenvolvedor Apple (Personal Team), que não libera CloudKit, iCloud Keychain sincronizado nem App Group. Ver "Conta Apple e instalação".

## Anti-objetivos

- Mostrar um número calculado pelo app como se fosse do Garmin. Toda métrica calculada traz o rótulo "trAIning" ou um ícone de origem; a previsão de prova diz "previsão trAIning", nunca "previsão Garmin".
- Projeção sem faixa de incerteza. Projeção é sempre linha tracejada com faixa.
- Dados de saúde saindo do aparelho do usuário para qualquer serviço de terceiros.

## Identidade visual (decidida)

- Nome: **TRAINING** em caixa alta, com "AI" na cor de destaque. Frase embaixo da logo: **"Inteligência do pulso à linha de chegada."** (prancheta "trAIning · marca e frases" no canvas).
- Estilo "Fusão": fundo quase preto `#07080A`, cards de vidro translúcido (material Liquid Glass do iOS 26 no app nativo), brilho de cor difuso no fundo, números grandes em fonte condensada, texto em fonte sem serifa.
- Cores: destaque verde-limão `#C8F05A`; laranja `#FF8A4C` reservado para prova; azul `#7FB2FF` para fitness/sono; vermelho `#FF5A5A`/amarelo `#FFC93B`/verde para a régua de prontidão.
- Fonte condensada dos números: nos mockups é Barlow Condensed. No app, usar SF Pro com largura `.compressed`/`.condensed` (decisão minha: evita embutir fonte e fica nativo). Se o resultado visual ficar fraco, embutir Barlow Condensed (licença OFL).
- Ícone do app: "AI" em verde sobre fundo escuro com brilho (rascunho no canvas; arte final é com o builder).
- Só tema escuro na v1 (decisão minha).

## Plataformas e requisitos

- iOS/iPadOS **26** como mínimo (decisão minha): Liquid Glass e o framework Foundation Models são do 26.
- iPhone: tab bar flutuante (Hoje, Evolução, Treinos, Provas). iPad: barra lateral com as mesmas seções e um card fixo da prova-alvo embaixo.
- Unidades métricas, idioma pt-BR.

## Telas

As telas e o conteúdo de cada card estão nos mockups. Resumo do que cada uma precisa ter:

**Hoje** (iPhone: rolagem; iPad: grade)
- Prontidão (0–100) grande, veredito em uma frase, régua vermelho/amarelo/verde, e quatro números de apoio: HRV vs base, nota do sono, razão aguda:crônica, stress.
- Sinais vitais com sparkline: HRV, sono, FC de repouso, VO2max, Body Battery.
- HRV de 30 noites com a faixa base sombreada.
- Sono da última noite com fases.
- Fitness/fadiga/forma em 90–120 dias.
- Semana: km por dia, meta semanal, distribuição de intensidade por zona (28 dias).
- Últimos treinos.
- Próxima prova: contagem, meta, previsão, projeção, progresso do longão.

**Evolução**
- Seletor de período (6M, 1 ano, 2 anos, Tudo) e seletor de horizonte da projeção (até a prova, 6 meses, 1 ano).
- Destaque: previsão de tempo da distância da prova-alvo (se não houver prova, a meia maratona), com histórico, projeção, linha da meta e a data estimada em que a meta é alcançada.
- Cards com projeção: VO2max, pace na Z2, fitness, volume mensal, foco da carga, pace/FC de limiar, previsões por distância (5/10/21/42), Durabilidade e Força em subida (no lugar do card "Endurance · Hill score" do mockup), dinâmica de corrida (cadência, contato com o solo, oscilação vertical), FC de repouso, heatmap de atividades.
- Todo card abre o Detalhe.

**Detalhe de métrica** (um componente genérico, parametrizado pela métrica)
- Valor atual, média, mínimo, máximo e tendência do período.
- Gráfico com série diária, média móvel de 7 dias, faixa normal (quando a métrica tem uma, como o HRV), marcos (provas, e na v1 só provas; anotações manuais ficam para a v2) e projeção de 60 dias com faixa.
- Valor projetado para o dia da prova-alvo.
- Leitura em texto, médias mensais, comparação com o mesmo período do ano anterior e, quando fizer sentido, um gráfico de relação (ex.: HRV × carga da semana anterior).

**Treinos**
- Lista com filtro Todos / Corrida / Força / Natação (os mockups mostram só Corrida e Força; Natação entra porque o usuário nada).
- Detalhe do treino: efeito aeróbico e anaeróbico com rótulo, distância, tempo, pace, FC, carga, cadência; mapa do percurso e altimetria; parciais por km com pace colorido por intensidade e FC; curva de FC com faixas de zona e tempo em cada zona; leitura em texto e comparação com treinos parecidos (mesmo tipo e distância ±20%, últimos 90 dias).
- Natação e força mostram o que a API trouxer (tempo, FC, carga, distância/piscina), sem parciais por km nem dinâmica de corrida.

**Provas**
- Lista de próximas e concluídas. Prova concluída com recorde pessoal ganha selo PR.
- Próxima prova: contagem, prioridade A/B/C, meta, previsão hoje, projeção no dia, bloco semana a semana (feito e projeção), checklist de prontidão, estratégia de pace por trecho sobre a altimetria do GPX importado, leitura do bloco.
- Prova concluída: resultado vs meta vs previsão da véspera, parciais, "o que a prova ensinou". O resultado é ligado a uma atividade do Garmin (o usuário escolhe a atividade, ou o app sugere a corrida do dia com distância compatível).

**Cadastrar/editar prova** (sheet)
- Nome, data, horário de largada, distância (5/10/21,1/42,2/outra), meta de tempo, prioridade A/B/C, cidade, importar GPX.
- Ao digitar a meta, mostra pace alvo, previsão atual e a diferença, com o aviso tranquila / desafiadora (>1%) / agressiva (>6%).
- A prova-alvo mostrada em Hoje e na barra lateral é a próxima prova A; sem prova A, a próxima de qualquer prioridade.

**Ajustes**
- Colar a chave da Personal API, ver validade, testar conexão, forçar sync, exportar/importar provas, apagar todos os dados locais.

## Origem dos dados

Tudo vem da Garmin Connect Personal API, base `https://personal.connectapi.garmin.com`. Referência de endpoints: cliente oficial em Python, https://github.com/garmin/connect-personal-api-python (`client.py`).

Autenticação: `POST /personalapitoken-service/personal-api/personal-api-key/token` com header `Authorization: ApiKey <chave>` retorna um JWT (texto puro) válido por cerca de 24 h; renovar quando faltar menos de 1 h para o `exp`. Chamadas com `Authorization: Bearer <jwt>`. A chave vale de 30 dias a 1 ano, conforme o usuário escolheu ao criar.

Testado em 2026-11-07 com a conta do usuário:

| Dado | Endpoint | Limite por chamada | Observação |
|---|---|---|---|
| Perfil | `/userprofile-service/userprofile/settings` | — | |
| Zonas de FC | `/biometric-service/heartRateZones/v2` | — | método por limiar; traz FC de limiar (175) e máxima (184) |
| Resumo diário | `/usersummary-service/v2/dailysummaries?startDate&endDate` | até 180 dias | FC repouso, stress, Body Battery, intensidade, respiração, SpO2 |
| HRV | `/hrv-service/hrv/daily/{ini}/{fim}` | 180 dias | média da noite, 7 dias, status, faixa base; detalhe do dia em `/hrv-service/hrv/{data}` |
| Sono | `/sleep-service/sleep/dailySleepSummariesByDate?startDate&endDate` | 28 dias | fases, nota e componentes; detalhe em `/sleep-service/sleep/dailySleep?date=` |
| Body Battery | `/wellness-service/wellness/bodyBattery/reports/daily?startDate&endDate` | 28 dias | série do dia e eventos |
| Stress / passos | `/usersummary-service/stats/{stress,steps}/daily/{ini}/{fim}` | 7 dias | |
| FC do dia | `/wellness-service/wellness/dailyHeartRate?date=` | 1 dia | |
| Fitness age | `/fitnessage-service/fitnessage/v2/{data}` | — | |
| Peso | `/weight-service/weight/range/{ini}/{fim}?includeAll=true` | — | |
| Atividades | `/activitylist-service/activities/search/activities?start&limit[&startDate&endDate&activityType]` | 50 por página | ~750 atividades, desde 2024 |
| Atividade | `/activity-service/activity/{id}` | — | |
| `.FIT` original | `/download-service/files/activity/{id}` | — | ZIP; exige `Accept: */*` (com `application/zip` retorna 406) |

Histórico disponível: HRV e atividades a partir de 2024. Requisições acima dos limites retornam 400 vazio. Rate limit não é publicado.

**Não disponível** (404 ou campo ausente): VO2max, training status, training readiness, race predictor, carga aguda/crônica, foco da carga, endurance score, hill score, pace de limiar, recovery time.

**Mensagem 140 do `.FIT`** (sem documentação, engenharia reversa da comunidade e conferida contra o Garmin Connect em 10 corridas):
- campo 7: VO2max da corrida = `valor / 65536 × 3,5`. Ficou entre 0 e ~1,3 ponto abaixo do valor exibido pelo Garmin, que é suavizado.
- campo 9: provavelmente recovery time em minutos (39–76 h nas amostras). Não confirmado.
- campo 17: provavelmente performance condition (−6 a +1). Não confirmado.

Esses campos são fonte "bônus": se faltarem ou mudarem, o app usa o cálculo próprio (abaixo) e a tela não quebra.

## Métricas

Origem de cada métrica e como o app chega no número. Valores de peso, janela e corte são o ponto de partida da v1 e podem ser calibrados depois com os dados do usuário.

| Métrica | Origem | Como |
|---|---|---|
| HRV, faixa base, status | Garmin | direto |
| Sono (duração, fases, nota) | Garmin | direto |
| Body Battery, stress, FC repouso, respiração, SpO2 | Garmin | direto |
| Zonas de FC e FC de limiar | Garmin | direto |
| Efeito de treino, rótulo, carga por atividade, dinâmica de corrida, potência, tempo em zona, parciais, melhores 1 km / milha / 5 km | Garmin | direto, por atividade |
| VO2max | `.FIT` msg 140 | média móvel exponencial de 14 dias sobre o valor de cada corrida; mostrado com 1 casa |
| Fitness / fadiga / forma | trAIning | carga diária = soma de `activityTrainingLoad` de todas as atividades do dia (todos os esportes). Fitness = MME 42 dias; fadiga = MME 7 dias; forma = fitness − fadiga do dia anterior |
| Razão aguda:crônica | trAIning | carga dos últimos 7 dias ÷ (carga dos últimos 28 dias ÷ 4) |
| Prontidão (0–100) | trAIning | 35% HRV, 25% nota do sono, 20% Body Battery, 20% carga. **HRV** (média da noite contra a faixa base do Garmin): abaixo de `lowUpper` = 0; entre `lowUpper` e `balancedLow` = rampa linear de 0 a 60; de `balancedLow` a `balancedUpper` = rampa de 60 a 100; acima = 100. **Body Battery** = maior valor entre o fim do sono e 3 h depois. **Carga**: A:C entre 0,8 e 1,3 = 100, caindo linearmente até 0 em 0,5 e 1,8. **Componente faltando** (ex.: relógio fora do pulso à noite): redistribuir o peso proporcionalmente entre os presentes e marcar a nota como parcial; sem HRV **e** sem sono, não mostrar nota ("sem dados da noite"). Veredito: < 40 "descanso ou regenerativo", 40–69 "treino moderado", ≥ 70 "treino forte liberado" (decisões minhas, calibráveis) |
| Pace na Z2 | trAIning | por corrida, pace médio dos registros do `.FIT` com FC dentro da Z2 (limites das zonas do Garmin), descartando os 10 primeiros minutos; série = mediana semanal |
| Pace e FC de limiar | trAIning | FC = `lactateThresholdHeartRateUsed`; pace = mediana do pace nos trechos de ≥ 5 min contínuos com FC em limiar ±3 bpm, últimos 60 dias |
| Foco da carga | trAIning | a carga de cada atividade é repartida pelo tempo em zona: Z1–Z2 → aeróbico baixo, Z3–Z4 → aeróbico alto, Z5 → anaeróbico; janela de 28 dias. Faixa ideal de referência na v1: 60–75% / 20–35% / 5–10% |
| Previsões de prova (5/10/21/42) | trAIning | Riegel `T2 = T1 × (D2/D1)^1,06` a partir do melhor esforço dos últimos 90 dias (resultado de prova cadastrada, ou `fastestSplit_5000`, ou `fastestSplit_1000` com peso menor); quando há várias fontes, a mais recente e mais longa pesa mais |
| Projeções | trAIning | regressão linear sobre a série suavizada dos últimos 90 dias, extrapolada até o horizonte; faixa = ±1,96 × desvio dos resíduos × √(1 + h/n). VO2max com teto suave (desacelera conforme passa de +4 pontos sobre a média de 1 ano). Data estimada da meta = quando a projeção central cruza a meta |
| Bloco da prova | trAIning | semanas desde 12 semanas antes da prova: km feitos por semana; semanas futuras = projeção pela média das últimas 4 semanas (sem plano na v1) |
| Checklist de prontidão da prova | trAIning | VO2max vs início do bloco, longão mais longo vs alvo (alvo do longão: 90% da distância para 21 km, 75% para 42 km, 100% para 5/10 km), pace de limiar vs pace alvo, HRV vs base, forma projetada no dia |
| Durabilidade | trAIning | desacoplamento aeróbico (pace:FC) em corridas contínuas de ≥ 60 min: razão velocidade/FC da segunda metade ÷ razão da primeira metade, descartando os 10 primeiros minutos; resultado em % de queda (< 5% bom, 5–10% ok, > 10% fraco). Corridas com tiros (efeito anaeróbico ≥ 2 ou rótulo de intervalado) ficam de fora. Série = mediana móvel das últimas 4 corridas elegíveis |
| Força em subida | trAIning | por corrida, nos trechos de ≥ 200 m com inclinação ≥ 4% (do `.FIT`): pace ajustado pela inclinação (Minetti) dividido pelo pace dos trechos planos (±1%) da mesma corrida, na mesma faixa de FC (±5 bpm). Índice 100 = sobe no mesmo esforço do plano; acima de 100 = sobe melhor. Série = mediana móvel de 4 semanas. Corridas sem subida suficiente não entram |
| Estratégia de pace por trecho | trAIning | ver "Estratégia de pace" |
| Leituras em texto | trAIning | ver "Textos" |

### Estratégia de pace (decisões minhas)

- **Trechos**: o GPX é dividido por km. Kms consecutivos com a mesma classe de inclinação (subida > +2%, descida < −2%, plano no resto) são agrupados num trecho para o gráfico; a tabela mostra km a km.
- **Pace por km**: esforço constante. Parte do pace alvo da meta e ajusta pela inclinação média do km com o modelo de custo energético de Minetti (2002), o mesmo princípio do "grade adjusted pace". Os paces são normalizados para que o tempo total feche com a meta.
- **Saída e final**: os 2 primeiros km ficam 5 s/km mais lentos e os últimos 3 km 3 s/km mais rápidos, compensados no meio para manter o total.
- **Rótulos**: automáticos, só "aquece", "subida", "descida", "plano" e "final". Rótulo livre (como "ponte") é editável pelo usuário.
- **Edição**: o usuário ajusta o pace de um trecho; o valor fica gravado na prova (sincroniza) e marcado como manual. Quando a meta muda, os trechos não editados são recalculados para fechar o total, e os editados ficam como estão; um botão "Recalcular tudo" descarta as edições.
- **Sem GPX**: trechos de 1 km, planos, com o mesmo ajuste de saída e final.

## Textos ("AI")

Leitura do dia, do treino, do bloco, da prova e do detalhe de métrica.

- Gerados no aparelho com o framework **Foundation Models** da Apple (decisão minha): grátis, privado, offline.
- O modelo recebe só fatos já calculados (números, comparações, rótulos), nunca dados brutos, e devolve 1 a 3 frases em pt-BR. Usar geração guiada (`@Generable`) para manter o formato.
- Quando o modelo não estiver disponível (aparelho sem Apple Intelligence, modelo baixando, recurso desligado), usar texto montado por template com os mesmos fatos. A tela nunca fica vazia.
- Os textos são gerados no sync e guardados; não gerar ao abrir cada tela.

## Arquitetura

- **SwiftUI** + **Swift Charts**, um único target universal (iPhone e iPad). Sem widget na v1.
- **SwiftData local** em cada aparelho. Cada aparelho busca os próprios dados no Garmin.
  - O modelo já segue as restrições do CloudKit (sem `@Attribute(.unique)`, relacionamentos opcionais, valores padrão em tudo), pra que ligar o sync pelo CloudKit no futuro seja só configuração (decisão minha). A deduplicação é do sync: chave natural = `activityId` para atividades e `calendarDate` para dados diários; upsert procurando pela chave.
- **Keychain local** (sem `kSecAttrSynchronizable`) para a chave da API; o usuário cola a chave em cada aparelho. O JWT fica em memória/Keychain local.
- **Provas entre aparelhos**: "Exportar provas" gera um arquivo `.json` (provas, metas, edições de pace, GPX) pelo menu de compartilhar (AirDrop, Arquivos); "Importar provas" lê o arquivo e faz upsert por um `id` UUID da prova. Na importação, a prova editada mais recentemente vence (campo `updatedAt`).
- **`.FIT`**: SDK oficial `garmin/fit-swift-sdk` via Swift Package Manager. O arquivo é baixado, processado e descartado; guardar só o derivado (série de pace/FC/altitude reamostrada a cada 5 s para os gráficos do treino, polilinha simplificada do percurso, campos da msg 140). Arquivos `.FIT` não ficam guardados.
- Módulos (pacotes Swift locais, testáveis sem UI):
  - `GarminAPI`: autenticação, endpoints, paginação, limites por endpoint, retry com backoff em 429/5xx.
  - `FITReader`: extração dos derivados e da msg 140.
  - `Metrics`: todas as fórmulas da seção Métricas, funções puras.
  - `Projections`: regressão, faixa, data de cruzamento da meta.
  - `Narrative`: Foundation Models + templates.
  - `Sync`: orquestra, grava no SwiftData.
- Sem backend.

## Sync

- **Primeira carga**: todo o histórico disponível (desde 2024), em janelas respeitando os limites de cada endpoint, uma requisição por vez. Mostrar progresso. Pode levar alguns minutos; o app fica usável com o que já chegou.
- **Incremental**: ao abrir o app e via `BGAppRefreshTask` (madrugada/manhã). Rebusca sempre os últimos 3 dias de dados diários (sono e HRV são finalizados depois) e as atividades novas desde a mais recente gravada (e as alteradas nos últimos 3 dias).
- **Quem sincroniza**: cada aparelho, de forma independente. O upsert por chave natural evita duplicata quando o mesmo dia é buscado de novo. Recalcular métricas derivadas depois de cada sync, a partir dos dados gravados.
- **Erros**: 401 na troca de token → chave inválida/vencida, aviso em Ajustes e banner em Hoje. 400 → janela grande demais (bug do app, logar). 429 → backoff exponencial e retomar no próximo sync.
- **Validade da chave**: avisar 14 dias antes de vencer, com atalho para a página de criação de chave no Garmin Connect.

## Repositório, README e landing page

O repositório é **público** no GitHub (o que também libera o GitHub Pages no plano gratuito) e carrega a mesma identidade visual do app.

- **README**: logo TRAINING (com "AI" em verde) e a frase embaixo, como imagem SVG com variante clara/escura via `<picture>` e `prefers-color-scheme` (o GitHub renderiza README em tema claro ou escuro, conforme o usuário). Depois: uma imagem de capa com as telas do iPhone e do iPad, o que o app faz, de onde vêm os dados (Personal API do Garmin) e o que é calculado pelo trAIning, requisitos (iOS 26, chave da Personal API), como rodar no Xcode, e o aviso de que é um projeto pessoal sem vínculo com o Garmin.
- **Landing page** no GitHub Pages, publicada a partir de `docs/site/` (ou branch `gh-pages`, escolha do builder), estática, sem build (HTML + CSS, sem framework):
  - mesma linguagem visual dos mockups: fundo `#07080A`, brilhos difusos, cards de vidro, números condensados, verde `#C8F05A` e laranja `#FF8A4C`;
  - hero com a logo, a frase e uma composição iPhone + iPad com as telas Hoje e Evolução;
  - seções curtas: o dia (prontidão), a evolução com projeção, os treinos, as provas, os dados (o que vem do Garmin e o que o app calcula), privacidade (sem servidor, dados só no aparelho);
  - funciona em celular (sem rolagem horizontal) e respeita `prefers-reduced-motion`;
  - fonte condensada: Barlow Condensed pelo Google Fonts (na web não existe SF Pro compressed);
  - as imagens das telas usam números de exemplo, nunca os dados reais do usuário.
- Nome "Garmin" só como referência à fonte dos dados, sem logo nem identidade visual da marca.
- Nenhum dado do usuário, chave, `.FIT` ou JSON de resposta da API entra no repositório. `.gitignore` cobre as pastas de dados de teste.

## Conta Apple e instalação

- Conta gratuita (Personal Team): instalação pelo Xcode, por cabo ou Wi-Fi, no iPhone e no iPad.
- O perfil de provisionamento vence a cada 7 dias. Depois disso o app não abre até ser instalado de novo pelo Xcode; os dados são preservados porque o bundle id é o mesmo. O README explica o passo.
- Capabilities usadas: só Background Modes (para o `BGAppRefreshTask`). Nada de iCloud, App Groups ou Keychain Sharing.
- Se o usuário assinar o Apple Developer Program depois, a evolução prevista é: CloudKit para o SwiftData, Keychain sincronizado, App Group e widget. O modelo de dados já está pronto pra isso.

## Privacidade

- Dados ficam só no aparelho. Nenhuma telemetria, nenhum serviço de terceiros.
- "Apagar todos os dados locais" em Ajustes apaga SwiftData, Keychain e caches.

## Riscos

| Risco | Efeito | Mitigação |
|---|---|---|
| Msg 140 do `.FIT` muda ou some | VO2max sem fonte | fallback: VO2max estimado (VDOT de Daniels a partir da previsão de 5 km), rotulado como estimativa |
| Garmin muda limites ou endpoints da Personal API | sync quebra | `GarminAPI` isolado, limites em constantes, testes com respostas gravadas |
| Rate limit não publicado | primeira carga interrompida | uma requisição por vez, backoff, carga retomável |
| Foundation Models indisponível no aparelho | sem texto gerado | templates |
| Fórmulas próprias divergem do Garmin | número "estranho" para o usuário | rótulo de origem; durante o desenvolvimento, comparar com os valores do Garmin Connect (o usuário tem acesso pelo MCP do Garmin) |
| Duplicatas no banco local | gráficos dobrados | upsert por chave natural e uma rotina de limpeza de duplicatas no início do sync |
| Perfil gratuito vence em 7 dias | app não abre até reinstalar | passo documentado no README; dados preservados |

## Validação

- Testes unitários de `Metrics` e `Projections` com séries sintéticas e com um recorte dos dados reais do usuário (JSON gravado, sem a chave).
- Conferir no aparelho, com os dados reais: VO2max suavizado próximo do Garmin (±1,5), fitness/fadiga com a mesma forma de curva do "training load" do Garmin Connect, previsões de prova dentro de ±3% do race predictor do Garmin.
- Conferir a primeira carga completa sem 400/429 e sem duplicatas depois de vários syncs seguidos.
- Exportar provas no iPad e importar no iPhone, editar a mesma prova nos dois e reimportar: a edição mais recente vence.

## Deixado para o builder

- Versões de iPhone de Treinos, Provas, Detalhe e Cadastro: não têm mockup; adaptar do iPad seguindo o estilo Fusão (lista → detalhe em navegação empilhada).
- Onde o mockup diverge desta spec (ex.: "Plano cadastrado" no checklist, "previsão do Garmin"), vale a spec.

- Estrutura de pastas, nomes de tipos, organização dos pacotes.
- Detalhes visuais finos (espaçamentos, animações, transições), seguindo os mockups e o estilo Fusão.
- Arte final do ícone.
- Estratégia de reamostragem e simplificação de polilinha.
- Ordem de implementação (sugestão: GarminAPI → Sync → Metrics → Hoje → Treinos → Evolução/Detalhe → Provas → Narrative → README e landing page).
