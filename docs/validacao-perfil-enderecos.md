# Perfil, endereços e recuperação — 03/10/2026

A branch fix/perfil-enderecos-recuperacao parte de 47ae2d8 e preserva as otimizações de perf/latencia-tcc. O backend já define o endereço padrão atomicamente em UsuarioService.atualizarEndereco; não é necessário desmarcar o anterior no cliente.

## Alterações

- Pedidos no resumo navega para /meus-pedidos; opção duplicada removida; área inteira do cartão recebe clique.
- Confirmação de identidade tem um aviso por falha; cancelamento não exibe falha; operações simultâneas são bloqueadas.
- Perfil distingue loading de erro e oferece retry. Estatísticas indisponíveis não viram zero; refresh busca contagens novas sem reutilizar cache anterior.
- Endereço padrão usa um PUT, conserva seleção anterior quando falha e não mostra sucesso indevido; seletores compartilham o tratamento.
- Complemento opcional é seguro no carrinho; trocar endereço no checkout repete a solicitação de número.
- Pedido carregado continua visível quando loja falha, com retry. Produto diferencia erro de consulta de loja fechada.
- Seguidores têm erro/retry e botão ocupado; múltiplos cliques geram uma operação.
- Itens e observações do carrinho são persistidos juntos e isolados por conta; carrinho vazio limpa observações e cache antigo permanece compatível.
- Telefone e e-mail Google são somente leitura com motivo visível. Ajustados estouros de layout nos controles, ações de endereço e diálogo de número.

## Verificação

- flutter test --no-pub: 240 testes passaram (22 novos cenários sobre a base de 218).
- flutter analyze --no-pub --no-fatal-infos: sem erros ou warnings; 15 infos de estilo preexistentes em arquivos fora das correções.
- flutter build web --release --no-pub --no-wasm-dry-run: build JavaScript de produção.
- Auditoria estática premium strict: zero achados; esse auditor não analisa Dart e não certifica acessibilidade.
- Chromium 390x844: login fixture, falha de estatísticas, retry e contagens reais, cartão Pedidos abre histórico; também inspecionado 1280x900.
- Chromium: contagem de seguidores falha e se recupera; seis cliques rápidos produzem um POST e contagem passa de 10 para 11.
- Chromium: falha de loja no produto não mostra loja fechada; retry por foco/Enter recupera o botão Adicionar.
- Testes de widgets: senha, Google, SMS e cancelamentos sem avisos duplicados; endereço sem complemento; checkout pede número ao trocar; rastreio conserva pedido sem loja.
- Testes de providers/repos: gravação/restauração de observações, isolamento por conta, falha/nulo do perfil, PUT único, preservação do padrão após erro, zero legítimo e atualização de cache das estatísticas.

Google, SMS e biometria reais dependem de conta/provedor e dispositivo. A confirmação desses fluxos foi validada com mocks; a verificação web usa somente as credenciais públicas da fixture E2E. Não certifica autenticação externa nem toda a responsividade do aplicativo.

## Reproduzir

Com o backend de fixtures em 127.0.0.1:8089 e o build web servido em localhost:3000:

    NODE_PATH=/tmp/nhac-browser/node_modules node tool/verify_profile_ui.cjs
    NODE_PATH=/tmp/nhac-browser/node_modules node tool/verify_follow_product_ui.cjs

Requer Playwright/Chromium na pasta de ferramentas. As falhas, estatísticas e favoritos são interceptados no navegador; não alteram conta de produção. Imagens ficam em /tmp/nhac-ux-ui, ou no diretório indicado por NHAC_UX_SHOTS.
