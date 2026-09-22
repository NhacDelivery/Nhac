# Spec 001 — E2E do app Nhac

Status: PROPOSTA PARA IMPLEMENTAÇÃO
Escopo inicial: `/workspaces/Nhac`
Dependências: `/workspaces/backend-nhac`
Próxima fase: `/workspaces/Nhac-Motoboy`

## 1. Objetivo

Criar uma suíte E2E determinística que valide a jornada crítica do cliente usando o app Flutter real, o backend Spring real e MariaDB isolado.

O primeiro vertical slice deve validar:

`login -> home -> catálogo -> produto -> carrinho -> checkout DINHEIRO -> pedido -> rastreio`

A suíte nunca pode usar produção e nunca pode depender de SMS, e-mail, Google Sign-In, Stripe, PIX, Firebase Push ou geolocalização externa reais.

## 2. Estado atual verificado

- Flutter já possui `integration_test` em `pubspec.yaml`.
- Existe `integration_test/backend_contract_smoke_test.dart`, mas hoje ele testa contrato HTTP, não jornada de UI.
- `API_BASE_URL` e `E2E_MODE` já existem em `AppConstants`.
- `E2E_MODE` já desativa App Check e Push, mas ainda não cria um bootstrap E2E completo.
- Não há testes atuais usando `find.byKey`; seletores estáveis precisam ser adicionados.
- O backend já possui ITs de autenticação/pedido, idempotência e Testcontainers/MariaDB.
- O checkout do app já usa `Idempotency-Key`.
- Pagamentos salvos ainda não estão implementados e ficam fora deste escopo.
- O app Motoboy ainda não possui `integration_test`; ele entra após estabilizar esta spec.

## 3. Princípios do SDD

A implementação deve seguir esta ordem:

1. escrever/ajustar a spec;
2. criar o teste E2E falhando;
3. adicionar somente os hooks/keys/fixtures necessários;
4. fazer o teste passar;
5. remover flakiness;
6. integrar no CI;
7. só então ampliar cenários.

Não alterar regras de negócio apenas para facilitar teste.

## 4. Guard rails obrigatórios

- `RUN_E2E=true` é obrigatório para executar a suíte.
- `E2E_MODE=true` é obrigatório para iniciar o app em modo E2E.
- `API_BASE_URL` deve apontar explicitamente para backend isolado.
- Se `RUN_E2E=true` e a URL contiver `onrender.com` ou outro host de produção, o teste deve falhar antes de executar.
- Credenciais E2E são exclusivas do ambiente de teste.
- Nenhum segredo real deve ser commitado.
- Banco deve nascer limpo e determinístico em cada execução.
## 5. Contrato de fixture do backend

Criar perfil Spring `e2e` com Flyway habilitado e MariaDB real.

Dados mínimos determinísticos:

- usuário: `e2e.cliente@nhac.local`
- senha: `NhacE2E#123`
- papel: `CLIENTE`
- loja: ID fixo `e2e-loja-001`, aberta
- produto: ID fixo `e2e-produto-001`, ativo, estoque >= 20
- preço do produto: valor fixo conhecido
- endereço padrão do usuário dentro do raio de entrega da loja
- taxa/tempo de entrega fixos e previsíveis

O perfil `e2e` deve usar:

- SMS mock
- e-mail mock
- storage mock
- pagamentos externos mock
- JWT secret exclusiva de teste

Preferência: seed por componente Spring ativo somente no profile `e2e`, usando repositories/serviços da aplicação.
Não criar endpoint público de reset/seed disponível fora desse profile.

## 6. Bootstrap E2E do Flutter

Em `E2E_MODE=true`:

- não inicializar Firebase Messaging;
- não ativar Firebase App Check;
- não solicitar permissões push;
- não depender de Google Sign-In;
- não executar chamadas externas de geocoding/places;
- não inicializar Stripe quando o cenário não usar cartão;
- preservar HTTP real contra o backend E2E;
- preservar secure storage/session real do app;
- limpar estado local no início da suíte.

