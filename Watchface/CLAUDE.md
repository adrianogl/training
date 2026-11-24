# Mostrador (Connect IQ)

Mostrador em Monkey C para o Forerunner 965 (`fr965`). Compilação, fonte de cada dado e troca da foto estão em `Watchface/README.md`.

## Build

O `monkeyc` precisa do Java 17 do Homebrew, que não está no PATH:

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH=/opt/homebrew/opt/openjdk@17/bin:$PATH
Watchface/build-local.sh
```

- `build-local.sh` copia o projeto para uma pasta temporária, embute o token de `~/.config/training-sync/watch-token` em `BuildToken.mc`, troca o fundo pela foto de `~/.config/training-sync/watch-background.png` e gera `bin/TrainingFace.prg`.
- A chave `developer_key.der` fica só no checkout principal (ignorada pelo git). Num worktree, copie a chave antes ou compile no checkout principal.
- O simulador abre pelo binário `ConnectIQ.app/Contents/MacOS/simulator` do SDK. Confira o modo sempre ligado em Settings → Display Mode.

## Instalar no relógio

O 965 conecta por MTP e não aparece em `/Volumes`. `mtp-sendfile` e `mtp-connect --sendfile` falham com "Error sending file". Não insista pela linha de comando: peça para arrastar `Watchface/bin/TrainingFace.prg` para `GARMIN/Apps` pelo OpenMTP.

Se a nota sumir do relógio depois de trocar o token no app, salve o token novo em `~/.config/training-sync/watch-token`, rode `build-local.sh` de novo e reinstale. Para conferir o servidor: `GET https://training.aglv.dev/api/v1/watch/readiness` com o token como Bearer.

## Regras

- No git, `BuildToken.WATCH_TOKEN` fica sempre vazio e `resources/drawables/background.png` fica preto. A foto real tem pessoas da família e o repositório é público.
- Modo sempre ligado: até 10% de pixels acesos no AMOLED. Por isso a hora usa fonte bitmap de peso 700 nesse modo e não mostra a foto.
- Hora na tela ativa: PNG com alpha por caractere em `resources/drawables/clock`. Fonte bitmap customizada sai sem antialias e a borda fica serrilhada.
- Mudança visual começa num mock aprovado.
