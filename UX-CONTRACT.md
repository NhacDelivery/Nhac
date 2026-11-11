# Nhac client interaction contract

## Pagamento e comprovante (13/10/2026)

`PAGAMENTO_INDISPONIVEL` preserva a mensagem do servidor: indisponibilidade
temporária não prova expiração. O estado do pedido continua determinando a
navegação para rastreio ou histórico. Retry consulta o mesmo pedido.

Dinheiro pendente usa “Aguardando confirmação da loja” e informa “Pagamento na
entrega”; `PAGO` em dinheiro usa “Pedido confirmado”. Home, rastreio, notificação
ao vivo e histórico reutilizam `StatusPedido.labelParaPagamento`. O histórico
recebe `formaPagamento` de `PedidoResumoDTO`; respostas antigas sem esse campo
continuam legíveis. Publicar o backend antes do cliente para os textos completos.

O checkout captura o comprovante local antes de consumir o carrinho. A consulta
confirmada do servidor prevalece sobre esse snapshot; se falhar, itens, desconto,
frete e total da compra continuam disponíveis. Troco é opcional em dinheiro,
deve ser positivo e cobrir o total após desconto e frete. O servidor valida o
total canônico e rejeita a compra inteira sem consumir estoque ou cupom.

Fontes: `PedidoReservaService`, `PedidoCreateDTO`, `PedidoResumoDTO` e
`NotaFiscalDados.fromCarrinho`. Verificação: `PedidoFlowIT`, testes de pagamento
pendente, comprovante, cartão da home e histórico.

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


## Feed e avaliações (05/10/2026)

Fonte: FeedService e AvaliacaoProdutoService no backend feature/feed-api.
Permissões retornadas pela API: autor/admin editam e excluem posts; autor do comentário,
autor do post e admin excluem comentários. Confirmação Flutter antes de excluir.
Curtidas no cartão usam a resposta confirmada; comentar abre o campo em foco.
Hashtags cadastradas aparecem separadamente. Salvos reutiliza cartões e paginação explícita.
Comentários usam ordem/filtro de autor no servidor e deduplicação por ID. Consultas do post
e comentários são independentes. Refresh conserva a lista e oferece retry.
Seguir acompanha a loja mencionada via favoritos persistidos; sem loja o botão não aparece.
Destaques ordena por salvos/curtidas/data; Novidades por data. O primeiro comentário é destacado,
com desempate por ID e sem contagem fictícia de curtidas.
Tentativas de envio conservam chave e payload em armazenamento seguro por conta/API/escopo.
Reabrir restaura e repetir recupera o mesmo recurso. O servidor confere fingerprint sob lock
da conta e mantém registro de recursos excluídos para impedir recriação no replay.
Compartilhar usa nhac://app/publicacao/{id}; Android/iOS registram o esquema e a rota consulta
o servidor após login. Requer app instalado. Universal Links dependem de domínio e arquivos
de associação não disponíveis nesta mudança.
Avaliações individuais de produtos usam uma nota por pedido/produto, somente do comprador
para itens de pedidos ENTREGUE, com fotos de upload HTTPS. Positivas: notas 4 e 5. Filtros
consultam o servidor antes de paginar. Resumo do produto não converte notas da loja em notas individuais.
Em destaque na loja usa desconto > 0; Vendidos ordena quantidades de pedidos ENTREGUE.
Percentual positivo da loja usa suas avaliações com nota >= 4 e não afirma percentual por produto.
Recuperação do checkout subtrai só produto/quantidade/loja do payload original e grava um recibo
junto ao carrinho, conservando itens adicionais e evitando novo consumo no replay.


## Chat e erros — passo 4

Fontes: `backend-nhac/docs/chat-clientes.md`, `ConversaClienteController`,
`ChatService` e DTOs de mensagens. O backend existente é suficiente; não há
nova regra de permissão nesta mudança.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| CRUD | ChatRepository / ChatConversaPage | API /conversas e clientMessageId | pessoa / loja / pedido / produto | chat_passo4_test.dart; client_chat_e2e_test.dart |
| Toast | ErrorUIHelper / AppUiUtils | exceções tipadas da API | banner persistente / notificação | error_ui_helper_test.dart |

- Pessoas e Lojas conservam listas, páginas e posição por aba. Consultar novamente
  não transforma falha em caixa vazia. Retry repete a operação que falhou.