Refatorar o bootstrap somente o necessário, preferindo uma função/classe testável em vez de condicionais espalhadas.

## 7. Contrato de seletores

Adicionar `Key` sem alterar layout/visual.

Convenção:

- `e2e.welcome.continue`
- `e2e.login.email`
- `e2e.login.password`
- `e2e.login.submit`
- `e2e.home.ready`
- `e2e.home.store.e2e-loja-001`
- `e2e.store.product.e2e-produto-001`
- `e2e.product.add`
- `e2e.cart.open`
- `e2e.cart.item.e2e-produto-001`
- `e2e.cart.checkout`
- `e2e.checkout.address`
- `e2e.checkout.payment.cash`
- `e2e.checkout.confirm`
- `e2e.checkout.success`
- `e2e.tracking.root`
- `e2e.tracking.order-id`

Testes não devem depender primariamente de texto visual, posição na árvore ou índice de widget.

## 8. Cenário E2E-001 — Login

Given:
- backend E2E saudável;
- usuário fixture existente;
- sessão local limpa.
When:
- app abre;
- usuário navega para login;
- informa e-mail e senha fixture;
- confirma.

Then:
- backend responde autenticação válida;
- token é persistido;
- app navega para home;
- `e2e.home.ready` fica visível.

## 9. Cenário E2E-002 — Catálogo e carrinho

Given:
- usuário autenticado;
- loja `e2e-loja-001` aberta;
- produto `e2e-produto-001` disponível.

When:
- usuário abre a loja/produto;
- adiciona 1 unidade;
- abre o carrinho.

Then:
- item fixture aparece no carrinho;
- quantidade é 1;
- total corresponde ao preço + regras de frete vigentes;
- carrinho está associado à loja correta.

## 10. Cenário E2E-003 — Checkout em dinheiro

Given:
- carrinho do E2E-002;
- endereço padrão fixture carregado.

When:
- usuário avança ao checkout;
- seleciona `DINHEIRO`;
- confirma o pedido.

Then:
- exatamente um pedido é criado;
- resposta contém `pedidoId`;
- carrinho é esvaziado;
- diálogo/tela de sucesso aparece;
- ao continuar, app navega para `/rastreio?pedidoId=<id>`.

O cenário deve validar implicitamente a proteção de duplo submit:
dois taps rápidos no botão não podem gerar dois pedidos.

## 11. Cenário E2E-004 — Rastreio

Given:
- pedido criado no cenário anterior.

When:
- tela de rastreio abre.

Then:
- `e2e.tracking.root` aparece;
- o pedido exibido é o mesmo `pedidoId`;
- status inicial vindo do backend é renderizado;
- nenhum estado de erro genérico aparece.

## 12. Cenários seguintes, somente após o slice verde

Prioridade P1:
- login inválido;
- sessão expirada/401;
- loja fechada no momento do checkout;
- produto sem estoque;
- conflito de idempotência;
- histórico contém o pedido criado.

Prioridade P2:
- PIX com gateway mock;
- cartão com Stripe totalmente mockado;
- recuperação de senha com código fixture;
- cadastro completo sem provedores reais.

Não implementar P2 antes de E2E-001..004 estarem estáveis no CI.

## 13. Estrutura de testes proposta

`integration_test/`:
- `support/e2e_config.dart`
- `support/e2e_finders.dart`
- `support/e2e_actions.dart`
- `support/e2e_wait.dart`
- `client_login_e2e_test.dart`
- `client_order_cash_e2e_test.dart`
- manter `backend_contract_smoke_test.dart` como smoke separado

Evitar `pumpAndSettle()` sem limite em telas com animação/socket.
Criar helper de polling com timeout e mensagem de erro útil.

## 14. Orquestração local

Pré-condição: repositórios irmãos em `/workspaces`.

