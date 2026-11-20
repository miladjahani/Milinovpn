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

    await tester.scrollUntilVisible(find.text('Germany'), 200);
    await tester.tap(find.text('Germany'));
    await tester.pumpAndSettle();
    expect(picked, 'DE');
  });
}
