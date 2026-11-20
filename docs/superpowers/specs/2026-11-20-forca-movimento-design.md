# Força: movimento, observações e carga sugerida

Data: 20/11/2026 · Mock: https://claude.ai/artifact/HSTSgs9X4biNo3CUxhKEHh

## Por quê

Na prescrição de força, o atleta vê o nome do exercício e a carga, mas não vê como ele é executado. Exercício novo do catálogo da Garmin (1.358 exercícios, nomes traduzidos) chega sem referência visual e, se tem peso, sem carga. Recomendação do treinador sobre a execução fica fora do app. Gráficos no iPhone ficam apertados porque o app não gira.

## Objetivos

1. Mostrar o movimento de cada exercício com imagem, em qualquer origem (Treinador, treinos do Claude, MFIT).
2. Deixar o atleta dizer se a imagem corresponde à execução, oferecer alternativas e guardar cada avaliação sem perder nada.
3. Guardar observações permanentes por exercício.
4. Sugerir a primeira carga de exercício com peso que nunca foi feito, a partir do histórico.
5. Permitir o iPhone na horizontal.

## Fora do escopo

- Fontes pagas de animação (ExerciseDB, WorkoutX e parecidos) e link para vídeo no YouTube: descartados pelo usuário.
- Vídeo do app do MFIT: a API usada não traz mídia.
- Prazo de validade em observação: a nota é permanente até ser apagada.
- Diferenciar observação do atleta e do treinador.

## O que não pode acontecer

- Avaliação ou observação perdida porque o aparelho estava sem internet ou a sincronização falhou.
- Mostrar movimento errado por causa de um casamento automático não revisado.
- Toque de um atleta (ex.: a Thaís) mudar a imagem de um exercício para outro atleta antes da revisão.
- Carga sugerida acima do que o histórico sustenta.

## Abordagens consideradas

| Abordagem | Trade-off | Decisão |
| --- | --- | --- |
| Só free-exercise-db + link de vídeo | Grátis, mas sai do app | Link de vídeo recusado ("Não gostei do quatro") |
| GIFs pagos (ExerciseDB, clones) | Animação contínua, mas assinatura e termos proíbem guardar a mídia | Recusado ("remover os que são pagos") |
| Só desenho próprio | Visual único, mas mostra o padrão e não a variação | Fica como última camada |
| **Cascata free-exercise-db → equivalente → wger → desenho, com carrossel** | Exercício exato quando há foto; mistura estilos | **Escolhida pelo usuário** |

## Imagens do movimento

### Fontes

| Camada | Fonte | Licença | Conteúdo |
| --- | --- | --- | --- |
| 1 | free-exercise-db (github.com/yuhonas/free-exercise-db) | Unlicense | 873 exercícios com 2 fotos (início e fim), passo a passo em inglês |
| 2 | Equivalente na free-exercise-db | Unlicense | Exercício do mesmo padrão e equipamento quando não há o próprio |
| 3 | wger (wger.de) | CC-BY-SA 3.0/4.0, por imagem | 288 de 979 exercícios com imagem, 5 GIFs; crédito do autor obrigatório |
| 4 | Desenho próprio | nosso | Um por padrão de movimento do catálogo |

Medição automática por nome sobre os 1.358 exercícios: 157 com foto própria na free-exercise-db, 55 só na wger, 1.146 sem nenhuma. A camada 2 deve reduzir bastante o último grupo.

### Ordem e carrossel

- Cada exercício tem uma lista ordenada de imagens: fotos próprias da free-exercise-db, equivalentes da free-exercise-db, imagens da wger e, por último, o desenho do padrão. O desenho está sempre presente.
- A tela do exercício mostra um carrossel com essa lista. Arrastar para o lado troca a imagem; pontos e "2 de 4" mostram a posição; a origem e o crédito aparecem embaixo.
- As duas fotos da free-exercise-db alternam como animação. GIF da wger toca em loop.
- A lista do treino mostra miniatura da primeira imagem.

