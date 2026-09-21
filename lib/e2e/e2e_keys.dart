import 'package:flutter/widgets.dart';

abstract final class E2EKeys {
  static const welcomeContinue = Key('e2e.welcome.continue');
  static const loginEmail = Key('e2e.login.email');
  static const loginPassword = Key('e2e.login.password');
  static const loginSubmit = Key('e2e.login.submit');
  static const homeReady = Key('e2e.home.ready');
  static const productAdd = Key('e2e.product.add');
  static const cartOpen = Key('e2e.cart.open');
  static const cartCheckout = Key('e2e.cart.checkout');
  static const checkoutAddress = Key('e2e.checkout.address');
  static const checkoutCash = Key('e2e.checkout.payment.cash');
  static const checkoutConfirm = Key('e2e.checkout.confirm');
  static const checkoutSuccess = Key('e2e.checkout.success');
  static const checkoutSuccessOrderId = Key('e2e.checkout.success.order-id');
  static const checkoutSuccessContinue = Key('e2e.checkout.success.continue');
  static const trackingRoot = Key('e2e.tracking.root');
  static const trackingOrderId = Key('e2e.tracking.order-id');
  static const cartStoreId = Key('e2e.cart.store-id');
  static const checkoutTotal = Key('e2e.checkout.total');
  static const trackingStatus = Key('e2e.tracking.status');

  static Key homeStore(String storeId) => Key('e2e.home.store.$storeId');
  static Key storeProduct(String productId) =>
      Key('e2e.store.product.$productId');
  static Key cartItem(String productId) => Key('e2e.cart.item.$productId');
  static Key cartItemQuantity(String productId) =>
      Key('e2e.cart.item.$productId.quantity');
}
