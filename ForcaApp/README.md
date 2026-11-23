# trAIning Força (Connect IQ)

App de relógio que substitui a atividade de força nativa do Garmin. Roda o treino de força do dia, do MFIT ou do treinador, série a série, e manda cada série ao iPhone na hora. Funciona no Forerunner 965 e no Venu 3/3S.

## O que faz

- Grava a atividade como treino de força (`ActivityRecording`, `SPORT_TRAINING` + `SUB_SPORT_STRENGTH_TRAINING`), com FC, efeito do treino e carga no Garmin Connect. A atividade leva o nome do treino.
- Mostra a série, o descanso com vibração aos 10 s e no zero, o ajuste da série que acabou, a fila com "Pular · fazer depois" e "Fazer agora", e a pausa com Retomar / Salvar / Descartar. Botões e regras em [`docs/regras/prescricao.md`](../docs/regras/prescricao.md#força-ao-vivo).
- Guarda o treino de hoje e o de amanhã, que o iPhone manda depois de cada sync. Sem o iPhone por perto, o treino roda inteiro.
- Manda ao iPhone o início, cada ação (série feita, ajuste, pular, fazer agora, deixar de fora), a fase, a FC e o fim, pelo Connect IQ Mobile SDK. Repete a cada 5 s até o iPhone confirmar.

O Connect IQ não grava as séries no `.FIT`. Depois de salvar, o iPhone envia as séries para a atividade no Garmin Connect.

## Aparelhos e botões

| Ação | Forerunner 965 | Venu 3 |
| --- | --- | --- |
| Começar, pausar, confirmar o ajuste | START | botão de cima |
| Concluir a série, pular o descanso, cancelar o ajuste | BACK/LAP | botão de baixo |
| Trocar a visão; no descanso, abrir o ajuste | UP/DOWN | deslizar para cima ou para baixo |
| Menu de ações | segurar UP | segurar o botão de baixo |

O `monkey.jungle` separa o código por anotação: `:buttons` só no 965 e `:touch` só no Venu.

## Build e testes

Pré-requisitos: Java 17, Connect IQ SDK com `fr965`, `venu3` e `venu3s`, e a mesma chave de desenvolvedor do mostrador (`DEVELOPER_KEY`, padrão `../Watchface/developer_key.der`).

```bash
./build-local.sh                 # gera bin/TrainingForca-<aparelho>.prg (release) para os três aparelhos
DEBUG=1 ./build-local.sh         # build de debug, que abre com um treino de exemplo sem plano do iPhone
DEVICES=fr965 ./build-local.sh   # só um aparelho
./test-local.sh                  # testes (:test) no simulador, que precisa estar aberto
DEVICE=venu3 ./test-local.sh
```

Para instalar, copie o `.prg` do aparelho para `GARMIN/APPS` no relógio. O `.prg` de release mostra a tela vazia enquanto o iPhone não manda o treino do dia; o de debug (`DEBUG=1`) abre com um treino de exemplo, que o iPhone não associa a nenhum plano.

## iPhone

No iPhone, abra `training://relogio` uma vez para escolher o relógio no Garmin Connect. O app precisa do Garmin Connect instalado e do Bluetooth em segundo plano. O código do iPhone fica em `App/Strength/WatchLink/` (canal e envio do treino) e `App/Strength/Live/` (sessão, tela ao vivo, resumo e envio das séries), e o Live Activity em `Widgets/StrengthLive*.swift`.
