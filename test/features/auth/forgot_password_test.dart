import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rayuela_mobile/core/error/app_exception.dart';
import 'package:rayuela_mobile/core/error/result.dart';
import 'package:rayuela_mobile/core/router/routes.dart';
import 'package:rayuela_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:rayuela_mobile/features/auth/presentation/providers/auth_providers.dart';
import 'package:rayuela_mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:rayuela_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:rayuela_mobile/l10n/app_localizations.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

Widget _testApp({
  required Widget child,
  required AuthRepository authRepo,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'test-root',
        builder: (_, __) => child,
      ),
      GoRoute(
        path: AppPath.login,
        name: AppRoute.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppPath.forgotPassword,
        name: AppRoute.forgotPassword,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
    ],
    child: MaterialApp.router(
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

void main() {
  late _MockAuthRepository mockAuthRepo;

  setUp(() {
    mockAuthRepo = _MockAuthRepository();
  });

  group('LoginScreen -> ForgotPassword navigation', () {
    testWidgets('tapping forgot password navigates to ForgotPasswordScreen',
        (tester) async {
      when(() => mockAuthRepo.hasValidSession())
          .thenAnswer((_) async => false);

      await tester.pumpWidget(
        _testApp(
          child: const LoginScreen(),
          authRepo: mockAuthRepo,
        ),
      );
      await tester.pumpAndSettle();

      final forgotButton = find.text('¿Olvidaste tu contraseña?');
      expect(forgotButton, findsOneWidget);

      await tester.tap(forgotButton);
      await tester.pumpAndSettle();

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });
  });

  group('ForgotPasswordScreen', () {
    testWidgets('shows validation error when email is empty or invalid',
        (tester) async {
      await tester.pumpWidget(
        _testApp(
          child: const ForgotPasswordScreen(),
          authRepo: mockAuthRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Tap submit with empty email
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(find.text('El correo es obligatorio'), findsOneWidget);

      // Enter invalid email
      await tester.enterText(find.byType(TextFormField), 'not-an-email');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      expect(find.text('Ingresá un correo válido'), findsOneWidget);
    });

    testWidgets('shows success view on successful submission', (tester) async {
      when(() => mockAuthRepo.forgotPassword(any()))
          .thenAnswer((_) async => const Success(null));

      await tester.pumpWidget(
        _testApp(
          child: const ForgotPasswordScreen(),
          authRepo: mockAuthRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepo.forgotPassword('user@example.com')).called(1);

      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(
        find.text(
          'Si existe una cuenta con user@example.com, le enviamos un enlace para crear una nueva contraseña.',
        ),
        findsOneWidget,
      );
      expect(find.text('Volver al inicio de sesión'), findsOneWidget);
    });

    testWidgets('shows error banner when repository fails', (tester) async {
      when(() => mockAuthRepo.forgotPassword(any())).thenAnswer(
        (_) async => const Failure(
          NetworkException(message: 'No internet connection'),
        ),
      );

      await tester.pumpWidget(
        _testApp(
          child: const ForgotPasswordScreen(),
          authRepo: mockAuthRepo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'user@example.com');
      await tester.tap(find.text('Enviar enlace'));
      await tester.pumpAndSettle();

      verify(() => mockAuthRepo.forgotPassword('user@example.com')).called(1);

      expect(find.text('Sin conexión a internet.'), findsOneWidget);
    });
  });
}
