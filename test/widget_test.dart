import 'package:auto_swiper/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the swipe control screen', (tester) async {
    await tester.pumpWidget(const AutoSwiperApp());

    expect(find.text('随机滑屏'), findsWidgets);
    expect(find.text('v0.0.2'), findsWidgets);
    expect(find.text('运行'), findsWidgets);
    expect(find.text('启动'), findsWidgets);
    expect(find.text('启动后去向'), findsOneWidget);
    expect(find.text('设置'), findsWidgets);

    await tester.scrollUntilVisible(find.text('运行辅助'), 400);
    expect(find.text('运行辅助'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('动作'), 400);
    expect(find.text('动作'), findsOneWidget);
  });
}
