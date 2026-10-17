---
name: HomeControl
description: Controle doméstico em um painel nativo de vidro fumê na barra de menus do macOS.
colors:
  background: "rgba(4.7%, 5.1%, 4.7%, 1)"
  surface: "rgba(100%, 100%, 100%, 0.065)"
  raised: "rgba(100%, 100%, 100%, 0.11)"
  accent: "rgba(70%, 68%, 58%, 1)"
  text: "rgba(91%, 91%, 87%, 1)"
  secondary: "rgba(78%, 79%, 74%, 1)"
  line: "rgba(100%, 100%, 100%, 0.12)"
  good: "rgba(65%, 76%, 56%, 1)"
  warning: "rgba(94%, 72%, 49%, 1)"
  glass-tint: "rgba(0%, 0%, 0%, 0.62)"
  glass-edge: "rgba(100%, 100%, 100%, 0.10)"
  panel-edge-start: "rgba(100%, 100%, 100%, 0.24)"
  panel-edge-middle: "rgba(100%, 100%, 100%, 0.07)"
  panel-edge-end: "rgba(100%, 100%, 100%, 0.14)"
typography:
  temperature:
    fontFamily: "macOS system rounded"
    fontSize: "58pt"
    fontWeight: "medium"
    letterSpacing: "-2pt"
  temperature-range:
    fontFamily: "macOS system rounded"
    fontSize: "43pt"
    fontWeight: "medium"
    letterSpacing: "-2pt"
  temperature-unit:
    fontFamily: "macOS system"
    fontSize: "24pt"
    fontWeight: "medium"
  setup-title:
    fontFamily: "macOS system rounded"
    fontSize: "29pt"
    fontWeight: "medium"
    letterSpacing: "-0.6pt"
  device-title:
    fontFamily: "macOS system"
    fontSize: "15pt"
    fontWeight: "semibold"
  body:
    fontFamily: "macOS system"
    fontSize: "13pt"
    fontWeight: "regular"
  action:
    fontFamily: "macOS system"
    fontSize: "13pt"
    fontWeight: "semibold"
  label:
    fontFamily: "macOS system"
    fontSize: "12pt"
    fontWeight: "regular"
  field-label:
    fontFamily: "macOS system"
    fontSize: "12pt"
    fontWeight: "medium"
  option-value:
    fontFamily: "macOS system"
    fontSize: "12pt"
    fontWeight: "semibold"
  caption:
    fontFamily: "macOS system"
    fontSize: "11pt"
    fontWeight: "regular"
  micro:
    fontFamily: "macOS system"
    fontSize: "10pt"
    fontWeight: "regular"
  badge:
    fontFamily: "macOS system"
    fontSize: "10pt"
    fontWeight: "medium"
rounded:
  input: "10pt"
  control: "11pt"
  panel-track: "14pt"
  slider-thumb: "9pt"
  navigation: "8pt"
spacing:
  pt-4: "4pt"
  pt-5: "5pt"
  pt-8: "8pt"
  pt-9: "9pt"
  pt-10: "10pt"
  pt-11: "11pt"
  pt-12: "12pt"
  pt-13: "13pt"
  pt-14: "14pt"
  pt-18: "18pt"
  pt-20: "20pt"
  pt-24: "24pt"
  pt-26: "26pt"
components:
  panel:
    textColor: "{colors.text}"
    rounded: "{rounded.panel-track}"
    width: "440pt"
    height: "632pt"
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.background}"
    rounded: "{rounded.control}"
    padding: "{spacing.pt-11} {spacing.pt-14}"
    typography: "{typography.action}"
  button-secondary:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.text}"
    rounded: "{rounded.control}"
    padding: "{spacing.pt-11} {spacing.pt-14}"
    typography: "{typography.label}"
  tab-item:
    textColor: "{colors.secondary}"
    typography: "{typography.caption}"
    rounded: "{rounded.navigation}"
    height: "34pt"
  tab-item-selected:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.text}"
    rounded: "{rounded.navigation}"
    height: "34pt"
  setup-field:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.body}"
    rounded: "{rounded.input}"
    padding: "{spacing.pt-13}"
  option-tile:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.option-value}"
    rounded: "{rounded.control}"
    padding: "{spacing.pt-11}"
    height: "94pt"
  power-button:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.secondary}"
    size: "42pt"
  slider:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.panel-track}"
    height: "40pt"
  climate-detail:
    typography: "{typography.temperature}"
  eco-control:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.option-value}"
    rounded: "{rounded.control}"
    padding: "{spacing.pt-10}"
  demo-badge:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.accent}"
    typography: "{typography.badge}"
    padding: "{spacing.pt-4} {spacing.pt-8}"
