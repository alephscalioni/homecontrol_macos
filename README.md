# HomeControl

[English](README.en-US.md)

Controle os dispositivos do seu Home Assistant pela barra de menus do Mac. Ajuste o ar-condicionado, acenda as luzes e acesse os controles de cada cômodo sem abrir o navegador.

O app acompanha o idioma do Mac, com português do Brasil e inglês dos Estados Unidos. Os nomes dos seus aparelhos e cômodos permanecem como você cadastrou no Home Assistant.

## Instalação

Requer um Mac com Apple Silicon (M1 ou posterior) e macOS 14 ou superior. Seu Home Assistant precisa estar configurado e acessível pelo Mac.

A versão atual é assinada pelo desenvolvedor e distribuída sem notarização da Apple. O macOS pode bloquear sua abertura.

1. [Baixe a versão mais recente](https://github.com/alephscalioni/homecontrol_macos/releases/latest).
2. Extraia o ZIP e mova **HomeControl.app** para a pasta **Aplicativos**.
3. Abra o app. Uma casa aparecerá na barra de menus; clique nela para abrir os controles.

Para conhecer o app antes de conectar sua casa, escolha **Explorar demonstração**. Essa opção mostra aparelhos de exemplo.

## Conectar ao Home Assistant

Na primeira abertura:

1. Informe o endereço do seu Home Assistant, como `http://homeassistant.local:8123` ou o endereço HTTPS que você já utiliza.
2. No Home Assistant, abra seu **Perfil → Segurança → Tokens de acesso de longa duração** e crie um token com o nome HomeControl. Esse código autoriza o app a acessar sua casa.
3. Copie o token, cole no campo indicado e clique em **Conectar ao Home Assistant**.

Seus dispositivos e cômodos aparecerão após a conexão. Não é necessário instalar uma integração adicional no Home Assistant.

## Usar os controles

O app tem três abas:

- **Ar-condicionado:** escolha o cômodo e ajuste a temperatura, o modo, a velocidade e a direção do ar. Arraste a barra de temperatura e solte para confirmar, ou use os botões **−** e **+**. A animação do vento acompanha a velocidade do ventilador informada pelo aparelho.
- **Cômodos:** abra um ambiente para acessar luzes, tomadas, interruptores, cortinas, ventiladores e leituras dos sensores. Clique no nome de um aparelho para abrir seus detalhes.
- **Favoritos:** reúna os itens que você usa com mais frequência. Para adicionar ou remover um favorito, clique na estrela do item.

As opções disponíveis dependem dos recursos de cada aparelho. É possível ligar, desligar e ajustar o brilho de luzes RGB. A escolha de cores, câmeras, multimídia, fechaduras e alarmes ainda não têm controles no app.

## Organizar sua casa

Os cômodos seguem as áreas cadastradas no Home Assistant. Quando você altera uma área por lá, o HomeControl atualiza a organização automaticamente. Itens sem uma área atribuída aparecem em **Sem cômodo**.

Dentro de um cômodo, os controles do dia a dia aparecem primeiro. Leituras de consumo, manutenção e outras informações ficam em seções que você pode expandir quando precisar.

Use **Organizar** para mudar a classificação de um item ou ocultá-lo. É possível restaurar os itens ocultos nessa mesma tela. Essas preferências ficam salvas neste Mac.

## Widgets na Mesa

Mantenha o HomeControl aberto e conectado. Clique com o botão direito na Mesa, escolha **Editar Widgets** e procure **HomeControl**.

- **Um aparelho:** escolha uma luz, tomada, interruptor, ventilador, ar-condicionado ou cena. O ar mantém os botões de temperatura **−/+** quando oferece esse ajuste.
- **Até 4 controles:** misture até quatro itens e escolha a ordem em que aparecem.

Para trocar os itens depois, clique com o botão direito no próprio widget, escolha **Editar** e altere **Aparelho** ou **Itens**. A busca aceita nome, cômodo e tipo, como “luzes”. Não é necessário marcar um item como favorito para usá-lo no widget.

Aparelhos indisponíveis ficam com os controles desativados. Se um item for removido ou você trocar de conexão, escolha-o novamente na edição do widget.

## Favoritos na Central de Controle

No macOS 26 ou superior, abra a **Central de Controle → Editar Controles**, procure **HomeControl** e adicione um controle de energia ou de cena. Escolha um item que você marcou como favorito no app. Para controlar mais de um favorito, adicione mais controles.

Os controles de energia ligam e desligam o aparelho; os de cena a ativam. Ajustes de temperatura ficam nos widgets ou no app.

## Atualizar o app

Quando o HomeControl perguntar sobre atualizações, permita a busca automática e marque a opção de baixar e instalar novas versões. Para procurar uma atualização manualmente, abra o menu **⋯ → Verificar atualizações…**.

A conexão com o Home Assistant e suas preferências são mantidas ao atualizar.

## Conexão e privacidade

O token de acesso fica guardado no **Chaves do macOS**. Para removê-lo deste Mac, abra as configurações do HomeControl e escolha **Esquecer conexão**.

Se a conexão cair, o app avisa e tenta reconectar. Os controles ficam indisponíveis até a conexão voltar. Você também pode usar **⋯ → Reconectar** para tentar novamente.
