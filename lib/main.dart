// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/foundation.dart';
import 'package:nhac/repositories/loja_repository.dart';
import 'package:nhac/repositories/produto_repository.dart';
import 'package:nhac/repositories/pedido_repository.dart';
import 'package:nhac/models/pedido/status_pedido.dart';
import 'package:nhac/pages/no_internet_page.dart';
import 'package:nhac/controllers/cadastro_controller.dart';
import 'package:nhac/controllers/cart_provider.dart';
import 'package:nhac/controllers/endereco_provider.dart';
import 'package:nhac/controllers/user_provider.dart';
import 'package:nhac/services/auth_service.dart';
import 'package:nhac/services/connectivity_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:flutter/material.dart';
import 'package:nhac/globals/app_state.dart';
import 'package:nhac/globals/app_constants.dart';
import 'package:nhac/globals/router.dart';
import 'package:firebase_core/firebase_core.dart';

import './firebase_options.dart';

import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nhac/services/push_notification_service.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:nhac/e2e/e2e_bootstrap.dart';

import 'package:nhac/services/live_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Notificação em background recebida!");

  if (message.data.containsKey('pedidoId') &&
      message.data.containsKey('status')) {
    final status = StatusPedido.fromApi(message.data['status']?.toString());
    final nomeProduto = message.data['nomeProduto']?.toString() ?? 'Seu pedido';
    final stageIndex = status.stage;

    LiveNotificationService.updateLiveNotification(
      pedidoId: message.data['pedidoId'].toString(),
      nomeProduto: nomeProduto,
      status: message.data['statusTexto'] ?? status.label,
      tempoEstimado: message.data['tempoEstimado'] ?? '',
      progresso: stageIndex,
    );
  }
}

@NowaGenerated()
late final SharedPreferences sharedPrefs;

@NowaGenerated()
main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConstants.e2eMode) {
    await E2EBootstrap.prepare();
    sharedPrefs = await SharedPreferences.getInstance();
    E2EBootstrap.runIsolated(const MyApp());
    return;
  }

  final sentryDsn = AppConstants.sentryDsn;

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for tracing.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
      // The sampling rate for profiling is relative to tracesSampleRate
      // Setting to 1.0 will profile 100% of sampled transactions:
      //options.profilesSampleRate = 1.0;
    },
    appRunner: () async {
      try {
        final stripeKey = AppConstants.stripePublishableKey;
        if (stripeKey.isNotEmpty) {
          Stripe.publishableKey = stripeKey;
          await Stripe.instance.applySettings();
        }

        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        if (!AppConstants.e2eMode) {
          await FirebaseAppCheck.instance.activate(
            // ignore: deprecated_member_use
            androidProvider: kDebugMode
                ? AndroidProvider.debug
                : AndroidProvider.playIntegrity,
          );

          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );

          final pushService = PushNotificationService(authServiceRoteador);
          await pushService.initialize();
        }

        sharedPrefs = await SharedPreferences.getInstance();

        runApp(SentryWidget(child: const MyApp()));
      } catch (e, s) {
        // Se qualquer inicialização crítica falhar, reporta pro Sentry
        // (agora já ativo) e mostra uma tela de erro em vez de deixar a
        // splash branca travada pra sempre.
        await Sentry.captureException(e, stackTrace: s);
        debugPrint('Falha ao inicializar o app: $e\n$s');
        runApp(_StartupErrorApp(error: e));
      }
    },
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Não foi possível iniciar o app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@NowaGenerated({'visibleInNowa': false})
class MyApp extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>(create: (context) => AppState()),
        ChangeNotifierProvider<AuthService>.value(value: authServiceRoteador),
        ChangeNotifierProvider<CadastroController>(
          create: (context) => CadastroController(authService: authServiceRoteador),
        ),
        ChangeNotifierProvider<UserProvider>(
          create: (context) => UserProvider(),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider(authService: authServiceRoteador)),
        ChangeNotifierProvider(create: (_) => EnderecoProvider()),
        ChangeNotifierProvider<ConnectivityService>(
          create: (context) => ConnectivityService(),
        ),
        Provider<LojaRepository>(create: (_) => LojaRepository()),
        Provider<ProdutoRepository>(create: (_) => ProdutoRepository()),
        Provider<PedidoRepository>(create: (_) => PedidoRepository()),
      ],
      builder: (context, child) {
        return Consumer<ConnectivityService>(
          builder: (context, connectivity, child) {
            return ScreenUtilInit(
              designSize: const Size(390, 844),
              minTextAdapt: true,
              splitScreenMode: true,
              builder: (context, child) {
                return MaterialApp.router(
                  showSemanticsDebugger: false,
                  debugShowCheckedModeBanner: false,
                  theme: AppState.of(context).theme,
                  routerConfig: appRouter,
                  builder: (context, navigator) {
                    if (!connectivity.isOnline) {
                      return const NoInternetPage();
                    }
                    return navigator!;
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