---

# Design System: HomeControl

## Overview

**Creative North Star: "Controle doméstico em vidro fumê"**

Registro do design implementado em SwiftUI e AppKit para a barra de menus do macOS. Três abas rotuladas, Ar-condicionado, Cômodos e Favoritos, organizam o painel. O detalhe do ar-condicionado preserva a composição da referência: identificação à esquerda, energia circular à direita, ilustração central, temperatura proeminente, Eco, slider e opções compactas. O vidro fumê usa material nativo, superfícies translúcidas e bordas claras finas.

A interface segue o idioma do macOS, com en-US e pt-BR, e combina texto marfim, acento oliva-taupe e controles arredondados. O escopo mantém os dispositivos compatíveis do Home Assistant; capacidades da entidade determinam quais controles aparecem. O ar-condicionado é uma imagem gerada, não uma fotografia do aparelho conectado. Os dados de exemplo são identificados por “Demonstração”.

**Key Characteristics:**

- Painel nativo compacto, com três abas rotuladas e ícone fixo na barra de menus.
- Cômodos do Home Assistant, uso diário primeiro e organização local reversível.
- Vidro fumê real, texto quente e superfícies brancas translúcidas.
- Tipografia do sistema, SF Symbols e controles conforme as capacidades.
- Demonstração identificada e preferências de acessibilidade respeitadas.

Esta reconciliação usa somente `PanelView.swift`, `RoomsView.swift`, `DeviceListView.swift`, `DeviceViews.swift`, `Theme.swift` e `App.swift`, com contexto de `PRODUCT.md` e `.impeccable/rooms-surface-contract.md`. Paleta, tipografia e material permanecem integrais; detalhes de conexão já registrados a partir de `SetupView.swift` foram preservados sem nova verificação desse arquivo. As medidas são pontos lógicos do SwiftUI; os pesos são nativos. Os canais percentuais RGBA preservam as frações de `Color`, sem conversão para hex. A leitura é estática, sem inspeção visual, build, testes ou verificação do registro ao vivo.

## Colors

### Primary

`accent` é o oliva-taupe usado em ações proeminentes, ícones de ação selecionados, Eco e preenchimento do slider. O estado ligado da energia aplica opacidades de 0,12 no fundo e 0,48 no contorno desse acento.

### Neutral

`background` é o fundo opaco de acessibilidade e a cor do texto no botão proeminente. `text` é o marfim principal; `secondary` atende legendas, instruções e estados auxiliares. `surface` e `raised` são preenchimentos brancos translúcidos, não cinzas opacos; `line` delimita o slider e a energia desligada.

`glass-tint` escurece o material nativo. `glass-edge` define a borda dos controles. Os três `panel-edge-*` compõem o brilho diagonal da borda externa.

### Status

`good` identifica a conexão estabelecida no ponto do rodapé. `warning` colore indisponibilidade e avisos; a faixa de erro aplica opacidade de 0,08 dessa cor no fundo. Texto e indicadores acompanham a cor para comunicar o estado.

## Typography

San Francisco é resolvida pela fonte nativa `.system`; os números principais e o título de conexão usam `.rounded`. SF Symbols fornece os ícones. Não há fonte externa nem altura de linha global definida nas fontes lidas.

- Temperatura: `temperature` ou `temperature-range`, com `.monospacedDigit()`; a unidade usa `temperature-unit`.
- Conexão: `setup-title`; texto explicativo e campos usam `body`. O texto explicativo acrescenta 4 pontos entre linhas; a ajuda do token acrescenta 3.
- Aparelho: `device-title`; leituras auxiliares usam `caption`.
- Opções e ações: `option-value`, `field-label`, `label` e `action` conforme o papel. A marca HomeControl também usa 12 pontos semibold.
- Rodapé e limites: `micro`; selo de demonstração e título das opções: `badge`.

