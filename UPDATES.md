# Atualizações do aplicativo

O HomeControl integra Sparkle 2.10.0. A configuração pública contém somente o endereço do feed e a chave pública. A chave privada de assinatura permanece no Chaves do computador que publica as versões.

Sem configuração, o app funciona normalmente e não inicia o atualizador. Para um build sem canal, use uma cópia do projeto sem `config/updates.json`. A demonstração também não inicia verificações. O canal deste projeto usa `config/updates.json`: feed estável do GitHub Releases e chave pública de verificação. A chave privada não pertence ao repositório.

## Publicar uma versão deste projeto

O script de build usa `config/updates.json` por padrão. A conta de assinatura é `br.com.homecontrol.updates` no Chaves do mantenedor. Incremente as versões em `Info.plist`, gere o pacote e publique os assets na mesma release:

```sh
./scripts/prepare-release.sh config/updates.json https://github.com/alephscalioni/homecontrol_macos/releases/download/v0.3.3/
```

O `appcast.xml` assinado deve ser um asset da release marcada como **Latest**. O endereço `releases/latest/download/appcast.xml` permanece estável; o ZIP de cada versão usa uma URL versionada. Publique os arquivos completos como rascunho antes de tornar a release Latest. Não substitua os bytes de um ZIP já assinado.

## Preparar um canal próprio para um fork

Resolva as dependências e gere uma chave própria de publicação:

```sh
swift package resolve
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account br.com.homecontrol.updates
cp config/updates.example.json config/updates.local.json
```

Preencha `feedURL` com o endereço HTTPS estável de `appcast.xml` e `publicEDKey` com a chave **pública** exibida pela ferramenta. O arquivo `updates.local.json` é ignorado pelo Git. Nunca copie a chave privada para ele.

Compile a versão com o atualizador habilitado:

```sh
HOMECONTROL_UPDATE_CONFIG=config/updates.local.json ./scripts/build-app.sh
```

A versão inicial precisa ser instalada manualmente. O Sparkle pede permissão para procurar atualizações automaticamente e permite ao usuário escolher o download/instalação automáticos. A ação **Verificar atualizações…** aparece no menu do app quando há configuração válida. Preferências e tokens do Home Assistant ficam fora do `.app` e não são substituídos por uma atualização.

## Preparar as próximas versões

Incremente `CFBundleVersion` em `Info.plist` a cada versão e atualize `CFBundleShortVersionString`. Gere o pacote e o feed assinado:

```sh
./scripts/prepare-release.sh config/updates.local.json https://downloads.example.org/homecontrol/
```

O comando usa a conta `br.com.homecontrol.updates` do Chaves. Uma conta diferente pode ser passada como terceiro argumento. Ele confere se a chave pública corresponde à conta, empacota o app, gera as assinaturas e verifica o feed. A saída fica em `build/updates/VERSÃO-BUILD/`, isolada por versão para preservar os endereços dos ZIPs. Nada é enviado para a internet pelo script.

Publique o ZIP no endereço de download informado e publique `appcast.xml` exatamente no `feedURL`. Não edite o XML após a assinatura. Em GitHub, os ZIPs podem ficar em Releases e o feed em Pages; os endereços precisam ser acessíveis ao atualizador.

O app exige HTTPS e valida as assinaturas do feed e do arquivo antes de extrair a atualização. A configuração habilita instalação automática como escolha sugerida no consentimento inicial; permissões do macOS podem exigir interação para instalar ou relançar.

## Assinatura Apple e distribuição

O build local usa assinatura ad hoc. Para distribuição com Developer ID, informe sua identidade:

```sh
HOMECONTROL_SIGNING_IDENTITY='Developer ID Application: NOME DA ORGANIZAÇÃO (TEAMID)' \
HOMECONTROL_UPDATE_CONFIG=config/updates.local.json ./scripts/build-app.sh
```

O script assina os componentes internos do Sparkle antes do app. Notarização e publicação dependem das credenciais e da infraestrutura do mantenedor; não são executadas automaticamente. Assinatura Apple e assinatura Ed25519 das atualizações são mecanismos diferentes.

Depois de notarizar e exportar o app pelo Xcode, empacote essa cópia sem recompilar ou alterar a assinatura e o ticket da Apple:

```sh
HOMECONTROL_PREBUILT_APP='/caminho/da/exportacao/HomeControl.app' \
./scripts/prepare-release.sh config/updates.json https://github.com/alephscalioni/homecontrol_macos/releases/download/v0.3.3/
```

O script verifica a assinatura do app e sua configuração de atualizações antes de empacotar. Confira também `xcrun stapler validate` e `spctl --assess --type execute` na cópia exportada antes de publicar. Os símbolos de depuração (`.dSYM`) ficam fora do `.app` e não devem ser publicados com os downloads.

Antes de anunciar o canal como funcional, teste uma versão antiga instalada recebendo a nova: descoberta, download, validação, substituição e relançamento. A integração e o pacote podem ser validados localmente; a entrega automática pela internet só pode ser confirmada depois de configurar e publicar o canal.

Referências: [integração do Sparkle](https://sparkle-project.org/documentation/), [publicação](https://sparkle-project.org/documentation/publishing/), [preferências](https://sparkle-project.org/documentation/customization/).
