# E2E do cliente

A suíte usa o app Flutter real contra o backend Spring e um MariaDB isolado. O
runner recusa URLs fora de `localhost`, `127.0.0.1` e `10.0.2.2`.

Com um emulador Android já iniciado e os repositórios `Nhac` e `backend-nhac`
como diretórios irmãos:

```bash
RUN_E2E=true E2E_REPEAT=3 ./tool/run_e2e.sh
```

O script recria as fixtures ao reiniciar o backend em cada repetição e grava os
logs em `build/e2e-logs`.

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