Nos detalhes de luz e ventilador, o estado usa `.system(size: 30, weight: .medium, design: .rounded)`; na cortina, 32 pontos com o mesmo desenho. Leituras auxiliares usam 23 pontos light para brilho e 24 pontos light para posição. Esses valores são locais, não uma escala tipográfica adicional.

## Layout

O `PanelView` tem tamanho fixo de **440 × 632 pontos**. Cabeçalho, conteúdo rolável, eventual aviso e rodapé formam uma pilha vertical sem espaçamento externo. As fontes não implementam breakpoints nem variantes móveis.

O cabeçalho tem margens horizontais de 20 pontos, topo de 12 e base de 10, reduzida a 8 durante a configuração. As três abas dividem a largura igualmente, com 3 pontos entre botões. A navegação desaparece enquanto `SetupView` está aberto. Na barra do macOS, `NSStatusItem.squareLength` reserva largura quadrada fixa para `house.fill`, em modo template e somente imagem. Não há temperatura variável na barra.

O detalhe tem padding de 20 pontos e mais 2 no topo, com intervalos verticais de 12. A identificação ocupa no mínimo 48 pontos de altura. O bloco do ar-condicionado tem 118 de altura; a imagem usa enquadramento de 224 × 112, ajustada proporcionalmente e deslocada 9 pontos para cima. A linha temperatura/Eco tem 59 de altura. A grade de opções conserva quatro colunas flexíveis e intervalos de 8; opções adicionais seguem para outra linha.

Cômodos reutiliza as margens de 20 pontos e o conteúdo rolável. A visão geral apresenta linhas de áreas com ícone, nome, contagem de uso diário, contagem adicional quando houver e chevron. Os títulos locais usam `.system` arredondada de 27 pontos medium; a lista com título próprio usa 26. Linhas de itens combinam nome, estado ou leitura, ação compatível e favorito; divisores de `line` mantêm o alinhamento do texto. Esses tamanhos locais não ampliam a escala tipográfica do sistema.

A configuração usa margens horizontais de 26 pontos, base de 24 e grupos separados por 20. O rodapé tem padding horizontal de 20 e vertical de 10; seu fundo é `surface` com opacidade adicional de 0,3. O conteúdo rola com indicadores ocultos. A faixa de erro fica antes do rodapé, com padding de 12 e texto rolável limitado a 64 pontos de altura.

## Elevation & Depth

`NativeGlass` cria um `NSVisualEffectView` com material **`.hudWindow`**, mistura **`.behindWindow`**, estado **`.active`** e aparência **`.darkAqua`**. Acima dele, outro `NSView` aplica preto com alfa **0,62**. O material desfoca o conteúdo atrás da janela; o código não define um raio de desfoque para ele.

O painel recebe contorno de 0,75 ponto, com gradiente do canto superior esquerdo ao inferior direito. `GlassSurface` aplica contorno branco de 0,75 ponto aos botões táteis, opções, Eco e campos. Essa sobreposição e os preenchimentos translúcidos estabelecem a profundidade dos controles.

Há uma sombra explícita no puxador do slider: `.shadow(color: .black.opacity(0.35), radius: 3, y: 2)`. Sombras nativas de janelas e popovers pertencem ao macOS/AppKit; não há token de sombra de janela definido nas views inspecionadas.

Com **Reduzir Transparência**, o fundo do painel troca `NativeGlass` por `Palette.background` opaco. Os preenchimentos e contornos dos controles continuam como implementados, sobre esse fundo.

## Shapes

O painel e a trilha do slider compartilham o raio `panel-track`; botões táteis, opções e Eco usam `control`; campos usam `input`; o puxador usa `slider-thumb`. Os cantos são os de `RoundedRectangle`, sem estilo contínuo explicitado.

Energia, favoritos e botões de ajuste são círculos. O selo de demonstração e a trilha do pequeno interruptor Eco usam `Capsule`, sem raio numérico arbitrário. A aba selecionada usa uma superfície `raised` com raio `navigation`, sem sublinhado.

## Components

### Botões

`TactileButtonStyle` tem variantes proeminente (`accent`/`background`) e secundária (`raised`/`text`), com o mesmo padding e borda de vidro. A opacidade é 0,72 durante a pressão e 0,4 quando desabilitado; em repouso, 1. A variante proeminente aparece na conexão; a secundária, nas ações de cortina.

