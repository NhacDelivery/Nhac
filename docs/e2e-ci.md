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

`E2E_ONLY` aceita `all`, `contract_smoke`, `login` ou `order_cash`. PRs/pushes usam
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

Esta etapa alinha e torna reproduzível a suíte existente. PIX/cartão e entrega
completa entre os três aplicativos continuam sendo a próxima ampliação de E2E.