### Correspondência revisada

- Um script local (`scripts/`) gera candidatos por nome, padrão e equipamento a partir das duas bases. Eu reviso; só a correspondência revisada entra no app. Na dúvida, fica de fora.
- O resultado é um arquivo versionado no repositório que liga `id` do catálogo (ex.: `SQUAT/GOBLET_SQUAT`) às imagens, em ordem, com origem, licença e autor.
- Exercícios do MFIT chegam só com nome; são ligados ao catálogo pelo nome e, sem casamento, ficam só com o desenho do grupo muscular mais próximo do padrão.

### Armazenamento das imagens

- Imagens dentro do app, para funcionar sem internet. As da free-exercise-db são domínio público e podem ir no repositório.
- As da wger vão no repositório com o arquivo de créditos (autor, licença, link) exigido pela CC-BY-SA, e o crédito aparece embaixo da imagem.
- Redimensionar e comprimir para manter o tamanho do app razoável. Antes de embutir, medir o tamanho total e trazer o número para aprovação se passar de 40 MB.

### Desenho próprio

- Um desenho animado por valor de `padrao` do catálogo (16 hoje: `antiExtension`, `horizontalPush`, `singleLeg`, `hinge`, `horizontalPull`, `verticalPull`, `squat`, `plyo`, `antiRotation`, `verticalPush`, `lateralCore`, `hipStability`, `mobilityHip`, `mobilityThoracic`, `calf`, `mobilityAnkle`).
- Boneco de perfil, desenhado em SwiftUI nas cores do app, uma repetição em cerca de 2,6 s, sem bounce. Com Reduzir Movimento ligado, fica parado na posição de maior amplitude.
- Passo a passo em português escrito por nós por padrão.

### Passo a passo

O passo a passo em inglês da free-exercise-db é traduzido para português na geração do arquivo de correspondência e revisado. Exercício sem passo a passo usa o do padrão.

## Avaliação da imagem

### Fluxo

- Embaixo da imagem do carrossel: "A imagem mostra a execução certa?" com "Corresponde" e "Não corresponde". A avaliação vale para a imagem na tela.
- "Corresponde": faixa "Confirmada por você em DD/MM", com desfazer.
- "Não corresponde": mostra até 3 alternativas da free-exercise-db do mesmo padrão, por semelhança de nome e equipamento. Botão "Buscar na wger" troca as três por alternativas da wger. Botão "Usar o desenho" vai para o desenho com campo de texto para dizer o que está diferente.
- A alternativa escolhida passa a ser a primeira imagem daquele exercício na hora, só no aparelho de quem escolheu. Para os outros atletas, só depois da revisão e de uma nova versão do arquivo de correspondência.

### O que é guardado

Cada avaliação é um registro: exercício (`id` do catálogo ou nome do MFIT), imagem avaliada (origem e identificador), resultado (corresponde / não corresponde), alternativa escolhida ou "nenhuma", texto opcional, data, atleta, treino em que estava, status (`pendente` / `resolvida`), e, quando resolvida, o que mudou e em que versão.

### Como é guardado

- Gravado no banco local no toque, antes de qualquer envio.
- Enviado na sincronização como um novo `kind` de registro do servidor (`server/src/constants.ts` `RECORD_KINDS`), com o mesmo protocolo de `POST /api/v1/changes`. Falha de envio fica na fila e tenta de novo na próxima sincronização.
- Nunca apagado. Resolver muda o status.
- O servidor MCP do trAIning ganha ferramentas, restritas ao admin (`ADMIN_EMAILS`), para listar as avaliações de imagem pendentes de todas as contas e marcar como resolvidas com a nota do que mudou. Avaliação de imagem não carrega dado pessoal além do exercício e do texto sobre a imagem. Observações do exercício continuam privadas de cada conta e não aparecem nessas ferramentas. Uso: numa sessão, eu leio, corrijo o arquivo de correspondência ou o desenho no repositório e marco.