`IconButton` usa `.plain`, círculo, símbolo de 16 pontos medium e tamanho padrão de 36; selecionado, recebe `raised` e ícone `accent`. Há tamanhos locais de 30 para favorito, 26 para configurações e 20 para fechar aviso. Os botões `.plain` e o estilo tátil não definem tratamento próprio de hover nem anel de foco próprio. Menus e demais comportamentos nativos ficam a cargo do sistema.

### Navegação, energia e estado

Ar-condicionado, Cômodos e Favoritos são as três abas do cabeçalho. Cada botão combina SF Symbol de 13 pontos e rótulo visível de 11; a selecionada usa texto semibold, `text`, fundo `raised` e trait `.isSelected`. As demais usam peso regular e `secondary`. Ajuda e rótulo de acessibilidade acompanham o nome. A seleção superior permanece no contexto de origem ao abrir detalhes. O menu de reticências é um `Menu` nativo sem indicador. Quando o mantenedor configura um canal válido, esse menu inclui “Verificar atualizações…”; a instalação usa a interface nativa do Sparkle. Sem configuração e em demonstração, o atualizador não inicia. Quando há mais de um ar-condicionado e o detalhe não veio de Cômodos ou Favoritos, um `Picker` segmentado pequeno seleciona o aparelho. Detalhes abertos a partir dessas listas têm ação de retorno à origem.

A energia é circular e usa `power-button`. Ligada, recebe acento translúcido no fundo e contorno; desligada, `surface`/`line`. Durante um comando, o símbolo vira `ProgressView`. Fica desabilitada quando `store.canControl` é falso, a entidade está indisponível, a ação de energia não é suportada ou há comando pendente.

O selo `demo-badge` exibe “Demonstração” no cabeçalho. O rodapé combina texto de status, ponto de 5 pontos ou progresso e configurações; reconexão pode oferecer “Tentar agora”. Avisos têm ícone, mensagem e fechamento.

### Cômodos, listas e Organizar

`RoomsView` consome `store.registryAreas`, usa `area.id` no escopo e exibe os nomes recebidos do Home Assistant. Toda a casa abre o escopo global; Geral da casa e Sem cômodo aparecem quando têm itens. Sem cômodo identifica ausência de associação, sem inventar localização. A contagem principal é de itens de uso diário, acompanhada da contagem dos outros grupos quando existente.

Carregamento, registro indisponível, ausência de áreas e avisos de metadados têm mensagens distintas. Atualizar cômodos mostra progresso ou ação manual; o status informa demonstração, última organização recebida, sincronização automática ou atualização a cada minuto conforme o estado do store. Essas views não comprovam por si só a sincronização do servidor.

`DeviceListView` apresenta controles de uso diário e ambiente antes dos grupos técnicos. Consumo, rotinas, manutenção, configuração, diagnóstico e outras leituras começam recolhidos nos cômodos. Busca ativa e Favoritos mostram os grupos com resultados diretamente. A busca aparece quando a base tem mais de seis itens e inclui nomes e cômodos dos itens não ocultos, inclusive grupos técnicos. Mudar de cômodo ou categoria limpa busca, expansões e modo de organização.

Organizar alterna para Concluir, exibe instrução curta e acrescenta o menu de cada linha. Classificar como, Usar classificação automática, Ocultar no app e Mostrar no app permitem organização local reversível neste Mac, por servidor conforme o contrato aprovado; não são edição de áreas ou entidades do Home Assistant. Itens ocultos ficam acessíveis em uma seção recolhida durante esse modo. O menu contextual também oferece essas ações. Itens ocultos ou desativados no Home Assistant recebem indicação e não oferecem a alternância local de ocultação.

As linhas mantêm controles e leituras misturados: luzes e interruptores usam switch, cenas usam Ativar, sensores mostram valor e unidade, e aparelhos compatíveis abrem detalhes. Consumo preserva identificação do dispositivo quando houver período, a unidade e o período informado; os grupos separam métricas sem somar energia acumulada e potência instantânea. Favoritos mantém a lista dos itens escolhidos pelas estrelas.

### Opções e Eco

