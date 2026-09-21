# E2E

Os testes E2E são opt-in e nunca usam produção por padrão.

Execute com RUN_E2E=true e API_BASE_URL apontando para um backend isolado.
Exemplo de parâmetros:
- --dart-define=RUN_E2E=true
- --dart-define=E2E_MODE=true
- --dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1

Para cenários autenticados, passe também um JWT efêmero de usuário de teste:
- --dart-define=E2E_TOKEN=<jwt-de-teste>

Se o cenário exercitar cartão, a chave publicável pode vir por dart-define:
- --dart-define=STRIPE_PUBLISHABLE_KEY=<pk_test_...>

A ideia é o CI subir o backend-nhac e o MariaDB em ambiente isolado e apontar
o Flutter para essa URL. O primeiro smoke valida o contrato público de lojas;
os próximos cenários podem cobrir autenticação, checkout, pagamento mock,
despacho e rastreio.
