import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ride/screens/home/vehicle_select_screen.dart';

void main() {
  testWidgets(
    'Vehicle list includes six real-image choices and no proceed button',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VehicleSelectScreen()));
      expect(find.text('Motorcycle'), findsOneWidget);
      expect(find.text('Tuk Tuk'), findsOneWidget);
      expect(find.text('Car'), findsOneWidget);
      expect(find.text('Bicycle'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Van'), 200);
      expect(find.text('Van'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Bus'), 200);
      expect(find.text('Bus'), findsOneWidget);
      expect(find.byType(Image), findsWidgets);
      expect(find.text('Continue to Where To'), findsNothing);
    },
  );

  testWidgets('Selecting a vehicle reports it without navigating', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: VehicleSelectScreen(onSelected: (value) => selected = value),
      ),
    );
    await tester.tap(find.text('Motorcycle'));
    await tester.pump();
    expect(selected, 'motorcycle');
    expect(find.byType(VehicleSelectScreen), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });
}
