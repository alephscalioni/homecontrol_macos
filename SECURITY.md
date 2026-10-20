# Dados locais

O projeto não inclui credenciais, inventários ou capturas de uma instalação real. Os exemplos e os dados do servidor simulado são sintéticos.

O token do Home Assistant fica no Chaves do macOS. Endereço do servidor, favoritos e preferências de organização ficam nas preferências locais do app. Esses dados não são gravados no código nem no pacote distribuído.

No port Windows/Linux, o token fica criptografado no perfil local do aplicativo com a proteção do sistema (DPAPI, KWallet ou Secret Service). O pacote inclui somente o runtime, fontes e assets do aplicativo, sem o perfil do usuário. Nenhuma credencial é persistida usando o backend Linux `basic_text`. O processo de interface não recebe o token; o processo principal mantém a conexão com o Home Assistant.

Os comandos da CLI podem gerar inventários e backups em `.homeassistant/`. Essa pasta é privada e ignorada pelo Git. Não a inclua em arquivos ZIP ou publicações manuais.

Chaves privadas, arquivos `.env`, configurações locais e artefatos de build também são ignorados. Antes de publicar, confira os arquivos selecionados com `git status` e `git diff --cached`.

Instaladores públicos e código usam exemplos sintéticos. Evidências locais de depuração, inventários e capturas de uma instalação real não devem ser anexados às releases. Nome e identificação pública do mantenedor permanecem nos metadados de autoria; commits antigos podem conter o e-mail usado na época.

O atualizador recebe apenas a chave pública de verificação. A chave privada que assina as versões deve permanecer no Chaves ou no armazenamento de segredos da infraestrutura de publicação.
