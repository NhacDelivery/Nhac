# Correções de estados, pedidos e requisições

## Repositórios e implantação

- Flutter: `fix/ux-estados-e-erros`, base `76f9fb4`.
- Backend: `fix/ux-estados-e-erros`, criada a partir de `main` em `22b7796`, sem publicação na main.
- Painel do lojista: `fix/lojista-review-20260928`, base `52ce6e7`; preserva as correções dessa branch.

Publicar o backend antes do aplicativo: o aplicativo utiliza `GET /pedidos/ativos` e `GET /produtos/promocoes`. O endpoint singular continua compatível para clientes antigos. Clientes que finalizam compras sem coordenadas precisam ser atualizados; o backend exige latitude/longitude válidas no endereço de entrega.

## Causas e comportamento

O log fornecido identifica falha de rota, não prova falha de busca de endereço. A inspeção encontrou pedidos antigos com coordenadas opcionais, lojas inicialmente cadastradas em `0,0` e fallback de rota que fabricava um trajeto retilíneo. O checkout geocodifica o endereço completo, rejeita resultados ambíguos/inválidos e só permite concluir após confirmar frete e coordenadas. O backend valida e persiste ambas. A configuração de endereço do lojista já atualiza endereço e coordenadas confirmadas juntos.

A rota exige origem/destino válidos e resposta válida do OSRM. Erros de negócio preservam a mensagem da API; falhas do provedor não viram distância estimada. Não existe vínculo histórico confiável para recuperar coordenadas ausentes de pedidos antigos: não se usa o endereço atual do cliente como se fosse o endereço geográfico histórico. A tela informa a causa; o chat permite confirmar o endereço com a loja. Uma loja com posição inválida deve corrigir seu cadastro. O modo E2E explicitamente simulado permanece separado.

Localização HTTP 204 significa indisponível: não lança exceção, não cria posição e não repete imediatamente. A API exige entregador atribuído, fase de entrega permitida e posição recente (até 120 segundos). Um marcador previamente recebido fica identificado como desatualizado. Uma resposta sem horário não é tratada como posição recente.

O chat só adiciona referência quando aberto pelo produto. Entradas por pedidos não enviam `pedidoReferencia`. O contrato persistido continua sendo `conteudo` com cabeçalho `Produto`, `ID`, `Preço`, `Imagem` opcional e uma linha vazia antes da mensagem. Flutter e lojista interpretam esse formato como cartão; IDs/URLs não aparecem como texto. O `clientMessageId` é preservado no reenvio; a idempotência existente do backend e a conciliação REST/WebSocket evitam duplicações.

Pedidos simultâneos substituem a restrição de pedido ativo. Foram preservados lock por usuário, chave/fingerprint de idempotência, estoque, pagamento e validações. Não havia índice de unicidade de pedido ativo para remover. A home lista todos os pedidos com chave, socket, notificações e acompanhamento por ID. Descoberta inicial não ocupa espaço; atualização mantém cartões conhecidos; falha não significa lista vazia. Snapshots são por usuário, expiram e não guardam código de entrega.

A navbar permanece no `bottomNavigationBar` do Scaffold, com área segura e espaço inferior. A rolagem não recolhe o acesso ao carrinho.

## Responsáveis pelas chamadas e controle

- Catálogo: inicialização/refresh da HomeContent; keep-alive evita recriar a home ao trocar abas. Promoções usam uma página filtrada no backend: loja aberta, produto ativo, desconto cadastrado e preço cobrado estritamente abaixo de R$ 20. `preco` já é final: nenhum segundo desconto.
- Pedidos: HomeOrders descobre/atualiza a lista e recupera falhas por polling de 60 segundos somente ativa. Cada cartão recebe eventos por pedido; não mantém polling individual quando gerenciado pela lista.
- Rastreio: eventos WebSocket e recuperação de status com polling de 30 segundos quando desconectado; localização no máximo a cada 30 segundos. Rota falha tem intervalo de dois minutos; falta de coordenadas exige tentativa explícita.
- SharedGet compartilha operações por Dio, sessão, autenticação, URL e parâmetros. TTL: catálogo/lojas 2 minutos, pedidos 5 segundos, rota 15 minutos, localização 30 segundos. Mutações e eventos invalidam recursos pertinentes; refresh manual invalida o cache. Erros não são cacheados nem repetidos automaticamente.
- Timers e inscrições encerram no dispose; abas/rotas inativas e aplicativo em segundo plano pausam atualizações. Gerações descartam respostas obsoletas; atualização individual prevalece sobre lista anterior ainda em voo.

## Comparação reproduzível de requisições

Contagens observadas em testes de widgets com transporte HTTP simulado, mesmo catálogo (promoção apenas na página 15), mesmo pedido PREPARANDO, rota 400 sem coordenadas, sem entregador atribuído e WebSocket desconectado. A baseline usa os arquivos reais de `76f9fb4`; o cenário novo usa os arquivos desta branch. Cada linha conta as novas chamadas naquela etapa, sem somar etapas anteriores.

| Cenário | Antes | Depois |
|---|---:|---:|
| Abrir home | 20 | 5 |
| Trocar para Feed e voltar | 20 | 0 |
| Abrir rastreio e voltar à home | 5 | 2 |
| Atualizar home manualmente | 18 | 4 |

Reprodução: `dart run tool/prepare_request_baseline.dart`, `flutter test --no-pub --dart-define=E2E_MODE=true test/.request_benchmark_test.dart`, `dart run tool/prepare_request_baseline.dart --clean`. Não são contagens de tráfego de produção. O cenário não mede a frequência de GPS com entregador atribuído.

## Validação e limites

Testes cobrem entradas de chat, histórico/reenvio, pedidos simultâneos e isolamento, home vazia/falha/atualização, navbar após rolagem, deduplicação/invalidação, paginação, respostas antigas e contrato de rota/204. O backend exercita duas compras com banco H2, além do OSRM simulado; testes de concorrência/migração com MariaDB dependem de Docker.

Não foi realizada entrega real nem validação do mapa em produção. Geocodificação nativa, chave do Google Maps, acesso real ao OSRM, GPS físico e implantação conjunta precisam de homologação em dispositivo. Resultados locais e GitHub Actions são apresentados na entrega, sem confundir mocks com produção.
