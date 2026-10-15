# Dados locais

O projeto não inclui credenciais, inventários ou capturas de uma instalação real. Os exemplos e os dados do servidor simulado são sintéticos.

O token do Home Assistant fica no Chaves do macOS. Endereço do servidor, favoritos e preferências de organização ficam nas preferências locais do app. Esses dados não são gravados no código nem no pacote distribuído.

Os comandos da CLI podem gerar inventários e backups em `.homeassistant/`. Essa pasta é privada e ignorada pelo Git. Não a inclua em arquivos ZIP ou publicações manuais.

Chaves privadas, arquivos `.env`, configurações locais e artefatos de build também são ignorados. Antes de publicar, confira os arquivos selecionados com `git status` e `git diff --cached`.

O atualizador recebe apenas a chave pública de verificação. A chave privada que assina as versões deve permanecer no Chaves ou no armazenamento de segredos da infraestrutura de publicação.
