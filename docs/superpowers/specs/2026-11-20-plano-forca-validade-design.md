# Plano de força com validade

Data: 20/11/2026 · Mock aprovado: https://claude.ai/artifact/BbmYv5kuRfnLuefp1XsFcs

## Por quê

Pedir "mobilidade na terça e na quinta" ao Claude cria treinos presos a datas, sem um plano que diga até quando aquilo vale. As sessões de força do Treinador não têm validade nenhuma: seguem para sempre. O usuário quer montar a força como monta a corrida, com características e validade.

## Objetivos

1. Criar um plano de força com objetivo, dias e validade, montado pelo Treinador ou pelo Claude.
2. Mostrar o plano ativo com o progresso (semana N de M, treinos feitos).
3. Quando o plano acaba, os dias dele deixam de aparecer e chega uma notificação depois do último treino.
4. MFIT em paralelo: o plano nunca substitui um treino do MFIT. Dia com os dois mostra os dois.

## Fora do escopo

- Mais de um plano de força ativo ao mesmo tempo (o mock mostra um por vez).
- Mudar a parte de corrida do plano do Treinador.
- Substituir treino do MFIT pelo plano (a opção `replacesMFIT` deixa de ser oferecida para treinos do plano).

## O que não pode acontecer

- Treino do MFIT escondido ou trocado por causa do plano de força.
- Plano que termina e continua gerando treino.
- Perder as sessões de força que o usuário já configurou hoje.

## Abordagens

| Abordagem | Trade-off | Decisão |
| --- | --- | --- |
| Validade dentro do plano de corrida (`TrainerPlan.strength`) | Menos código, mas a força morre e nasce junto com a corrida | Descartada: o usuário quer validade própria |
| **Plano de força independente, com store e sincronização próprios** | Mais código, mas cada plano tem início, fim e objetivo | **Escolhida** |
| Só dar período aos pedidos do Claude | Não resolve as sessões do Treinador | Descartada |

## Desenho

### Modelo

`StrengthPlan`: `id`, `objective` (`mobility`, `strength`, `prevention`), `sessions` ([TrainerStrengthSession], o tipo de hoje), `start` (Day), `validity` (`untilRace(raceId)`, `weeks(n)`, `untilDate(Day)`), `end` (Day, calculado), `builder` (`trainer`, `claude`), `createdAt`, `endedNotifiedAt`.

- `TrainerStrengthGroup` ganha `mobility`. O gerador escolhe exercícios dos padrões `mobilityHip`, `mobilityAnkle` e `mobilityThoracic`, sem carga.
- Objetivo define o padrão das sessões novas: Mobilidade → foco mobilidade, intensidade leve; Força → foco escolhido, intensidade moderada; Prevenção → corpo todo leve com padrões de corredor (unilateral, panturrilha, quadril).

### Onde fica

- Um plano ativo por conta, num store próprio no diretório da conta, sincronizado como blob `preference` (id `strengthPlan`), no mesmo padrão dos stores da v1.28.0 (gravação atômica, carimbo de documento).
- O Treinador passa a ler as sessões de força do plano de força ativo, no lugar de `plan.strength` / `standaloneStrength`.
- Migração: na primeira abertura, as sessões que existirem hoje viram um plano com objetivo deduzido dos focos, início hoje e validade "até a data de fim do plano de corrida" quando houver plano de corrida; sem plano de corrida, 12 semanas. O app mostra uma vez o aviso "Seu treino de força virou um plano até DD/MM. Ajuste a validade se quiser." (decisão minha, ver abaixo).

### Fim do plano

- Dias depois de `end` não geram treino do plano.
- Notificação "Plano de <objetivo> terminou" com "Foram X de Y treinos. Toque para montar o próximo.", disparada quando o último treino do plano é concluído ou às 21h do último dia, o que vier primeiro. Uma vez por plano (`endedNotifiedAt`). Abre a tela de força do Treinador.
- Tela de força mostra o aviso de plano terminado com "Montar próximo plano" e "Repetir o mesmo plano" (mesmas sessões e duração, começando no próximo dia de treino).

### Claude

- Com "Quem monta: Claude", o pedido usa `start`/`end` do plano como período e os dias e focos do plano. Os treinos devolvidos são gravados por data e marcados com o `id` do plano; somem quando o plano termina ou é trocado.
- `replacesMFIT` não é oferecido nem aplicado para treinos do plano.

### MFIT

- Nada muda no MFIT. Dia que tem MFIT e plano mostra os dois cards, cada um com sua etiqueta ("MFIT" e "Plano").

### Telas (mock aprovado)

1. Novo plano de força: objetivo, dias (+ adicionar), validade (até a prova / semanas / até a data), início, resumo "Termina … · N treinos", quem monta.
2. Card do plano ativo: título, período, barra e "Semana N de M · X de Y treinos feitos", "Editar plano"; card do MFIT separado.
3. Dia com os dois treinos.
4. Notificação e aviso de fim com os dois botões.

## Regras do projeto

Mock aprovado antes do código e comparação com o mock ao fim de cada tela; cantos concêntricos 26/12; types e constantes em arquivos próprios; sem comentários; regra nova documentada em `docs/regras/prescricao.md`; README e landing atualizados.

## Decisões minhas para conferir

- Migração das sessões atuais para um plano com validade (fim do plano de corrida ou 12 semanas) e aviso único.
- Notificação às 21h do último dia se o último treino não for feito.
- "Repetir o mesmo plano" começa no próximo dia de treino.
- Objetivo define os padrões das sessões novas (pode ser alterado por sessão).
