# HomeControl

App nativo da barra de menus do Mac para controlar uma casa integrada ao Home Assistant. Interface em português, com a composição da referência e glassmorfismo: desfoque nativo do macOS, vidro escuro translúcido e bordas suaves. A opção Reduzir Transparência do sistema é respeitada.

## Instalar

Baixe o ZIP da [última versão](https://github.com/alephscalioni/homecontrol_macos/releases/latest), extraia `HomeControl.app` e mova para a pasta Aplicativos. O pacote inicial atende Macs com Apple Silicon e macOS 14 ou superior.

Para compilar do código-fonte, dê dois cliques em `Abrir HomeControl.command` ou execute `./scripts/build-app.sh` e abra `build/HomeControl.app`.

O ícone de uma casa aparece na barra de menus. Na primeira abertura, configure sua conexão ou selecione **Explorar demonstração**. A demonstração usa dados de exemplo e não envia comandos à sua casa.

## Conectar sua casa

1. Informe o endereço do seu Home Assistant, por exemplo `http://homeassistant.local:8123` ou seu endereço HTTPS.
2. No Home Assistant, abra seu **Perfil → Segurança → Tokens de acesso de longa duração** e crie um token para o HomeControl.
3. Cole o token no campo protegido do aplicativo e clique em **Conectar ao Home Assistant**.

O token é salvo no Chaves do macOS depois que a conexão funciona. As preferências guardam o endereço, os IDs dos favoritos e as escolhas locais de organização. Use **Esquecer conexão** para remover o token salvo desta instância. Endereços HTTP locais e HTTPS são aceitos; certificados inválidos não são ignorados. O app não publica seu Home Assistant na internet.

Os dispositivos e seus estados vêm do servidor. O app acompanha mudanças em tempo real e tenta reconectar quando a conexão cai ou o Mac desperta. Durante uma interrupção, os dados ficam identificados como desatualizados e os comandos são desativados. Um comando aceito pelo servidor não significa que o aparelho já confirmou o novo estado.

## Controles

O painel tem três abas e um único ícone de largura fixa na barra de menus:

- **Ar-condicionado:** seletor por cômodo, temperatura individual ou faixa, modo, velocidade, perfis, Eco e direção do ar, conforme as capacidades. Ao arrastar a temperatura, o número acompanha a escolha; o ajuste é enviado ao soltar. O fluxo de ar é animado e respeita Reduzir Movimento.
- **Cômodos:** controles e leituras do ambiente aparecem primeiro. Consumo, horários, manutenção, configurações, diagnóstico e outras leituras ficam em seções recolhidas. A busca encontra itens de todos os grupos. **Toda a casa** reúne os itens; **Geral da casa** distingue cenas e serviços globais; **Sem cômodo** mostra localizações ainda não atribuídas.
- **Favoritos:** reúne os itens marcados com estrela, incluindo leituras técnicas escolhidas explicitamente.

Dentro dos cômodos é possível ligar interruptores e tomadas, abrir detalhes de luzes (brilho e temperatura de branco), cortinas e ventiladores, e ativar cenas. O botão de voltar retorna ao cômodo ou aos favoritos de origem.

**Organizar** revela o menu de cada item para mudar sua classificação ou ocultá-lo no app. Itens ocultos podem ser restaurados nessa mesma tela. Essas escolhas ficam neste Mac, separadas por servidor e pelos IDs estáveis das entidades. Itens ocultos/desativados no HA são respeitados; a organização local não os reativa. A classificação usa metadados do registro e classes/unidades dos sensores, com regras específicas para temporizadores e manutenção; itens desconhecidos vão para Outras leituras.

Consumo separa energia acumulada de potência instantânea e conserva unidade e período (por exemplo, ontem e este mês). O app não soma contadores de períodos ou aparelhos diferentes.

Luzes RGB têm controle de energia e brilho; escolha de cor RGB, câmeras, multimídia, fechaduras e alarmes não estão implementados. As áreas dependem da permissão de leitura dos registros do Home Assistant; se indisponíveis, a aba Ar-condicionado e os favoritos continuam acessíveis pelo nome. Não é necessário instalar uma integração no servidor.

## Desenvolvimento

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

## Atualizações do aplicativo

As versões distribuídas usam o feed assinado do GitHub Releases. O usuário pode autorizar a busca e instalação automáticas; o menu também oferece **Verificar atualizações…**. A chave privada de publicação permanece no Chaves do mantenedor. Para publicar uma versão ou configurar um fork, consulte [UPDATES.md](UPDATES.md).

## Privacidade do repositório

O código não inclui os dados de uma instalação real. Credenciais e preferências ficam fora do projeto, no armazenamento local do macOS. Inventários, capturas, builds e configurações locais devem permanecer fora das publicações; consulte [SECURITY.md](SECURITY.md).

## Referências

- [WebSocket API do Home Assistant](https://developers.home-assistant.io/docs/api/websocket/)
- [Capacidades de climatização](https://developers.home-assistant.io/docs/core/entity/climate/)
- [Tokens e autenticação](https://developers.home-assistant.io/docs/auth_api/)

A imagem do ar-condicionado foi criada com a ferramenta integrada de geração de imagens. O prompt e a origem estão em `assets/air-conditioner.prompt.txt` e nos metadados do PNG. O ícone usa SF Symbols e pode ser recriado com `scripts/make-icon.swift`.
