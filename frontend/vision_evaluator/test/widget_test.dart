import 'package:flutter_test/flutter_test.dart';
import 'package:vision_evaluator/main.dart';

void main() {
  testWidgets('shows the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const VisionEvaluatorApp());

    expect(find.text('Vision\nEvaluator'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
  });
}
