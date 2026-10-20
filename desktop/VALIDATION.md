# Validação do port — 2026-10-20

| Ambiente | Resultado |
| --- | --- |
| Fedora 44 KDE, x86_64 | 27 testes de modelo/protocolo, credenciais e posicionamento. Conexão real de leitura ao HA confirmada: entidades auxiliares dos aspiradores agrupadas sem duplicação na lista principal. Identificadores e inventários permanecem fora deste registro público. |
| RPM Fedora instalado | Revisão 7 validada com conexão autenticada e salva após reinícios com e sem as variáveis da sessão KDE. Painel visível/focado junto à barra superior, inclusive por ativação SNI. Clique físico não foi observado nesta rodada. Revisão `0.5.0-8.fc44` instalada via DNF e reaberta pelo desktop entry, sem depurador, com reconexão ao HA; contém os mesmos controles, contato público de autoria e link de downloads atualizado. |
| Ubuntu 24.04, contêiner Podman no Fedora | Validação anterior: DEB instalado e reinstalado; app executado como usuário sem privilégios em Xvfb/D-Bus; painel, três abas, bandeja criada, favoritos e ajustes pelo teclado aprovados. Sem `--no-sandbox`. As correções de 20/10 foram verificadas em testes e no Fedora; persistência real no GNOME ainda não foi testada. |
| Windows x86_64 | Instalador NSIS gerado. Fontes do runtime dentro do `app.asar` conferidas contra as fontes finais. Execução no Windows ainda não testada. |
| macOS, Electron de desenvolvimento | Primeiro teste de abertura/bandeja aprovado; testes de protocolo/modelo aprovados. O app SwiftUI permanece separado. |

As verificações gráficas anteriores usam dados sintéticos. A câmera do teste transmite a ilustração do ar-condicionado por um servidor MJPEG local. A rodada de 20/10 confirmou autenticação, leitura dos aparelhos reais e restauração da conexão; nenhum comando foi enviado aos aparelhos reais.

O erro da chave foi reproduzido na revisão anterior: sem as variáveis de ambiente KDE, o Electron selecionava `basic_text` e ignorava a credencial criptografada. A revisão 7 guarda o identificador do cofre junto ao ciphertext e seleciona esse mesmo cofre antes de inicializar o `safeStorage`. O arquivo anterior foi migrado automaticamente; a reabertura sem o ambiente KDE manteve `kwallet6`, `connected=true` e `saved=true`. Falhas temporárias do cofre preservam o arquivo e oferecem reconexão. A exclusão da conexão é serializada com migrações/gravações para impedir que uma operação pendente recrie a chave.

O centro da tela vinha do uso de `Tray.getBounds()` no Linux, onde o SNI não fornece esses limites. A revisão 7 usa as informações da ativação ou o cursor, limita a janela à área útil e mantém a abertura junto à borda da barra; abertura pelo atalho tem posição padrão no topo.

A revisão independente encontrou perda de foco durante atualizações e Eco/opções fora da composição aprovada. Ambos foram corrigidos e a revisão dos dois itens terminou com `ship`: foco estável confirmado por eventos reais de teclado no Electron; Eco inline e quatro colunas de opções visíveis no painel.

O teste Ubuntu encontrou uma biblioteca de compatibilidade OSS escolhida para `libasound2`. O pacote prioriza `libasound2t64 | libasound2`, e o teste final foi repetido com o DEB corrigido e ALSA real.

Os 12 arquivos de runtime dentro dos `app.asar` Linux e Windows foram comparados byte a byte às fontes finais, incluindo as novas rotinas de credenciais e posicionamento. `npm audit --omit=dev` não relatou vulnerabilidades nas dependências de produção na validação anterior.

Capturas e resultados de depuração ficam no diretório local ignorado `../build/desktop-review/`; não são incluídos na publicação. Instaladores e checksums públicos: [HomeControl Desktop 0.5.0](https://github.com/alephscalioni/homecontrol_macos/releases/tag/desktop-v0.5.0). Atualização automática não está implementada neste port.
