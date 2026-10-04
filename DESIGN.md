---
version: alpha
name: Nhac
description: Aplicativo de delivery com identidade coral e interfaces móveis em português.
colors:
  primary: "#FF6961"
  surface: "#FFE7E5"
  feed-text: "#5D201C"
  feed-background: "#FFFFFF"
typography:
  sans:
    fontFamily: "Roboto, sans-serif"
omitted:
  - section: rounded
    reason: "Geometria adaptativa definida pelos componentes Flutter existentes."
  - section: spacing
    reason: "Dimensões adaptadas por flutter_screenutil nos componentes existentes."
components:
  notification: {}
  button: {}
---

# Nhac Design System

## Overview

O app aproxima a experiência de um cardápio de bairro: coral, imagens de comida e
formas arredondadas. É um produto de delivery para uso móvel; o feed permite ler
publicações reais e interagir. A linguagem atual é português brasileiro.
A assinatura é o coral Nhac, preservado nesta integração. Evitar um visual de
painel corporativo ou uma reformulação da identidade para esta feature.

Este documento espelha o código existente: `lib/globals/themes.dart` é a fonte
canônica da paleta e da fonte. `lib/pages/feed_page.dart` e
`lib/pages/feed_post_detail_page.dart` mantêm os estilos específicos do feed.
A publicação usa Material e a paleta de `lightTheme`, com fotos em miniaturas
arredondadas e formulário rolável para manter campos e ações acessíveis no celular.
Não há geração de tokens. Mudanças futuras devem reconciliar documento e código.

## Colors

Coral identifica ações e seleção. Superfície rosa apoia a marca; fundo branco e
texto marrom são os valores existentes do feed. Não foram alterados nesta integração.

## Typography

Roboto vem do tema atual. Pesos e tamanhos usam as definições existentes das telas
e a adaptação de `flutter_screenutil`. Mensagens de recuperação precisam ser legíveis.

## Layout

Preservar SafeArea, listas com slivers e a barra inferior dos detalhes. Paginação
é explícita, com “Carregar mais”. O campo de comentário deve continuar alcançável
com o teclado aberto; verificação em dispositivo ainda necessária.

## Elevation & Depth

Os cards e barras existentes usam bordas, superfícies e sombras discretas.
Esta feature não estabelece novos níveis de elevação.

## Shapes

Preservar os raios existentes dos cards, imagens e botões; não aplicar uma escala
nova em telas isoladas.

## Components

Ações e formulários usam Material. Erros de operações usam
`ErrorUIHelper` → `AppUiUtils` → `showAppNotification`.
Listas têm estados de carregamento, vazio, falha e nova tentativa.
Skeletons existentes continuam na listagem; detalhes usam indicador Material.
Ícones seguem Material e ações interativas recebem nome acessível.
A integração não altera animações existentes nem adiciona movimento decorativo.

## Do's and Don'ts

- Preservar tema e navegação das telas existentes.
- Mostrar contagens vindas da API e preservar comentário quando o envio falhar.
- Ignorar respostas antigas ao trocar categoria.
- Não preencher estado vazio ou erro com posts, comentários ou números fictícios.