Fluxo esperado:

1. subir MariaDB E2E;
2. iniciar `backend-nhac` com profile `e2e`;
3. aguardar `/actuator/health`;
4. iniciar emulador Android;
5. executar Flutter integration tests com:
   - `RUN_E2E=true`
   - `E2E_MODE=true`
   - `API_BASE_URL=http://10.0.2.2:8080/api/v1`
6. coletar logs e encerrar serviços.

Criar script reproduzível, por exemplo `tool/run_e2e.sh`, sem assumir serviços de produção.

## 15. CI

Adicionar job separado de E2E; não misturar com unit/widget tests.

Pipeline:
- checkout Nhac;
- checkout backend-nhac;
- JDK 25;
- Flutter da versão fixada pelo projeto;
- MariaDB service/container;
- backend profile e2e;
- health-check;
- Android emulator;
- `flutter test integration_test/client_order_cash_e2e_test.dart -d <device>`;
- upload de logs em falha.

O job deve ser obrigatório em PRs que alterem:
- auth;
- carrinho;
- checkout;
- pedido;
- rastreio;
- contratos HTTP usados por esses fluxos.

## 16. Critérios de aceite da implementação

A spec é considerada atendida quando:

- E2E-001..004 passam localmente em execução repetida;
- três execuções consecutivas não apresentam flakiness;
- nenhuma chamada toca produção;
- banco E2E usa MariaDB e Flyway;
- nenhum serviço externo real é obrigatório;
- selectors são estáveis e documentados;
- falhas mostram etapa, finder e último estado conhecido;
- unit/widget tests existentes continuam passando;
- backend tests continuam passando;
- CI publica logs/artifacts úteis em falha.

## 17. Arquivos que o Codex deve inspecionar primeiro

Flutter:
- `lib/main.dart`
- `lib/globals/app_constants.dart`
- `lib/globals/router.dart`
- `lib/services/auth_service.dart`
- `lib/pages/auth/email_cliente.dart`
- `lib/pages/auth/continuar_senha.dart`
- `lib/components/home/home_content.dart`
- `lib/pages/carrinho_page.dart`
- `lib/pages/checkout_page.dart`
- `lib/pages/rastreio_pedido_page.dart`
- `lib/controllers/cart_provider.dart`
- `lib/controllers/endereco_provider.dart`
- `integration_test/backend_contract_smoke_test.dart`

Backend:
- `src/test/java/br/com/nhac/backend_nhac/AbstractIntegrationTest.java`
- `src/test/java/br/com/nhac/backend_nhac/domain/auth/AuthFlowIT.java`
- `src/test/java/br/com/nhac/backend_nhac/domain/pedido/PedidoFlowIT.java`
- `src/main/resources/db/migration/`
- configuração de profiles/serviços externos
- entidades/repositories de usuário, endereço, loja, produto e pedido

## 18. Ordem de implementação para o Codex

PR/Slice A — Testability:
- criar bootstrap E2E;
- adicionar keys;
- limpar estado local;
- criar helpers de teste;
- manter comportamento de produção inalterado.

PR/Slice B — Fixture backend:
- profile `e2e`;
- MariaDB + Flyway;
- seed determinístico;
- health-check reproduzível.

PR/Slice C — Happy path:
- E2E-001 login;
- E2E-002 catálogo/carrinho;
- E2E-003 checkout dinheiro;
- E2E-004 rastreio.

PR/Slice D — CI:
- script local;
- job GitHub Actions;
- logs/artifacts;
- execução repetida para detectar flakiness.

## 19. Próxima spec

Após esta ficar verde, criar `002-motoboy-e2e.md` cobrindo:
`login -> cadastro entregador -> online -> oferta -> aceitar -> coletar -> concluir`.

Essa segunda spec deve reutilizar o mesmo backend E2E e a mesma estratégia de fixtures, conectando o pedido criado pelo cliente à jornada do motoboy.
