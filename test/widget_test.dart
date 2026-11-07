import 'package:flutter_test/flutter_test.dart';
import 'package:jelajahku/main.dart';

void main() {
  testWidgets('JelajahKu menampilkan halaman utama', (tester) async {
    await tester.pumpWidget(const JelajahKuApp());

    await tester.pump();

    expect(find.text('JelajahKu'), findsOneWidget);
  });
}
