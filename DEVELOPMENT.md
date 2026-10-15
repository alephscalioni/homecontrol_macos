# Desenvolvimento do HomeControl

Instruções para compilar, testar e trabalhar com o código-fonte. Para assinatura e publicação de versões, consulte [UPDATES.md](UPDATES.md). Para os cuidados com arquivos locais, consulte [SECURITY.md](SECURITY.md).

## Compilar

Requer macOS 14+ e Xcode/Swift 6 ou superior. O pacote usa Sparkle para as atualizações do aplicativo; o Swift Package Manager resolve a versão fixada em Package.resolved.

```sh
swift build
swift run HomeControl --demo --window
./scripts/build-app.sh
open build/HomeControl.app
```

`--demo` usa exclusivamente os exemplos locais; `--window` abre uma janela para inspeção. Sem essas opções, o app funciona pela barra de menus. O script empacota os recursos. Sem identidade de assinatura configurada, usa assinatura ad hoc local; a assinatura Developer ID e a notarização dependem da configuração de distribuição. Consulte as notas da release para os requisitos e o estado do pacote publicado.

## Verificação

```sh
swift test                    # modelo e capacidades; testes de conexão pulados sem fixture
./scripts/test-integration.sh # inicia um servidor WebSocket local e executa todos os testes
```

Os testes de conexão validam autenticação, assinatura de eventos, reconciliação com o snapshot, remoções, alvo do comando, recusa do serviço, timeout, cancelamento e queda de conexão. O servidor simulado escuta somente em `127.0.0.1`. Não use um endereço real em `HA_TEST_SERVER`.

## Organização e sincronização

O app usa as áreas do Home Assistant. Uma área explícita da entidade prevalece; caso contrário, ela herda o cômodo do dispositivo. Isso permite que cada canal de um interruptor compartilhado fique no ambiente correto.

Mudanças nas áreas, dispositivos e entidades são acompanhadas por eventos. A cada minuto, o app também confere novamente os registros. Os nomes e vínculos atualizam sem reiniciar. Se a leitura falhar, o app avisa e conserva a última organização recebida; a falha não é apresentada como uma casa vazia.

A CLI usa a conexão salva no app e lê o token diretamente do Chaves, sem argumento ou variável de ambiente com credenciais:

```sh
swift run HomeControlCLI inventory .homeassistant/inventario.json
swift run HomeControlCLI apply .homeassistant/plano.json
```

O inventário é somente leitura. A aplicação de um plano exige administrador, verifica os vínculos anteriores, guarda arquivos privados antes/depois e um plano de reversão, altera somente `area_id` e relê os registros para conferir. O plano de reversão pode ser passado ao mesmo comando `apply`; as precondições impedem sobrescrever uma organização que tenha mudado desde então. Não há renomeação de IDs nem envio de serviços para acionar aparelhos. Arquivos locais da casa ficam em `.homeassistant/`, ignorada pelo projeto.

O repositório não inclui conexão, inventário, capturas ou backups de uma casa real. Os exemplos são sintéticos; os testes de protocolo e acionamento usam o servidor simulado e a demonstração.


## Referências

- [WebSocket API do Home Assistant](https://developers.home-assistant.io/docs/api/websocket/)
- [Capacidades de climatização](https://developers.home-assistant.io/docs/core/entity/climate/)
- [Tokens e autenticação](https://developers.home-assistant.io/docs/auth_api/)

A imagem do ar-condicionado foi criada com a ferramenta integrada de geração de imagens. O prompt e a origem estão em `assets/air-conditioner.prompt.txt` e nos metadados do PNG. O ícone usa SF Symbols e pode ser recriado com `scripts/make-icon.swift`.
