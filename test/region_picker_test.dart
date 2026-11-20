import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mili_vpn/ui/region_picker.dart';

void main() {
  test('labels the automatic choice and a country', () {
    expect(exitRegionLabel(''), 'Fastest');
    expect(exitRegionLabel('DE'), '🇩🇪 Germany');
  });

  testWidgets('the location sheet returns the chosen country', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  picked = await showExitRegionPicker(context, selected: '');
                },
                child: const Text('pick location'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('pick location'));
    await tester.pumpAndSettle();
    expect(find.text('Choose location'), findsOneWidget);
    expect(find.text('Fastest (automatic)'), findsOneWidget);

    // Searching avoids depending on how many lazy list rows fit in the sheet.
    await tester.enterText(find.byType(TextField), 'Germany');
    await tester.pump();
    expect(find.text('Germany'), findsOneWidget);
    await tester.tap(find.text('Germany'));
    await tester.pumpAndSettle();
    expect(picked, 'DE');
  });
}
