# Notificações de pedidos no Nhac

## Fluxo

1. O app pede permissão e obtém o token FCM do dispositivo.
2. Após o login, registra o token em `PUT /api/v1/usuarios/{id}/push-token` com o JWT do cliente. Na renovação do token, atualiza o registro. No logout, remove o registro e invalida o token local.
3. O backend publica um evento quando o pedido muda de status. Depois do commit, envia uma mensagem FCM aos dispositivos do dono do pedido com `pedidoId` e `status` no campo `data`.
4. Em primeiro plano, o app exibe uma notificação local. Em segundo plano ou fechado, o sistema exibe a notificação FCM. O toque abre `/rastreio?pedidoId=...`.

## Configuração necessária

- Backend: configure `FIREBASE_CREDENTIALS_BASE64` com a service account do **mesmo projeto Firebase do app** e `FIREBASE_STORAGE_BUCKET` para uploads. Ative a Firebase Cloud Messaging API (HTTP v1) e conceda à conta permissão de envio. Não versione a chave.
- Android: confirme que o `google-services.json` do ambiente corresponde ao application ID instalado. Android 13+ solicitará permissão de notificações.
- iOS: no Xcode, habilite Push Notifications e Background Modes (Background fetch e Remote notifications); envie a chave APNs do Apple Developer ao projeto Firebase. A chave APNs e o provisionamento dependem da conta Apple e não ficam no repositório.
- Testes automatizados usam o modo mock do Storage e não enviam push real.

## Verificação em dispositivo real

1. Faça login, conceda permissão e confirme que `PUT /push-token` responde 204.
2. Crie um pedido e mude seu status para `PREPARANDO` pelo lojista.
3. Teste com o app aberto, em segundo plano e fechado. Toque na notificação e confirme que abre o pedido certo.
4. Faça logout e confirme que `DELETE /push-token` responde 204; o dispositivo não deve continuar recebendo avisos daquele cliente.

O WebSocket existente continua atualizando a tela de rastreio enquanto ela está aberta. O FCM cuida dos avisos fora dessa tela; a API de pedidos permanece a fonte de verdade para o status.
