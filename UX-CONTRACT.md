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
