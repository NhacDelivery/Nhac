# Correções das pendências de UX — 03/10/2026

Frontend: branch `perf/latencia-tcc`, sobre `42fe14a`. Backend entregue em `patches/backend-nhac-cupons-enderecos.patch`, validado sobre `origin/main` (`a0274bc`) em worktree isolado. O checkout original do backend não foi modificado.

## Checklist implementado

Os números seguem a ordem dos 28 itens solicitados.

| Itens | Resultado |
| --- | --- |
| 1–2 | Cupons recebidos contados no backend; perfil recarrega ao retornar, ativar a aba e retomar o app. |
| 3 | Exclusão do padrão promove outro endereço na mesma transação; mutações serializadas por conta. |
| 4 | Status PIX adapta texto e indicador; dimensões consistentes no loading; valor usa quebra de linha. |
| 5 | Sugestões vêm de produtos reais de lojas abertas, sob “Explore o cardápio”. |
| 6–8 | Endereços distinguem erro de vazio, preservam dados e oferecem retry; falhas ao excluir e ao atualizar após salvar têm mensagens distintas. |
| 9–11 | Número solicitado também para o primeiro endereço sem padrão; formulário bloqueia duplicação e mostra erro; retorno do cadastro valida endereço e recalcula frete. |
| 12 | Carrinho mostra subtotal sem afirmar que inclui entrega. |
| 13–15 | Falha na consulta PIX fica explícita; consulta manual disponível após erro e limite automático; ação de rastreio chamada “Acompanhar pedido”. |
| 16 | Chave e payload persistidos antes do POST em armazenamento seguro, por conta/API; tentativa incerta reutiliza o mesmo envio, inclusive após reabrir a tela. |
| 17–19 | Avaliações distinguem erro e vazio; resumo do produto separado dos comentários da loja; controles inertes removidos. |
| 20–22 | Filtros sem ação, indicadores fixos de qualidade e peso “500g” removidos. |
| 23–24 | Pesquisa pagina fontes separadamente, deduplica resultados e mantém fontes bem-sucedidas quando outra falha. |
| 25–26 | Autocomplete ignora respostas antigas e informa falha nos detalhes do endereço. |
| 27–28 | Rastreio avisa quando o pedido deixa de atualizar; dados pessoais oferece retry. |

## Evidências

- `flutter test --no-pub --reporter expanded`: **258 testes aprovados** (18 regressões adicionadas).
- `flutter analyze --no-pub --no-fatal-infos`: **zero erros e warnings**; 15 infos preexistentes fora dos arquivos alterados.
- `flutter build web --release --no-pub --no-wasm-dry-run`: concluído.
- Backend com patch: `./mvnw -B test`: **412 testes, zero falhas/erros/skips**.
- API real do backend em fixture H2/e2e local: resgate de boas-vindas contabilizado sem novo pedido, resgate repetido não duplica, excluir padrão promove endereço remanescente.
- Chromium com build release e fixture local: perfil com falha/retry; endereços com falha/retry; PIX com consulta automática falhando e consulta manual funcional; nenhum `pageerror` nesses cenários.
- Capturas inspecionadas, incluindo PIX em 320×1000. O layout desktop mantém a escala existente do aplicativo e usa rolagem.

Logs e capturas da execução ficam em `build/ux-validation/` (ignorados pelo Git). `tool/verify_pending_ux_ui.cjs` reproduz endereços/PIX com Playwright, frontend local na porta 3000 e fixture e2e na porta 8089. As credenciais desse script são exclusivas da fixture de testes.

## Aplicação do backend

No repositório do backend, sobre a versão compatível:

```sh
git apply --check /caminho/Nhac/patches/backend-nhac-cupons-enderecos.patch
git apply /caminho/Nhac/patches/backend-nhac-cupons-enderecos.patch
./mvnw -B test
```

A contagem de cupons e a promoção do endereço dependem da publicação desse backend. O patch não foi publicado em produção nesta entrega.

## Limites da validação

Não houve pagamento real, consulta real ao Google Places, execução em aparelho físico nem validação de concorrência contra MariaDB em produção. Persistência e recuperação do checkout foram verificadas com testes automatizados; ainda cabe testar fechamento/reabertura em aparelhos Android/iOS reais. As verificações acima não representam certificação de acessibilidade ou uma execução integral de todos os fluxos de negócio.
