# Par de revisões e isolamento E2E

O par canônico é Nhac `eu-e-tu` + backend-nhac `main`. PRs validam também o código
proposto: o repositório que dispara o workflow usa o commit de merge do PR,
enquanto o outro usa sua branch canônica. Não há dependência de branches antigas
de desenvolvimento.

| Origem | Cliente | Backend |
|---|---|---|
| Push em `eu-e-tu` ou `main` do Nhac | Commit do push | `main` |
| PR do Nhac | Commit de merge do PR | `main` |
| Push em `main` do backend | `eu-e-tu` | Commit do push |
| PR do backend | `eu-e-tu` | Commit de merge do PR |
| Agendamento do Nhac | `eu-e-tu` | `main` |
| Execução manual | `app_ref` ou padrão do workflow | `backend_ref` ou padrão do workflow |

O job `resolve-revisions` resolve as refs uma vez. Todos os devices fazem checkout
dos SHAs imutáveis resultantes. `e2e-metadata/revisions.json` registra os commits,
refs solicitadas, evento, repositório do workflow e execução. O resumo também
aparece no GitHub Actions. Divergência entre SHA esperado e checkout interrompe
o job antes de compilar. Os metadados são enviados junto com os diagnósticos,
inclusive quando uma etapa posterior falha.

## Suíte executada

`tool/run_e2e.sh` executa, nesta ordem:

1. `backend_contract_smoke_test.dart`: catálogo e histórico autenticado; faz login
   com a fixture, sem depender de `E2E_TOKEN` manual.
2. `client_login_e2e_test.dart`: login e abertura da home pela interface.
3. `client_order_cash_e2e_test.dart`: compra em dinheiro, idempotência e rastreio.
4. `client_delivery_e2e_test.dart`: confirmação da loja, preparo, oferta automática,
   aceite, coleta, código inválido/correto, conclusão repetida, histórico, ganhos
   únicos, entregador liberado e avaliação enviada pela interface do cliente.
5. `client_payment_pix_e2e_test.dart`: checkout PIX, retomada pelo histórico,
   mesmo código/prazo/valor e confirmação pelo recurso do perfil E2E.
6. `client_payment_card_e2e_test.dart`: checkout cartão, assinatura inválida,
   evento de falha, retomada da cobrança, webhook assinado de sucesso/repetido,
   falha tardia sem regressão e recuperação da nota fiscal do pedido pago.

`E2E_ONLY` aceita `all`, `contract_smoke`, `login`, `order_cash`, `delivery`,
`payment_pix` ou `payment_card`. PRs/pushes usam
uma repetição; execução manual e agendamento usam três. Uma falha do smoke não
é mascarada pelo sucesso dos testes de interface.

O banco MariaDB é exclusivo do job. O backend usa o perfil `e2e` e é reiniciado
entre arquivos/tentativas, restaurando a fixture. O preflight exige histórico e
pedidos ativos vazios antes do teste. Senhas temporárias são usadas apenas nesse
ambiente. O runner recusa APIs externas e portas já ocupadas e encerra o backend
que iniciou. Os helpers do cliente são executados como versionados, sem patch
temporário pelo backend.

## Verificação e publicação

```bash
python3 -m unittest discover -s tool -p 'test_*.py' -v
bash -n tool/run_e2e.sh
```

Os testes de orquestração usam processos locais simulados para conferir seleção
dos arquivos, reinício, propagação de falha e limpeza. Eles não substituem o E2E
Android com MariaDB, executado no CI.

Integrar primeiro as mudanças do cliente em `eu-e-tu`, para disponibilizar o
runner e smoke atualizados. Depois integrar o workflow do backend em `main`.
Para testar os dois PRs juntos antes do merge, executar manualmente o workflow
escolhendo as duas branches em `app_ref` e `backend_ref`.

GitHub só agenda workflows presentes na branch padrão do repositório. A mudança
do agendamento deve chegar à `main` do cliente no fluxo normal de integração;
publicar somente em `eu-e-tu` já habilita seu push/PR, mas não atualiza o workflow
agendado da branch padrão.

## Cobertura e limites dos novos cenários

O cliente Flutter, HTTP, Spring, WebSocket/polling e MariaDB são reais. Loja e
entregador operam pelas APIs autenticadas: as interfaces dos outros aplicativos
não estão cobertas. O entregador é cadastrado pela API com a conta secundária
`e2e.pedido@nhac.local`; a sessão principal não é substituída.

Retomada significa desmontar a tela de pagamento, abrir o pedido pelo histórico
e continuar o pagamento no rastreio. Não representa encerramento do processo
Android, reinício do dispositivo ou falha de rede. Cada arquivo começa com
estado limpo; a retomada ocorre dentro do mesmo cenário e mantém o banco.

PIX usa a simulação existente, permitida pelo backend somente no ambiente de
teste. Cartão usa eventos HMAC SHA-256 no webhook real e o segredo fictício
`whsec_e2e_mock`. O evento usa `2026-08-26.dahlia`, correspondente a stripe-java
33.4.2; atualizar junto com o SDK. A chave publishable fictícia só habilita a
escolha no checkout do teste; o bootstrap E2E não inicializa a SDK. Não abrir
PaymentSheet com essa chave nem interpretar estes cenários como homologação do
provedor. O teste exige que o webhook altere o pedido, além de retornar HTTP 200.

Todas as novas jornadas conferem um único pedido e estoque 19 (partindo de 20)
após retomadas e operações repetidas. A entrega confere uma única corrida e
frete bruto de R$ 5 nos ganhos, horários de coleta/baixa, ausência de pedido
ativo e código oculto depois da conclusão.

Próximas ampliações: expiração/cancelamento com devolução de estoque, fechamento
real do processo e recuperação por armazenamento, indisponibilidade de rede,
Stripe PaymentSheet/Asaas no sandbox e UI dos aplicativos de loja e entregador.
