# HomeControl para Windows e Linux

Port do painel do HomeControl para a bandeja do sistema, sem widgets. O app macOS continua em SwiftUI na raiz do projeto.

- Ar-condicionado: temperatura única ou faixa, modo, ventilação, direção do ar e predefinições disponíveis.
- Cômodos, favoritos e ocultação local de aparelhos.
- Luzes e brilho, tomadas, ventiladores, cortinas, cenas e leituras de sensores.
- Aspirador: ações suportadas, sucção, seleção de cômodos em mapas Xiaomi compatíveis e ajustes organizados por limpeza, base, navegação, horários, manutenção, atividade e avançado.
- Câmeras: imagem, transmissão MJPEG em janela flutuante, pausa, tamanhos, ampliar e sempre por cima.
- Português e inglês, conforme o idioma do sistema. Nomes dos aparelhos permanecem como cadastrados no Home Assistant.

## Instalar

[Baixe os instaladores de Windows e Linux](https://github.com/alephscalioni/homecontrol_macos/releases/tag/desktop-v0.5.0). Use o pacote correspondente: `.rpm` no Fedora, `.deb` no Ubuntu ou `Setup.exe` no Windows. O AppImage é uma alternativa no Linux e pode exigir FUSE. A arquitetura destes pacotes é x86_64.

Abra HomeControl no menu de aplicativos. Informe o endereço HTTP/HTTPS do Home Assistant e um token de acesso de longa duração criado em **Perfil → Segurança**. **Explorar demonstração** usa apenas aparelhos simulados.

Na primeira execução, o painel de configuração abre automaticamente. Depois, o app fica na bandeja; clique no ícone para abrir o painel compacto e clique novamente ou fora dele para fechar, como no LedLinux. O lançador Linux usa XWayland para ancorar o painel junto ao ícone, como no LedLinux. Use o menu da bandeja para sair. No Ubuntu/GNOME, a visibilidade da bandeja depende do suporte a AppIndicator do desktop.

A conexão é salva usando a proteção de credenciais do sistema (DPAPI no Windows, KWallet/Secret Service no Linux). O app mantém a escolha do cofre nas próximas aberturas. Se o cofre de uma conexão já salva estiver bloqueado, desbloqueie-o e use **Reconectar**. Uma nova conexão feita sem um cofre disponível permanece apenas na memória. **Esquecer conexão** remove a credencial salva deste computador. Preferências de favoritos e itens ocultos são separadas por conexão.

As câmeras precisam oferecer imagens e MJPEG pelo Home Assistant. Streams que exigem WebRTC/HLS não são convertidos por este port. Áudio e gravação não têm controles. Somente o processo principal acessa o token; a interface recebe imagens por um protocolo local, sem credenciais na URL.

No Linux, o lançador passa `--ozone-platform=x11` antes de iniciar Electron para permitir ancoragem pelo XWayland em sessões KDE/GNOME Wayland e X11. A composição por software evita o conflito de Vulkan/Mesa reproduzido no Fedora KDE. Não altera a configuração global do desktop. Os instaladores Windows desta primeira versão não têm assinatura Authenticode. **Downloads e versões** abre a página de releases; atualização automática ainda não está implementada neste port.

## Desenvolvimento

Requer Node.js 22 ou superior e npm.

```bash
npm ci
npm start
npm test
npm run smoke:protocol
npm run dist:linux
npm run dist:win
```

O build Linux gera AppImage, DEB e RPM; para gerar RPM é necessário ter `rpmbuild` disponível. O build Windows gera um instalador NSIS. `smoke:protocol` testa a aplicação Electron contra um servidor local simulado, incluindo câmera e comandos; não acessa uma casa real e usa um perfil temporário.

`HOMECONTROL_SMOKE_DIR` permite escolher a pasta de capturas do teste. Os testes não desabilitam o sandbox do app. `--ozone-platform=x11` e `--ozone-platform=wayland` permitem selecionar o backend explicitamente.

## Evidência

Os testes de protocolo cobrem autenticação, ordem das mensagens, eventos concorrentes com o snapshot inicial, timeout, remoção de entidades, limites de comandos e proteção de credenciais. A execução gráfica no Fedora 44 KDE foi verificada com dados e comandos sintéticos. Isso não demonstra a execução física de comandos em aparelhos reais. Builds e testes em outros sistemas são registrados separadamente em `VALIDATION.md`.
