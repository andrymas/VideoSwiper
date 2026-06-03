import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:videoswiper/src/rust/frb_generated.dart';
import 'package:videoswiper/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async => await RustLib.init());
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const VideoSwiperApp());
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('VideoSwiper'), findsWidgets);
  });
}