`OptionTile` mantém título de 10 pontos, valor de até duas linhas com espaço reservado, ícone de 20 pontos light e chevron de 9. Abre uma lista nativa em popover de 180 pontos de largura; a altura é `min(300, quantidade × 40 + 10)`. A opção atual tem checkmark. Não há hover ou foco customizado na tile.

Eco é um `Button` com desenho de interruptor, não um `Toggle`: cápsula de 35 × 21 pontos, indicador circular com inset de 2 e fundo alternando `raised`/`accent`. Só aparece quando a entidade suporta presets e oferece tanto `eco` quanto `none`. O ventilador, quando compatível, usa um `Toggle` nativo `.switch` para “Oscilar”, com tint de acento.

### Slider

`ControlSlider` usa trilha de 40 pontos de altura, preenchimento em gradiente de `accent` com opacidades de 0,38 a 0,85 e puxador marfim de 22 × 32. Os botões opcionais de menos/mais têm 36 × 36 pontos. O passo e os limites vêm do controle/entidade; o valor é ajustado ao passo e limitado ao intervalo.

O foco muda o contorno de `line`/1 ponto para `accent`/2 pontos. Arrastar mantém um valor local e chama `onPreview`; o comando só é enviado ao soltar, quando o preview é limpo. Na temperatura de alvo único, o número principal acompanha esse preview e a instrução muda de “Arraste ou use − / +” para “Solte para ajustar”. Sair da view limpa o preview; trocar de aparelho também limpa o preview de temperatura. Os controles de mínima/máxima não usam esse preview no número principal. Setas do teclado, menos/mais e ações ajustáveis de acessibilidade enviam ajustes diretamente. A ajuda nativa do slider explica o arraste e as alternativas de ajuste. No alvo único de clima, a ausência da temperatura substitui o slider por uma explicação: com o ar desligado, ligar ou escolher um modo; ligado, ausência de leitura pelo Home Assistant. Nos outros usos, sem valor ou desabilitado, a opacidade fica em 0,4 e o slider deixa de aceitar foco e ajustes. Menos/mais ficam desabilitados também nos respectivos limites.

### Campos de conexão

`TextField` e `SecureField` usam `.plain`, `setup-field` e a borda `GlassSurface` de raio correspondente. Placeholders são textos sobrepostos em `secondary`, ocultos da acessibilidade e sem interceptar cliques. `FocusState` move do endereço ao token com Return; Return no token chama a conexão. Não há mudança customizada de borda para foco ou erro nesses campos.

O botão de conexão é desabilitado durante a conexão ou com endereço vazio após trim; enquanto conecta, mostra progresso e “Conectando…”. O token é um campo seguro; a ajuda informa seu armazenamento no Chaves deste Mac. Falhas aparecem na faixa de aviso do painel.

### Detalhes e fluxo de ar

`DeviceDetail` escolhe a view nativa de clima, luz, ventilador ou cortina. Controles aparecem somente conforme as capacidades da entidade. O detalhe inteiro fica desabilitado sem controle disponível, com aparelho indisponível ou comando pendente; aparelho indisponível também recebe mensagem explícita. As listas de Cômodos e Favoritos usam `DeviceListView`, com abertura dos detalhes compatíveis e retorno ao contexto de origem.

`AirConditionerView` usa o raster gerado `air-conditioner.png` e, se ele faltar, o SF Symbol `air.conditioner.horizontal.fill`. A imagem fica com opacidade 0,62 quando não está funcionando; esse caso inclui indisponibilidade. A ilustração e o fluxo são decorativos e ocultos da acessibilidade.

O fluxo aparece apenas com entidade ligada e disponível. Quinze trajetórias suaves partem da saída do ar e recebem faixas longas com pontas afiladas, gradiente de transparência e blur de 1,5 ponto. A velocidade reportada do ventilador determina intensidade, alcance e ritmo; a fase é integrada e a intensidade converge suavemente para evitar saltos ao trocar a velocidade. Oscilação horizontal reportada movimenta o fluxo como um conjunto. Automático e valores desconhecidos usam uma intensidade visual moderada, sem indicar potência elétrica. O desenho ocupa apenas os 24–40 pontos abaixo da saída e desaparece antes da borda do painel. O `TimelineView` usa no máximo 30 fps e pausa quando o painel não está visível ou a conexão não permite controlar. Delegates do popover e da janela acompanham visibilidade e oclusão. Com **Reduzir Movimento**, permanece uma indicação estática. Textos, acessibilidade e avisos usam recursos en/pt-BR; números seguem a região do Mac e nomes recebidos do servidor não são traduzidos.

