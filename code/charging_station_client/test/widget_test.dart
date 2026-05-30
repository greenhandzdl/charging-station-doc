import 'package:flutter_test/flutter_test.dart';
import 'package:charging_station_client/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ChargingStationApp());
    expect(find.text('充电站管理系统'), findsOneWidget);
  });
}