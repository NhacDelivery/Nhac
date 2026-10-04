# Contrato dos fluxos corrigidos

A identidade visual e os tokens continuam em DESIGN.md e lib/globals/themes.dart.
As mensagens usam português brasileiro e os componentes compartilhados existentes.

| Fluxo | Responsável | Comportamento |
|---|---|---|
| Endereços | EnderecoProvider / EstadoEnderecos | Falha não representa lista vazia; preservar dados e oferecer nova consulta. GPS só cadastra após consulta bem-sucedida e não define padrão. |
| Edição | EnderecosPage / BotaoLargoNhac | Aguardar confirmação, bloquear segundo envio, manter formulário na falha, anunciar sucesso pela página. |
| Checkout | CheckoutTentativaService / CheckoutPage | A tentativa persiste até confirmação. Recuperar pedido confirmado limpa carrinho antes de concluir a tentativa. Produtos esgotados impedem novo envio. |
| Busca | SearchPage / BannerErroInline | Falha parcial de atualização preserva resultados anteriores e mostra tentativa de atualização. |
| PIX | ApiClient / exceptions.dart / PagamentoPendentePage | Preservar PAGAMENTO_INDISPONIVEL e mensagem do servidor; consulta não cria nova cobrança. |
| Loja | LojaRepository / LojaPage | Consultar disponibilidade ao abrir, retomar e a cada 30 segundos em primeiro plano. Falha bloqueia adição até reconfirmar. |
| Produto compartilhado | appRouter / ProdutoLinkPage | Resolver ID pela API, preservar link durante splash, oferecer nova tentativa. Android depende da verificação do domínio. |

Fontes: contratos implementados em PedidoService.buscarPagamento, UsuarioService,
ProdutoController e AvaliacaoRepository; regras de checkout em CheckoutTentativaService.
Critérios de destaque, vendas e fotos não são inferidos de médias nem de uma página de resultados.

## Canonical UI Map

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Form | BotaoLargoNhac / EnderecosPage | EnderecoProvider and existing address API | create / edit | perfil_endereco_regression_test.dart |
| Toast | AppNotification / ui_utils.dart | DESIGN.md | success / error / info | existing widget tests |
| CRUD | EnderecoProvider | UsuarioService and EnderecoRepository | return / retry | endereco_checkout_regression_test.dart |
| Async state | EstadoComRetry / BannerErroInline / EstadoEnderecos | provider errors and API results | empty / error / cached | api_client_test.dart and provider regressions |
