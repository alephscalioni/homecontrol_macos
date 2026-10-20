---
version: 1
slug: "desktop-homecontrol-panel"
primary_target: "desktop/src/index.html"
related_targets: ["desktop/src/style.css", "desktop/src/renderer.js", "desktop/src/camera.html", "desktop/src/camera.js", "desktop/src/main.cjs"]
---

# Painel desktop para Windows e Linux

Mode: Operate. Extensão do mundo visual existente do HomeControl para Windows e Linux, com Fedora e Ubuntu como distribuições alvo. Sem widgets nesta versão. `DESIGN.md` e `sources-homecontrol-panelview-swift.md` continuam sendo a autoridade do aplicativo macOS; este registro descreve somente a tradução desktop em Electron.

## Direction contract

THESIS: Acessar rapidamente os mesmos controles domésticos em um painel compacto de bandeja, com estado e capacidades fornecidos pelo Home Assistant.

OWN-WORLD: Preservar texto marfim, acento oliva-taupe, controles arredondados e densidade compacta do HomeControl. O port usa fundo escuro opaco, superfícies tonais translúcidas sobre esse fundo e um gradiente discreto. Não implementa nem promete o desfoque nativo do macOS. Tipografia do sistema e ícones SVG substituem San Francisco e SF Symbols sem criar uma identidade nova.

STORY: Conectar o próprio servidor ou abrir demonstração identificada; escolher Ar-condicionado, Cômodos ou Favoritos; ler o estado recebido; executar apenas ações suportadas. Detalhes preservam retorno ao contexto de origem. Configurações, falhas de conexão e reconexão pertencem ao mesmo painel.

FIRST VIEWPORT: Janela inicial de 456 × 696 pixels lógicos, redimensionável, com mínimo de 400 × 560. Marca, configurações e fechar acima das três abas rotuladas. No clima, identificação e favorito à esquerda da energia circular, ilustração branca centralizada, temperatura proeminente com Eco na mesma linha, leitura atual, slider com ajustes laterais, quatro colunas compactas de opções e estado operacional. Rodapé persistente mostra conexão e versão. Conteúdo excedente rola; cabeçalho e rodapé permanecem disponíveis.

FORM: A composição climática existente governa o port. A temperatura usa 58 pixels, com dígitos tabulares; rótulos e controles compactos mantêm a leitura hierárquica. A grade tem quatro colunas e intervalo de 8 pixels; opções adicionais seguem em outra linha. A regra abaixo de 410 pixels reduz margens, temperatura e padding sem trocar a composição por um painel de cartões grandes. Campos e seletores usam os controles HTML; seleção de aba combina fundo elevado e peso de texto.

SIGNATURE: A ilustração decorativa do ar-condicionado continua sendo um recurso gerado, não uma foto do aparelho conectado. Três traços de ar animados acompanham a condição ligado/disponível; esta tradução não reproduz a modelagem nativa de velocidade e direção. Reduce Motion interrompe a animação. Eco só aparece quando a entidade informa suporte e alternativas de preset adequadas. Opções de clima, ações de aspirador e ajustes relacionados dependem das capacidades e dados do servidor.

FINISH: Documentação e evidência visual devem distinguir tradução de composição, simulação de protocolo e funcionamento em cada sistema operacional. Não alterar a documentação nem o material nativo macOS para atribuir a ele as decisões locais do port.

## Behavior

- Fechar o painel o oculta; a bandeja oferece abrir e sair. No Windows, abrir posiciona o painel junto à área útil da bandeja. A posição e a presença da bandeja dependem do ambiente desktop.
- `renderer.js` recebe snapshots do processo host: conexão, entidades, áreas, capacidades, favoritos, ocultação e comandos pendentes. A UI não deve substituir confirmação do Home Assistant por um estado visual inventado. Demonstração usa dados sintéticos e selo explícito.
- Controles indisponíveis, desconectados ou com comando pendente ficam desabilitados. Erros de comando usam mensagem visível; falha de registro tem aviso próprio, sem representar uma casa vazia como carregamento bem-sucedido.
- Re-renderizações preservam identificação de foco, posição de rolagem e edição dos campos. Botões, inputs, selects e summaries têm foco visível; rótulos acessíveis acompanham ações sem texto. O idioma é en-US ou pt-BR; nomes recebidos do servidor permanecem intactos.
- Cômodos apresenta busca, áreas e quantidade de aparelhos, depois controles de uso diário e informações recolhidas. Favoritos e ocultação são preferências locais por conta/servidor.
- Aspirador prioriza estado, bateria e ações suportadas, seguidos de sucção, seleção de cômodos do mapa quando disponível, ajustes e manutenção recolhidos. Cômodos do mapa do robô não se confundem com áreas do Home Assistant.
- Câmeras têm imagem de prévia e janela separada para transmissão. A janela usa imagem contida, barra compacta com pausa, fixar acima, tamanho, ampliar e fechar, além de mensagens de conexão e nova tentativa. Fechar ou trocar a conexão encerra os pedidos associados. O exemplo visual da câmera é uma imagem sintética servida por fixture.

## Acceptance

- Preservar as três abas, o reconhecimento visual do HomeControl e a composição climática com Eco inline e quatro colunas compactas.
- Manter leitura sem sobreposição na janela inicial e permitir rolagem em detalhes longos. No tamanho mínimo, continuar oferecendo navegação e controles acessíveis.
- Manter teclado utilizável após atualizações do host, com foco visível e sem substituir a posição de foco por outro controle.
- Exibir estados reais, limites e ações suportadas; identificar demonstração e apresentar falhas de conexão/comando.
- Entregar superfícies desktop para Windows, Fedora e Ubuntu, sem widgets. Validar cada ambiente separadamente antes de alegar funcionamento nele.
- Tratar a reprodução em Fedora 44 KDE com XWayland e composição por software como evidência desse ambiente específico. Não inferir dela execução nativa Wayland, execução Windows/Ubuntu ou conexão com uma casa real.

## Evidence checked

Inspeção documental e estática de `PRODUCT.md`, `DESIGN.md`, do brief macOS existente e dos cinco arquivos relacionados acima, mais inspeção de `desktop/src/index.html`. A documentação global permanece focada no macOS; este arquivo registra o escopo adicional sem reescrevê-la.

Capturas inspecionadas em `build/desktop-review/`:

- `fedora-climate.png`: painel de demonstração em 456 × 696; Eco ao lado de 24 °C; slider; quatro opções na mesma linha; estado e rodapé legíveis.
- `fedora-rooms.png`: busca, três áreas com contagens, divisores e Organizar; sem dados de uma casa real.
- `fedora-vacuum.png`: retorno, estado Na base, bateria, ações, sucção e ajustes recolhidos; conteúdo longo com rolagem visível.
- `fedora-camera.png`: janela da câmera fixture, imagem contida e barra de controles; a ilustração do ar-condicionado é o conteúdo sintético do teste.

As capturas documentam composição e estados de fixture; não comprovam comunicação com dispositivos físicos. A reprodução Fedora 44 KDE/XWayland e composição por software foi informada pelo teste do port; esta passagem documental não executou novamente o aplicativo. A revisão de acabamento informou resolução dos achados de foco e composição, com disposição de envio para esses achados; isso não amplia a evidência de plataformas.