- Buscar filtra nome e prévia das conversas carregadas. O texto do campo informa
  esse alcance; carregar mais continua disponível durante o filtro. A busca é
  local e temporária, sem enviar conteúdo privado para URLs ou analytics.
- Tocar em Pessoas abre o ID existente, sem criar uma conversa com loja. O autor
  é definido por remetenteUsuarioId e pela sessão; CLIENTE não significa “eu”.
- Loja, pessoa, pedido e produto reutilizam ChatConversaPage. O texto só é limpo
  após a mensagem confirmada. IDs deduplicam socket, histórico e resposta REST.
- Socket indisponível usa POST de mensagem por REST. Ausência de confirmação por
  15 segundos tenta REST uma vez com o mesmo clientMessageId; erro conserva a
  tentativa e permite reenvio com o mesmo ID. Não afirmar falha definitiva quando
  a persistência é incerta. Envio pendente bloqueia alterações do mesmo texto.
- Reconectar restabelece o socket e atualiza o histórico. Em primeiro plano, uma
  conexão indisponível consulta o histórico a cada 15 segundos sem sobreposição.
  Sair ou colocar o aplicativo em segundo plano interrompe essas consultas.
- Falhas persistentes usam BannerErroInline e ErrorUIHelper; textos tipados do
  backend são preservados. Falhas técnicas desconhecidas não exibem detalhes
  internos. Não existem botões de busca/menu/criação de conversa sem operação.

Verificação visual: capturas de estados de widgets no job Chat e estados de
recuperação. Não equivalem a uma certificação de browser/acessibilidade completa.


## Operação de pagamentos (passo 5)

OperacaoPagamentoCard é o dono compartilhado do acompanhamento no rastreio e no
pedido cancelado. Consulta ao abrir, ao retomar e a cada 30 segundos enquanto a
rota estiver visível, sem sobreposição. Não armazena estado financeiro em disco.
Falhas preservam o último estado e oferecem retry somente da consulta.

O backend autoriza estorno automático somente do pedido PAGO, antes do preparo,
com cobrança eletrônica identificada. confirmarNhac informa que cancelar o pedido
é imediato e a devolução é assíncrona. O botão bloqueia do diálogo ao fim do envio.
Resultado incerto exige consultar antes de permitir nova solicitação. O servidor
é idempotente; nunca afirmar devolução concluída antes da confirmação do provedor.
Após confirmação do cancelamento, o rastreio abre os detalhes existentes; histórico
mostra o mesmo acompanhamento. Publicar o backend com V1023 antes do app.

| Capability | Canonical owner | Source of truth | Allowed variants | Verification |
|---|---|---|---|---|
| CRUD | PedidoRepository / OperacaoPagamentoCard / confirmarNhac | autorização e fila persistida do backend | solicitação e acompanhamento | test/components/operacao_pagamento_card_test.dart |


## Home com catálogo pequeno (16/10/2026)

HomeCategoryChips é o único dono dos atalhos de categorias na home. Os banners
mostram produtos reais e abrem seus detalhes, usando as próprias imagens e nomes.
Não fazem outra consulta de categorias e não usam uma foto genérica para sugerir
conteúdo que não existe. O carrossel pausa fora da rota/app ativo ou com redução
de movimento e se ajusta quando o catálogo muda.

HomeProductSelection deriva as seções sem filtrar/truncar o catálogo original:
prioriza lojas abertas, deduplica por ID e limita cada seção a dez itens. A faixa
abaixo de R$ 20 usa o preço real, inclusive sem desconto. Se nenhum produto atende,
mostra “Explore o cardápio” com produtos existentes, sem inventar oferta/preço.
As duas seções podem compartilhar produtos quando o catálogo é pequeno. Lojas
fechadas continuam visíveis para consulta, com identificação e bloqueio existente
de adição; o servidor permanece responsável por autorizar a compra. Falhas mantêm
os produtos carregados e o retry; consulta bem-sucedida sem produtos é o único vazio.
O catálogo é solicitado com lojas abertas primeiro, antes do limite de 50 itens.


## Entrada do feed

O feed usa FeedPublishInvite para convidar a compartilhar uma experiência com comida.
A ação reutiliza /feed-publicar e a mesma recuperação de publicação do cabeçalho.
Voltar sem publicar preserva lista/categoria; publicar recarrega Destaques.
Salvos não mostra o convite. Não consultar categorias de produtos, usar fotos
genéricas, autoplay ou prometer promoções nesse espaço. Conteúdo editorial
permanece disponível mesmo quando a listagem falha.