## Do's and Don'ts

### Prévia do widget de clima

`ClimateWidgetCard` mantém a linguagem do painel em um cartão médio de 340 × 160 pontos, com 16 pontos de margem interna. O cômodo ocupa o cabeçalho; a temperatura desejada usa sistema arredondado de 44 pontos, acompanhada da leitura ambiente. O mesmo raster do aparelho fica à direita, sobre os botões −/+ de 48 × 30 pontos. O controle de energia tem 28 pontos. Uma indicação estática de ar acompanha o estado ligado; o widget não mantém animação contínua.

O fundo nativo do WidgetKit usa o tom de vidro fumê do app; o conteúdo usa as cores de texto e acento existentes. A janela de demonstração identifica os dados como Demonstração. Ações indisponíveis e limites de temperatura desabilitam seus botões. O widget oferece ações diretas, sem atalhos para abrir um painel externo. A colocação e as ações da extensão precisam ser verificadas na galeria nativa, separadamente da prévia.

### Do:

- **Do** preservar o painel de 440 × 632 pontos, as três abas rotuladas e a composição aprovada do detalhe de clima.
- **Do** usar o material nativo e seus preenchimentos translúcidos, mantendo o fallback opaco de Reduzir Transparência.
- **Do** conservar a tipografia do macOS, SF Symbols e os estados implementados de foco, pressão e desabilitação.
- **Do** identificar a demonstração e apresentar somente controles suportados pela entidade.
- **Do** manter o fluxo de ar estático com Reduzir Movimento, pausar quando invisível e ocultar quando o aparelho não estiver ligado e disponível.
- **Do** apresentar uso diário primeiro e manter os grupos técnicos recolhidos nos cômodos, respeitando as exceções de busca e Favoritos.
- **Do** usar Organizar para classificação e ocultação locais reversíveis, preservando áreas e estados recebidos do Home Assistant.

### Don't:

- **Don't** substituir a composição aprovada por outra direção visual, restaurar a navegação anterior por categorias ou inventar variantes móveis.
- **Don't** descrever o blur como CSS ou atribuir valores próprios às sombras de janela controladas pelo macOS.
- **Don't** apresentar a imagem gerada como fotografia de um aparelho físico ou dados de demonstração como leituras reais.
- **Don't** afirmar que há hover, foco de campo, rampas tonais ou animações globais customizadas sem implementação nas fontes.
- **Don't** acrescentar controles de fechaduras, alarmes ou portas de garagem ao escopo inicial.

A linha completa de um aparelho com detalhe é um botão com altura mínima de 44 pontos; energia e favorito são ações separadas. Os grupos recolhidos expandem por toda a faixa do título, com mínimo de 40 pontos; o chevron apenas indica o estado.

### Widget com até quatro controles

`HomeWidgetBoard` usa o formato grande de 340 × 354 pontos, margem de 14 pontos e uma grade de até duas colunas. Cada posição mostra o cômodo, o nome do item e seus controles suportados. A ordem é escolhida pela pessoa e guardada na configuração de cada widget. Luzes, tomadas e ventiladores usam energia; cenas usam ativação; ar-condicionado tem energia e ajuste por passos. O formato médio Um aparelho aceita os mesmos tipos do formato grande; ao escolher clima, usa o cartão original do ar-condicionado. Os modelos nativos indicam explicitamente o gesto de botão direito e Editar para trocar itens.

A prévia tem um botão Trocar item ou Trocar itens fora da área que representa o widget. Seu popover permite escolher até quatro itens, deixar posições vazias, mudar a ordem e substituir um item por outro diretamente pelo botão Trocar. A substituição funciona com todas as posições ocupadas. A busca por tipo encontra luzes mesmo sem esse termo no nome do aparelho. Essa configuração usa somente entidades sintéticas. No widget da Mesa, a seleção usa Editar Widget do macOS. Nenhum desses botões de acionamento abre um painel externo.
