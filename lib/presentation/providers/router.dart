import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../screens/auth/login_screen.dart';
import '../screens/inbox/inbox_screen.dart';
import '../screens/detail/email_detail_screen.dart';
import '../screens/compose/compose_screen.dart';
import '../../core/constants/app_constants.dart';
import 'email_providers.dart';

// Makes GoRouter listen to Riverpod auth state changes
class _AuthNotifierListenable extends ChangeNotifier {
  _AuthNotifierListenable(this._ref) {
    _ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifierListenable(ref);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // While restoring session, stay put
      if (authState.isRestoringSession) return null;

      final onLogin = state.matchedLocation == AppRoutes.login;

      if (!authState.isLoggedIn && !onLogin) return AppRoutes.login;
      if (authState.isLoggedIn && onLogin) return AppRoutes.inbox;

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.inbox,
        pageBuilder: (context, state) => _fadePage(state, const InboxScreen()),
      ),
      GoRoute(
        path: '/email/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id']!;
          return _slideRightPage(state, EmailDetailScreen(emailId: id));
        },
      ),
      GoRoute(
        path: AppRoutes.compose,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return _slideUpPage(
            state,
            ComposeScreen(
              initialTo: extra?['replyTo'] as String?,
              initialSubject: extra?['subject'] as String?,
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF8A9CC2)),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    ),
  );
});

// ─── Page transition helpers ──────────────────────────────────────────────────

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

CustomTransitionPage<void> _slideRightPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}

CustomTransitionPage<void> _slideUpPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (_, animation, __, child) {
      final tween = Tween(
        begin: const Offset(0.0, 1.0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: animation.drive(tween), child: child);
    },
  );
}
