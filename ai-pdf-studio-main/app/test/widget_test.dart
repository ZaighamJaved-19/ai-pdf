import 'package:ai_pdf_studio/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the AI PDF Studio shell', (tester) async {
    await tester.pumpWidget(const AiPdfApp());

    expect(find.text('AI PDF Studio'), findsOneWidget);
    expect(find.text('AI Assistant'), findsWidgets);
  });
}
