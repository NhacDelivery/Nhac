# Nhac client interaction contract

The authenticated app uses Brazilian Portuguese and the existing Flutter theme. Search shortcuts use the exact `categoriaMenu` values offered in the lojista product form. Bottom navigation has Home, Carrinho, Feed and Perfil; coupons remain available through Perfil and checkout.

| Operation | Pending | Success | Failure and recovery |
| --- | --- | --- | --- |
| Select address and calculate freight | Show an unconfirmed estimate | Confirm the address-specific amount and preserve its coordinates for this checkout | Keep the estimate labeled; retry; do not finalize without confirmed freight |
| Create order | Disable duplicate submission; reuse the same idempotency key | Go to the payment/tracking flow | Preserve cart and address; show server error |
| Track order and courier | Listen to socket and refresh by HTTP periodically | Update status, route, distance, and recent courier marker | Keep order readable; explain missing route and offer retry |
| Send chat message | Keep text until server message ID appears | Clear the confirmed text; deduplicate socket/history by ID | Retain text and retry with the same message ID after uncertain delivery |
| Check Pix | HTTP check on opening; poll while screen remains active | Enter tracking when backend confirms | After polling limit, allow manual status check and explain that payment may still be processed |

Search history is device-local and removed on logout, including session expiry. Product and store data is retained on device for fifteen minutes after closing the app, displayed while it is revalidated; network freshness remains two minutes while home is open. The active order snapshot is also retained for fifteen minutes, but only the server authorizes checkout and payment. Promotions require a positive `percentualDesconto`.

The profile's notification list displays FCM messages registered on this device, scoped to the current account; it is not a server-wide notification history.


# Performance and recovery additions

## Canonical UI Map

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Toast | lib/globals/ui_utils.dart e usos existentes de context.showError | Implementação compartilhada e textos do backend | erro e informação | testes de telas existentes |
| CRUD | PedidoRepository, CheckoutPage e pagamento | API de pedidos e idempotência | criação, recuperação e cancelamento | test/repositories/pedido_repository_test.dart |

O mapa cobre os fluxos alterados nesta revisão; não representa certificação de acessibilidade de todo o produto.

## Catálogo e paginação

A loja pede 50 produtos por página com ordenação por id. A primeira página é exibida sem aguardar as demais. Carregar mais é explícito. Erro inicial usa retry; erro posterior preserva os cards existentes. Uma requisição em andamento impede outra carga da mesma página. IDs duplicados não criam cards duplicados.

Os endpoints /produtos/cards e /produtos/cards/promocoes preservam os campos de card e omitem os grupos de adicionais. O detalhe completo continua no endpoint original. Publicar o backend antes do app que usa os novos endpoints.

## Busca e cache

O resultado pode aparecer do cache e ser revalidado. Respostas de buscas antigas são ignoradas. Gravar o cache local não atrasa a exibição. O estado da busca continua local nesta revisão, conforme a arquitetura Flutter existente; não criar URLs com informações de checkout ou endereço.

SharedGet separa clientes, sessão, autenticação, caminho e parâmetros. Uma mutação invalida os caminhos relacionados. Uma resposta anterior à invalidação não repovoa o cache. Invalidar pedidos não impede um catálogo em andamento de ser armazenado.

## Pedidos e recuperação

O servidor confirma a reserva antes de chamar o provedor externo. Se a reserva existe mas o gateway não respondeu, o erro inclui pedidoId. O app abre a recuperação do pagamento do pedido existente. Não iniciar outro POST automaticamente.

A idempotência conserva o mesmo pedido e o mesmo estoque reservado. Um resultado externo inconclusivo impede cancelamento e devolução do estoque até conciliação. O cupom permanece reservado junto com o pedido; volta a ficar disponível quando o cancelamento seguro termina.

## Carregamento

Refresh da home inicia catálogo e pedidos sem aguardar GPS. GPS tem limite de 8 segundos. Rastreio mostra o pedido antes da consulta de loja/rota. Inicialização de push acontece após o primeiro frame e falhas são reportadas ao Sentry. A reserva de pedido, as configurações de pagamento e a autenticação continuam obedecendo às suas dependências.

## Perfil, endereço e dados secundários

UserProvider distingue consulta pendente de falha; conserva o usuário carregado em refresh e oferece retry. ProfileContent atualiza usuário e estatísticas em paralelo. Contagens indisponíveis usam travessão e retry, sem fabricar zeros. Pedidos no resumo abre /meus-pedidos.

A confirmação de identidade em ProfileContent é a única responsável pelo aviso; cancelamento do diálogo ou Google não exibe falha. O botão bloqueia operações simultâneas. Telefone e e-mail de conta Google são somente leitura, com motivo visível e sem seta de edição.

EnderecoProvider define o padrão com um único PUT; UsuarioService.atualizarEndereco desmarca os demais na mesma transação. O estado local só muda após sucesso. selecionarEnderecoPadrao compartilha aviso e resultado; seletores só fecham após confirmação e checkout repete a validação do número.

