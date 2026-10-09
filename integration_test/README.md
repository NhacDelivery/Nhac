# E2E do cliente

A suíte usa o app Flutter real contra o backend Spring e um MariaDB isolado. O
runner recusa URLs fora de `localhost`, `127.0.0.1` e `10.0.2.2`.

Com um emulador Android já iniciado e os repositórios `Nhac` e `backend-nhac`
como diretórios irmãos:

```bash
cd ../backend-nhac && ./mvnw -B -ntp -DskipTests package && cd ../Nhac
printf 'API_BASE_URL=http://127.0.0.1:8080/api/v1\nE2E_MODE=true\n' > .env
flutter pub get
RUN_E2E=true E2E_REPEAT=3 ./tool/run_e2e.sh
# Para executar somente o login: RUN_E2E=true E2E_ONLY=login ./tool/run_e2e.sh
```

Use Java 25 para compilar o backend e defina `BACKEND_JAVA_HOME` se o JDK atual
for diferente. O script usa o jar já compilado, reinicia o backend antes de cada
cenário para recriar as fixtures e grava logs e evidências em `e2e-logs/`.
Antes de instalar o APK, confere os contratos de cards, promoções, login,
pedidos ativos e feed, além da presença do produto fixture. Um backend antigo
falha nessa etapa com a rota HTTP, em vez de gerar timeout na tela da loja.
O CI fixa o commit do backend `feature/feed-api` compatível com esses contratos.
Com `E2E_REPEAT=3`, executa três rodadas independentes sem retry; com uma única
rodada, repete uma vez cada teste que falhar e registra `flaky` no resumo.
O arquivo `.env` é a fonte da URL e do modo E2E; o runner rejeita URLs fora do
backend local. Não use esse `.env` para um build de produção.

Seletores estáveis do primeiro slice:

- `e2e.welcome.continue`
- `e2e.login.email`, `e2e.login.password`, `e2e.login.submit`
- `e2e.home.ready`, `e2e.home.store.<lojaId>`
- `e2e.store.product.<produtoId>`, `e2e.product.add`
- `e2e.cart.open`, `e2e.cart.item.<produtoId>`
- `e2e.cart.item.<produtoId>.quantity`, `e2e.cart.store-id`
- `e2e.cart.checkout`, `e2e.checkout.address`
- `e2e.checkout.payment.cash`, `e2e.checkout.total`
- `e2e.checkout.confirm`, `e2e.checkout.success`
- `e2e.checkout.success.order-id`, `e2e.checkout.success.continue`
- `e2e.tracking.root`, `e2e.tracking.order-id`, `e2e.tracking.status`
