# Correções da revisão de 09/10/2026

Implementado nesta branch: categorias e retries sem retorno de Future no setState; botão + consulta o produto completo e encaminha a seleção dos adicionais; bloqueio de paginação concorrente; retry da página de comentários que falhou; edição do feed com tentativa persistida e chave de idempotência; exclusividade dos métodos de login; proteção mounted no reenvio de SMS; nome da loja vindo do produto; sincronização das preferências com a conta, preservando a escolha local pendente; Universal Links no iOS.

## Configuração e validação fora dos testes locais

O backend correspondente é `feature/chat-clientes-20261008`. O domínio usado pelos links é `backend-nhac.onrender.com` e o pacote Android é `com.feentzs.nhac`.

- Configurar `NHAC_ANDROID_SHA256_CERTIFICATES` no backend com os SHA-256 dos certificados que realmente assinam o APK e, quando aplicável, da assinatura do Google Play. O servidor não inventa um certificado quando essa configuração está vazia.
- Configurar `NHAC_IOS_TEAM_ID`, habilitar Associated Domains no App ID e assinar com o perfil da mesma equipe. AASA está em `/.well-known/apple-app-site-association`.
- Verificar os dois arquivos de associação no domínio HTTPS e testar um link compartilhado com app instalado e sem app. Android: `adb shell pm verify-app-links --re-verify com.feentzs.nhac`, `adb shell pm get-app-links com.feentzs.nhac` e `adb shell am start -a android.intent.action.VIEW -d https://backend-nhac.onrender.com/publicacao/ID_REAL`.
- Validar em dois aparelhos a seleção, remoção e sincronização das preferências; encerrar o processo com uma escolha feita offline e confirmar a sincronização ao reabrir.

## Credenciais E2E

As senhas fixas das fixtures e do banco isolado foram removidas. `tool/run_e2e.sh` gera `E2E_PASSWORD` e `E2E_DB_PASSWORD` temporárias e fornece a mesma senha de conta ao backend e ao teste Flutter. Scripts de navegador usam `E2E_PASSWORD` do ambiente. O backend E2E exige essa variável, sem senha padrão.

O GitGuardian apontou ocorrências em commits antigos do PR 31. A remoção no código atual não apaga esses commits. Se a nova verificação continuar bloqueada, os incidentes históricos devem ser encerrados como credenciais de teste substituídas no painel GitGuardian; não foi reescrito o histórico compartilhado da branch.

## Validação local

301 testes Flutter passaram, incluindo recuperação da edição incerta e sincronização das preferências, incluindo proteção contra uma confirmação antiga apagar uma escolha mais recente pendente. Três testes Python dos contratos E2E passaram. A análise Flutter não apresentou erros ou warnings após preparar o arquivo de ambiente local; há avisos de estilo preexistentes. APK e Universal Links no aparelho precisam das configurações acima e não foram comprovados neste ambiente.
