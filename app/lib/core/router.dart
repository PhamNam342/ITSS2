import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/dashboard/home_page.dart';
import 'auth.dart';

final router = GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    final atLogin = state.matchedLocation == '/login';
    if (auth.user == null) return atLogin ? null : '/login';
    return atLogin ? '/' : null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomePage()),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  ],
);
