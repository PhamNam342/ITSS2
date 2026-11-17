import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/auth.dart';
import 'core/format.dart';
import 'core/router.dart';
import 'core/store.dart';
import 'core/theme.dart';

final messenger = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  usePathUrlStrategy(); // URL sạch: /community/post/123 thay vì /#/community/post/123
  await auth.load(); // biết đã đăng nhập chưa trước khi vẽ màn hình đầu

  void sync() => auth.user == null ? store.stop() : store.start();
  auth.addListener(sync);
  sync();

  // Snackbar nhẹ khi có giao dịch mới (spec 11.2)
  store.created.listen((tx) {
    final left = (store.summary?['remaining_month'] ?? 0) as num;
    final tail = store.summary?['budget_total'] == 0
        ? ''
        : left >= 0
            ? ' · Tháng này còn ${vnd(left)}'
            : ' · Tháng này hơi vượt dự kiến';
    messenger.currentState?.showSnackBar(SnackBar(
      content: Text('Đã ghi ${vnd(tx['amount'])} vào ${store.categoryName(tx['category_id'])}$tail'),
      action: SnackBarAction(label: 'Xem', onPressed: () => router.go('/transactions')),
    ));
  });

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'AnTâm Wallet',
        theme: appTheme,
        routerConfig: router,
        scaffoldMessengerKey: messenger,
        // Desktop / máy chiếu: giữ khổ điện thoại, căn giữa (spec 12)
        builder: (context, child) => ColoredBox(
          color: background,
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
          ),
        ),
      );
}
