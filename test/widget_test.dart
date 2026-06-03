import 'package:flutter_test/flutter_test.dart';
import 'package:videoswiper/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const VideoSwiperApp());
    expect(find.text('VideoSwiper'), findsWidgets);
  });
}
