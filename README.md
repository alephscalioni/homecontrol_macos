# HomeControl

Controle os dispositivos do seu Home Assistant pela barra de menus do Mac. Ajuste o ar-condicionado, acenda as luzes e acesse os controles de cada cômodo sem abrir o navegador.

## Instalação

Requer um Mac com Apple Silicon (M1 ou posterior) e macOS 14 ou superior. Seu Home Assistant precisa estar configurado e acessível pelo Mac.

A versão atual está assinada pelo desenvolvedor, mas a notarização da Apple ainda está pendente. O macOS pode bloquear sua abertura.

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

- **Ar-condicionado:** escolha o cômodo e ajuste a temperatura, o modo, a velocidade e a direção do ar. Arraste a barra de temperatura e solte para confirmar, ou use os botões **−** e **+**.
- **Cômodos:** abra um ambiente para acessar luzes, tomadas, interruptores, cortinas, ventiladores e leituras dos sensores. Clique no nome de um aparelho para abrir seus detalhes.
- **Favoritos:** reúna os itens que você usa com mais frequência. Para adicionar ou remover um favorito, clique na estrela do item.

As opções disponíveis dependem dos recursos de cada aparelho. É possível ligar, desligar e ajustar o brilho de luzes RGB. A escolha de cores, câmeras, multimídia, fechaduras e alarmes ainda não têm controles no app.

## Organizar sua casa

Os cômodos seguem as áreas cadastradas no Home Assistant. Quando você altera uma área por lá, o HomeControl atualiza a organização automaticamente. Itens sem uma área atribuída aparecem em **Sem cômodo**.

Dentro de um cômodo, os controles do dia a dia aparecem primeiro. Leituras de consumo, manutenção e outras informações ficam em seções que você pode expandir quando precisar.

Use **Organizar** para mudar a classificação de um item ou ocultá-lo. É possível restaurar os itens ocultos nessa mesma tela. Essas preferências ficam salvas neste Mac.

## Atualizar o app

Quando o HomeControl perguntar sobre atualizações, permita a busca automática e marque a opção de baixar e instalar novas versões. Para procurar uma atualização manualmente, abra o menu **⋯ → Verificar atualizações…**.

A conexão com o Home Assistant e suas preferências são mantidas ao atualizar.

## Conexão e privacidade

O token de acesso fica guardado no **Chaves do macOS**. Para removê-lo deste Mac, abra as configurações do HomeControl e escolha **Esquecer conexão**.

Se a conexão cair, o app avisa e tenta reconectar. Os controles ficam indisponíveis até a conexão voltar. Você também pode usar **⋯ → Reconectar** para tentar novamente.