CartRepository grava itens e observação em um snapshot por conta, com fila de gravações e compatibilidade com listas antigas. Carrinho vazio limpa observações. Falha de loja não invalida o pedido carregado nem confirma loja fechada. Seguidores têm loading, erro/retry e bloqueio de mutação concorrente.


## Recuperação de perfil, catálogo e checkout

- Formulários e feedback reutilizam Form/TextFormField, os botões Nhac, context.showError/showInfo e BannerErroInline. Lista vazia exige consulta bem-sucedida; erros preservam conteúdo anterior e têm retry.
- EnderecoProvider é o dono das mutações e consultas de endereço. Resposta antiga não substitui consulta nova. Falha de refresh após alteração confirmada informa “Alteração salva”; repetir somente a consulta. O backend promove outro padrão sob lock da conta ao excluir o atual.
- Perfil atualiza estatísticas ao ficar ativo, voltar de uma rota e retomar o aplicativo. “Cupons” conta cupons recebidos pela conta, incluindo usados, não pedidos com desconto.
- Busca pagina nome (20), categoria (50) e lojas (50) independentemente, com ordenação por id. Carregar mais preserva resultados, deduplica IDs e repete apenas fontes pendentes. Recomendações são produtos reais de lojas abertas, sem afirmar popularidade.
- Nota do produto e comentários recentes da loja são seções distintas. Controles sem operação e indicadores sem fonte foram removidos. Não há peso padrão inventado.
- Pix mostra erro de consulta, oferece verificação manual desde a abertura, encerra polling no limite e conserva a consulta manual. Acompanhar pedido abre o rastreio.
- CheckoutTentativaService persiste chave e payload original no FlutterSecureStorage, isolados por conta e URL da API, antes de enviar o POST. O payload inclui endereço/CPF e não vai para SharedPreferences nem logs. Tentativa incerta não expira automaticamente; impede nova criação até recuperação/rejeição definitiva. Recuperar reenvia exatamente o payload com a mesma chave; confirmação persistida evita outro POST. A entrada é removida após encaminhar o resultado conhecido. Não descartar uma tentativa por conflito de idempotência.
- Rastreio mantém o pedido carregado e sinaliza falha de atualização, separadamente da posição antiga do motoboy. Dados pessoais usa erro/retry do UserProvider.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| Form | Flutter Form/TextFormField e EnderecoProvider | API de endereços e contrato acima | cadastro e número no checkout | test/pages/endereco_checkout_regression_test.dart |
| CRUD | EnderecoProvider e CheckoutTentativaService | API e idempotência por usuário | mutação confirmada e recuperação | test/controllers/perfil_endereco_regression_test.dart e test/services/checkout_tentativa_service_test.dart |


## Correções de endereços, PIX e catálogo (04/10/2026)


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


# Contrato de interação — integração do feed

Visual: [DESIGN.md](DESIGN.md). Este documento registra apenas o fluxo tocado.
Contrato do servidor: `backend-nhac/docs/feed-api.md` na branch correspondente.

| Capacidade | Responsável canônico | Verificação |
|---|---|---|
| Formulário | TextField Material; validação e limites da API | teste de repositório; dispositivo pendente |
| Toast | ErrorUIHelper / AppUiUtils / showAppNotification | fluxo existente da LojaPage |
| CRUD do feed | FeedRepository / ApiClient; FeedController no backend | FeedIntegrationTest; feed_repository_test |
| Navegação | GoRouter no feed e Navigator/LojaPage na loja | rotas existentes; dispositivo pendente |

A listagem usa as quatro categorias atuais e páginas de 20 itens, sem fallback mock.
Ao trocar categoria, respostas antigas não substituem a seleção atual. Erro permite
“Tentar novamente”. Voltar dos detalhes recarrega contagens do feed.

O comentário só é limpo após confirmação do servidor. Durante envio, novo envio é
bloqueado; erros usam a notificação existente e preservam o texto. Curtir/salvar usam
PUT/DELETE idempotentes e só alteram a interface após resposta do servidor.

As abas de comentários filtram/ordenam os comentários já carregados; “Carregar mais”
traz a página seguinte. Não existem curtidas/respostas de comentário implementadas.
“Ver loja e fazer pedido” consulta a loja real e abre LojaPage, responsável pelo
fluxo de seguir e comprar. Criar posts abre `/feed-publicar` e retorna ao feed após confirmação do servidor.
A tela permite texto, até seis fotos e menção opcional a uma loja buscada pela API.
Uploads confirmados são reutilizados durante uma nova tentativa na mesma tela.
Texto e fotos são preservados em falhas; envio bloqueia novas submissões e saída.
Voltar com conteúdo não publicado exige confirmação de descarte.
Publicações de cliente não declaram patrocínio; a autoria vem da sessão.
POST não é idempotente: falha de confirmação orienta conferir o feed antes de repetir.
Edição continua disponível pela API. Não mostrar números fictícios de compartilhamento.

Contexto de negócio: principal do JWT determina autoria; FeedService determina
permissões e promoção da loja; a API exige autenticação. ApiClient é o responsável
pela expiração da sessão. Idioma das ações e recuperação: português brasileiro.
