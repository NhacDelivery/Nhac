import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class E2EFinders {
  static Finder key(String value) => find.byKey(ValueKey<String>(value));

  static final welcomeContinue = key('e2e.welcome.continue');
  static final loginEmail = key('e2e.login.email');
  static final loginPassword = key('e2e.login.password');
  static final loginSubmit = key('e2e.login.submit');
  static final homeReady = key('e2e.home.ready');
  static final homeScrollTop = key('e2e.home.scroll-top');
  static final store = key('e2e.home.store.e2e-loja-001');
  static final product = key('e2e.store.product.e2e-produto-001');
  static final productAdd = key('e2e.product.add');
  static final cartOpen = key('e2e.cart.open');
  static final cartItem = key('e2e.cart.item.e2e-produto-001');
  static final cartItemQuantity = key(
    'e2e.cart.item.e2e-produto-001.quantity',
  );
  static final cartStoreId = key('e2e.cart.store-id');
  static final cartCheckout = key('e2e.cart.checkout');
  static final checkoutAddress = key('e2e.checkout.address');
  static final checkoutCash = key('e2e.checkout.payment.cash');
  static final checkoutConfirm = key('e2e.checkout.confirm');
  static final checkoutTotal = key('e2e.checkout.total');
  static final checkoutSuccess = key('e2e.checkout.success');
  static final checkoutSuccessOrderId = key('e2e.checkout.success.order-id');
  static final checkoutSuccessContinue = key('e2e.checkout.success.continue');
  static final trackingRoot = key('e2e.tracking.root');
  static final trackingOrderId = key('e2e.tracking.order-id');
  static final trackingStatus = key('e2e.tracking.status');
}