## Observações do exercício

- Bloco "Observações" na tela do exercício, com "+ Adicionar". Cada nota mostra o texto e a data. Editar e apagar.
- A nota pertence ao exercício e ao atleta, não ao treino. Aparece sempre que o exercício aparecer, em qualquer origem, sem prazo.
- Sem distinção entre nota do atleta e do treinador.
- A `obs` das séries do MFIT (`MFITSerieDTO.obs`, hoje ignorada na tela) aparece no mesmo bloco, só leitura, identificada como "MFIT".
- Guardada como a avaliação: banco local no toque, novo `kind` na sincronização, nunca perdida.
- As notas entram no contexto dos treinos de força do Claude (`contexto_forca` do MCP e o pacote de contexto do app), para que o Claude respeite a recomendação.

## Carga sugerida

Vale para os treinos que o app prescreve (Treinador e treinos do Claude), só para exercício com equipamento de carga (`StrengthGeneratorConstants.loadedEquipment`) sem nenhuma carga registrada para aquele `id`. Treino do MFIT continua com a carga que o professor prescreveu. Hoje o gerador usa `StrengthProgression.next(context.loads[id])` e retorna `nil` nesse caso.

1. Procurar no histórico de cargas (MFIT e relógio) exercícios do mesmo `padrao`, preferindo o mesmo equipamento e o registro mais recente.
2. Converter: bilateral → unilateral, metade; barra → halter, dividir entre as mãos; outras conversões ficam na tabela de constantes, com valor conservador.
3. Tirar 20% por ser a primeira vez e arredondar para baixo no incremento do equipamento.
4. Sem base no padrão: não mostrar número, só "Primeira vez: comece leve e registre a carga".

Tela: carga com a etiqueta "sugerida" na lista e no exercício, e a base do cálculo escrita ("Base: Levantamento terra romeno, 40 kg em 14/11"). Quando a primeira carga é registrada, a etiqueta some e a progressão normal assume. A carga sugerida vai para o relógio como as outras.

## iPhone na horizontal

- Hoje `project.yml` limita o iPhone a `UIInterfaceOrientationPortrait`. Passa a aceitar retrato e as duas horizontais (sem retrato invertido, como o padrão do iOS no iPhone).
- O app inteiro gira. Gráficos ganham largura sem mudança própria.
- Cada aba é capturada na horizontal no iPhone 16 Pro Max; o que quebrar (altura fixa, sheet, barra de abas, carrossel) é corrigido. As capturas vão para aprovação antes do merge, conforme o fluxo de layout do projeto.

## Regras do projeto que valem aqui

- Mock aprovado antes do código; ao terminar cada tela, comparar com o mock.
- Cantos concêntricos: card 26, interno 12.
- Types e constantes em arquivos próprios; sem comentários no código.
- Regra nova de prescrição (carga sugerida) documentada em `docs/regras/prescricao.md` no mesmo commit.
- README e landing atualizados quando a mudança for visível.

## Decisões minhas para conferir

- Imagens embutidas no app, não baixadas em runtime.
- Correspondência revisada por mim antes de entrar; casamento automático nunca vai direto para o app.
- Alternativa escolhida vale na hora só para quem escolheu.
- Desconto de 20% e arredondamento para baixo na carga sugerida.
- Horizontal no app inteiro, não só nas telas de gráfico.
- Exercício do MFIT sem casamento no catálogo usa o desenho do padrão mais próximo.
- Carga sugerida só nos treinos do Treinador e do Claude; o MFIT mantém a carga do professor.

## Para quem for construir decidir

- Formato exato do arquivo de correspondência e do novo `kind` no servidor.
- Nome e parâmetros das ferramentas novas do MCP.
- Tamanho e compressão das imagens, dentro do limite acima.
- Desenho de cada um dos 16 padrões, seguindo o rascunho do mock.
