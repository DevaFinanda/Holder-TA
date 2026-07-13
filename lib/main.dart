import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';

import 'providers/auth_provider.dart';
import 'providers/app_settings_provider.dart';
import 'providers/wallet_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/issuance/issuance_flow_screen.dart';
import 'screens/presentation/presentation_consent_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const IDentiaApp());
}

class IDentiaApp extends StatefulWidget {
  const IDentiaApp({super.key});

  @override
  State<IDentiaApp> createState() => _IDentiaAppState();
}

class _IDentiaAppState extends State<IDentiaApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep session/account data intact across app close and reopen.
    if (state == AppLifecycleState.detached) {
      debugPrint('[Lifecycle] App detached');
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Handle cold-start deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri.toString());
    });

    // Handle warm deep links
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri.toString());
    }, onError: (e) {
      debugPrint('[DeepLink] Error: $e');
    });
  }

  void _handleDeepLink(String link) {
    debugPrint('[DeepLink] Received: $link');
    if (link.startsWith('openid-credential-offer://')) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => IssuanceFlowScreen(deepLink: link),
        ),
      );
    } else if (link.startsWith('openid4vp://') ||
        link.startsWith('haip://') ||
        link.startsWith('mdoc-openid4vp://')) {
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => PresentationConsentScreen(qrData: link),
        ),
      );
    }
    // 'identia://callback' is handled internally by OID4VCIService via AppLinks stream
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, WalletProvider>(
          create: (_) => WalletProvider(),
          update: (_, auth, wallet) {
            final provider = wallet ?? WalletProvider();
            provider.updateUserScope(auth.currentUser?.id);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
      ],
      child: Consumer<AppSettingsProvider>(
        builder: (context, settings, _) {
          final baseTextTheme = GoogleFonts.poppinsTextTheme().apply(
            bodyColor: settings.themeMode == 'dark'
                ? Colors.white
                : AppColors.textDark,
            displayColor: settings.themeMode == 'dark'
                ? Colors.white
                : AppColors.textDark,
          );

          final scaledTextTheme = baseTextTheme.copyWith(
            bodyMedium: baseTextTheme.bodyMedium?.copyWith(
              fontSize: (baseTextTheme.bodyMedium?.fontSize ?? 14) *
                  settings.fontScale,
            ),
            bodyLarge: baseTextTheme.bodyLarge?.copyWith(
              fontSize: (baseTextTheme.bodyLarge?.fontSize ?? 16) *
                  settings.fontScale,
            ),
            titleMedium: baseTextTheme.titleMedium?.copyWith(
              fontSize: (baseTextTheme.titleMedium?.fontSize ?? 16) *
                  settings.fontScale,
            ),
          );

          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: 'IDentia',
            debugShowCheckedModeBanner: false,
            locale: settings.localeValue,
            supportedLocales: const [
              Locale('id'),
              Locale('en'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: settings.themeModeValue,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryBlue,
                brightness: Brightness.light,
              ),
              textTheme: scaledTextTheme,
              useMaterial3: true,
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
                },
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: AppColors.textDark,
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
              outlinedButtonTheme: OutlinedButtonThemeData(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(
                      color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primaryBlue, width: 2),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: AppColors.primaryBlue,
                brightness: Brightness.dark,
              ),
              textTheme: scaledTextTheme,
              useMaterial3: true,
            ),
            builder: (context, child) {
              final media = MediaQuery.of(context);
              final highContrast = settings.highContrast;
              return MediaQuery(
                data: media.copyWith(
                  textScaler: TextScaler.linear(settings.fontScale),
                  highContrast: highContrast,
                ),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
