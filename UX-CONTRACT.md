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
