import 'package:nhac/models/feed/feed_post_model.dart';

class FeedRepository {
  // Dados mockados — substitua por chamada à API quando disponível
  Future<List<FeedPostModel>> buscarPosts({String categoria = 'Destaques'}) async {
    await Future.delayed(const Duration(milliseconds: 600));

    final todos = _mockPosts;

    switch (categoria) {
      case 'Promoções':
        return todos.where((p) => p.isPatrocinado).toList();
      case 'Novidades':
        return todos.reversed.toList();
      default:
        return todos;
    }
  }

  static const List<FeedPostModel> _mockPosts = [
    FeedPostModel(
      id: '1',
      nomeUsuario: 'Ana Lima',
      avatarUrl:
          'https://i.pravatar.cc/150?img=47',
      badge: 'Recomendado para você',
      conteudo:
          'Pedi o poke bowl de salmão aqui no app e chegou em 25 minutos! A frescura do peixe surpreendeu demais, parecia recém preparado 🫶',
      imagens: [
        'https://images.unsplash.com/photo-1563612116625-3012372fccce?w=600&q=80',
        'https://images.unsplash.com/photo-1580822184713-fc5400e7fe10?w=600&q=80',
      ],
      curtidas: 342,
      comentarios: 58,
      hashTags: ['#PokeBowl', '#DeliveryRápido', '#Saudável'],
      topComment: TopCommentModel(
        nomeUsuario: 'Usuário Inicial',
        conteudo: 'Poderia mandar o link da loja?',
        curtidas: 15,
      ),
      mentionedStore: MentionedStoreModel(
        nome: 'Poke do Chef',
        imageUrl: 'https://images.unsplash.com/photo-1548811579-017fb2a8f883?w=150&q=80',
        rating: 9.2,
        avaliacoes: '8.7 mil discussões',
      ),
    ),
    FeedPostModel(
      id: '2',
      nomeUsuario: 'Carlos M.',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      badge: 'Em alta',
      dispositivo: 'Android',
      conteudo:
          'Galera, alguém mais pediu pizza do "Forno de Minas" pelo Nhac? Chegou quentinha, queijo bem derretido 🍕🔥 Recomendo muito!\n\nPedido foi rápido e sem erro.',
      imagens: [
        'https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&q=80',
      ],
      curtidas: 890,
      comentarios: 134,
      hashTags: ['#Pizza', '#FornoDeMinas', '#Nhac'],
      topComment: TopCommentModel(
        nomeUsuario: 'Bia',
        conteudo: 'Amo! Peço todo final de semana.',
        curtidas: 125,
      ),
    ),
    FeedPostModel(
      id: '3',
      nomeUsuario: 'Bianca Souza',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      badge: 'Promoção',
      conteudo:
          'Consegui 30% de desconto no açaí com cobertura! O cupom "NHAC30" ainda tá funcionando 😍 Corre que é por tempo limitado!',
      imagens: [],
      curtidas: 1203,
      comentarios: 97,
      hashTags: ['#Desconto', '#Açaí', '#Cupom'],
      isPatrocinado: true,
      sponsorLabel: 'Oferta Especial',
    ),
    FeedPostModel(
      id: '4',
      nomeUsuario: 'Pedro H.',
      avatarUrl: 'https://i.pravatar.cc/150?img=68',
      badge: 'Recomendado para você',
      dispositivo: 'iPhone 14',
      conteudo:
          'Ontem pedi um combinado japonês pra jantar em casa com minha namorada. Chegou com tudo perfeito, nenhum rolinho aberto e super fresco. Nota 10! ✨🍣',
      imagens: [
        'https://images.unsplash.com/photo-1617196034183-421b4040ed20?w=600&q=80',
        'https://images.unsplash.com/photo-1559410545-0bdcd187e0a6?w=600&q=80',
      ],
      curtidas: 512,
      comentarios: 43,
      hashTags: ['#Japonês', '#Sushi', '#Jantar'],
      topComment: TopCommentModel(
        nomeUsuario: 'Lucas',
        conteudo: 'Parece incrível, qual o nome do restaurante?',
        curtidas: 32,
      ),
    ),
    FeedPostModel(
      id: '5',
      nomeUsuario: 'Mariana T.',
      avatarUrl: 'https://i.pravatar.cc/150?img=5',
      badge: 'Em alta',
      conteudo:
          'Tô apaixonada nessa granola com iogurte grego que pedi de manhã cedo! Chegou super gelada. Boa opção pra quem quer algo saudável sem abrir mão do sabor 💪',
      imagens: [
        'https://images.unsplash.com/photo-1517673400267-0251440c45dc?w=600&q=80',
      ],
      curtidas: 278,
      comentarios: 21,
      hashTags: ['#Saudável', '#Granola', '#BomDia'],
    ),
    FeedPostModel(
      id: '6',
      nomeUsuario: 'Rafael K.',
      avatarUrl: 'https://i.pravatar.cc/150?img=53',
      badge: 'Recomendado para você',
      conteudo:
          'Hambúrguer artesanal com cheddar e bacon. Paguei R\$28 e valeu cada centavo. Carne suculenta, pão brioche macio e chegou quente! 🍔',
      imagens: [
        'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&q=80',
        'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=600&q=80',
      ],
      curtidas: 734,
      comentarios: 88,
      hashTags: ['#Burger', '#Artesanal', '#FoodLover'],
      topComment: TopCommentModel(
        nomeUsuario: 'Malu',
        conteudo: 'Esse lugar é perfeito mesmo!',
        curtidas: 89,
      ),
    ),
  ];
}
