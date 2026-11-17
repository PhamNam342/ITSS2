import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'core/auth.dart';
import 'core/router.dart';
import 'core/theme.dart';

Future<void> main() async {
  usePathUrlStrategy(); // URL sạch: /community/post/123 thay vì /#/community/post/123
  await auth.load(); // biết đã đăng nhập chưa trước khi vẽ màn hình đầu
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'AnTâm Wallet',
        theme: appTheme,
        routerConfig: router,
        // Desktop / máy chiếu: giữ khổ điện thoại, căn giữa (spec 12)
        builder: (context, child) => ColoredBox(
          color: background,
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: child),
          ),
        ),
      );
}
