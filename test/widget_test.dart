import 'package:koadmap_plus/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders KoadMAP Plus shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CodeTreeViewerApp());

    expect(find.text('KoadMAP Plus'), findsOneWidget);
    expect(find.text('Ingest Folder'), findsOneWidget);
    expect(find.text('Select a folder and ingest it.'), findsOneWidget);
  });
}
