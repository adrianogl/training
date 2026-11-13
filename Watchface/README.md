# Mostrador trAIning (Forerunner 965)

Mostrador Connect IQ com o layout Prontidão: anel de segundos, data, temperatura e umidade, bateria, hora com segundos, VO2max, km da semana com barra de progresso, próxima prova com meta e previsão, e horário da próxima reunião.

## De onde vem cada dado

| Dado | Fonte no relógio |
| --- | --- |
| Temperatura e umidade | `Weather.getCurrentConditions()` |
| Bateria | `System.getSystemStats().battery` |
| VO2max, km da semana, próxima reunião, previsão de prova | complications do sistema (`Toybox.Complications`) |
| Meta semanal, nome, data, distância e meta da prova | configurações do mostrador no app Connect IQ do celular |
| Prontidão | servidor de sync do app trAIning, buscado em background a cada 15 min e guardado em `Application.Storage` |

A prontidão ocupa o terceiro número, com o selo AI. A previsão é a do relógio (race predictor da Garmin), por isso aparece sem o selo AI.

A complication de calendário devolve só o horário do próximo evento, sem o nome.

## Prontidão do app

1. No app trAIning do iPhone, gerar o token em Ajustes › Sincronização › Relógio.
2. No Garmin Connect do celular, abrir o mostrador e colar o token em Configurações › Token do relógio.

O mostrador busca a nota em `GET /api/v1/watch/readiness` a cada 15 minutos, em background, pelo celular (Bluetooth) ou Wi-Fi. A nota só aparece se for do dia de hoje no relógio; depois da meia-noite volta "--" até chegar a nova. Sem token, com token revogado (401) ou sem nota no servidor (404), aparece "--". Sem rede, fica a última nota recebida, se for de hoje.

## Build

Pré-requisitos: Java, Connect IQ SDK (via SDK Manager) com o device `fr965` baixado e uma chave de desenvolvedor.

```bash
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt

monkeyc -f monkey.jungle -d fr965 -o bin/TrainingFace.prg -y developer_key.der
connectiq
monkeydo bin/TrainingFace.prg fr965
```

Para instalar no relógio, copiar `bin/TrainingFace.prg` para `GARMIN/APPS` com o relógio ligado no Mac por USB.

No simulador, conferir o modo sempre ligado em Settings → Display Mode e o mapa de burn-in em View → Burn-in.

### Token sem a loja

Instalado pelo cabo, o mostrador não aparece nas configurações do Garmin Connect, então não há onde colar o token. Nesse caso, salve o token em `~/.config/training-sync/watch-token` e compile com `./build-local.sh`: ele copia o mostrador para uma pasta temporária, embute o token em `BuildToken.mc` e gera `bin/TrainingFace.prg`. No repositório, `BuildToken.WATCH_TOKEN` fica sempre vazio. Se a configuração do Garmin Connect tiver um token, ela tem prioridade.
