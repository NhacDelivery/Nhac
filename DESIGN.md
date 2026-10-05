---
version: alpha
name: Nhac
description: Aplicativo de delivery com identidade coral e interfaces móveis em português.
colors:
  primary: "#FF6961"
  background: "#FFE7E5"
  text: "#5D201C"
  surface: "#FFFFFF"
typography:
  body:
    fontFamily: "Roboto, sans-serif"
omitted:
  - section: spacing
    reason: "Existing Flutter screens use ScreenUtil values directly; no shared spacing token owner yet."
  - section: rounded
    reason: "Existing Flutter components define their own radii."
  - section: components
    reason: "Shared Flutter widgets remain the runtime owner."
---

## Overview

Nhac is a Brazilian food delivery app used while choosing, ordering, and following a meal. The food and the actual order status are the signature; avoid decorative dashboards or promises the backend cannot confirm. Existing Flutter widgets and `lib/globals/themes.dart` remain the runtime source of truth. This file records their accepted visual identity without changing it.

## Colors

Coral `#FF6961` identifies actions and active states; pale pink `#FFE7E5` is the app background; brown `#5D201C` carries readable headings; white contains cards and forms. Error and warning copy must state the condition in text.

## Typography

Roboto is the existing app family. Use clear hierarchy and keep long addresses, payment status, and route errors readable on narrow phones.

## Layout

Mobile first. The bottom navigation exposes only implemented destinations. Checkout keeps the amount and confirmation state together; tracking reserves space for map failure and retry.

## Elevation & Depth

Existing cards and sheets own their shadows. Do not introduce a new elevation scale during workflow fixes.

## Shapes

Retain the rounded cards, chips, and sheets already used throughout the app.

## Components

The store keeps loaded cards in place while fetching another page; the load-more control lives in the list footer. Tracking publishes order details before waiting for route geometry. Use existing shared buttons, loading indicator, product cards, and `context.showError`/`showSuccess` feedback. The map, Pix state, and chat preserve user input during network delays.

## Do's and Don'ts

Show confirmed freight as confirmed; label an estimate and block finalization until it is confirmed. Show promotions only when a real product discount exists. Do not show inert navigation or placeholder commerce actions.

## Feed integrado


Preservar SafeArea, listas com slivers e a barra inferior dos detalhes. Paginação
é explícita, com “Carregar mais”. O campo de comentário deve continuar alcançável
com o teclado aberto; verificação em dispositivo ainda necessária.


Publicações, comentários e contagens vêm da API. Não preencher falhas com conteúdo fictício.
