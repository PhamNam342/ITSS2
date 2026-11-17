import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_page.dart';
import '../features/auth/login_page.dart';
import '../features/community/community_page.dart';
import '../features/community/new_post_page.dart';
import '../features/community/post_page.dart';
import '../features/dashboard/home_page.dart';
import '../features/demo/demo_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../features/quick_check/quick_check_page.dart';
import '../features/settings/settings_page.dart';
import '../features/transactions/transactions_page.dart';
import 'auth.dart';

final router = GoRouter(
  refreshListenable: auth,
  redirect: (context, state) {
    final atLogin = state.matchedLocation == '/login';
    if (auth.user == null) return atLogin ? null : '/login';
    return atLogin ? '/' : null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomePage(),
      // Route con: mở thẳng /transactions vẫn có nút quay về Dashboard
      routes: [
        GoRoute(path: 'onboarding', builder: (context, state) => const OnboardingPage()),
        GoRoute(path: 'transactions', builder: (context, state) => const TransactionsPage()),
        GoRoute(path: 'settings', builder: (context, state) => const SettingsPage()),
        GoRoute(path: 'demo', builder: (context, state) => const DemoPage()),
        GoRoute(path: 'quick-check', builder: (context, state) => const QuickCheckPage()),
        GoRoute(
          path: 'community',
          builder: (context, state) => CommunityPage(
            key: ValueKey(state.uri.query), // đổi bộ lọc qua URL → dựng lại danh sách
            difficulty: state.uri.queryParameters['difficulty_type'],
            amount: state.uri.queryParameters['amount_range'],
          ),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) => NewPostPage(difficulty: state.uri.queryParameters['difficulty_type']),
            ),
            GoRoute(path: 'post/:id', builder: (context, state) => PostPage(id: state.pathParameters['id']!)),
          ],
        ),
        GoRoute(path: 'admin', builder: (context, state) => const AdminPage()),
      ],
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  ],
);
