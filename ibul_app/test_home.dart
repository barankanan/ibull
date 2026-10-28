import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ibul_app/screens/home/home_initial_page.dart';

void main() {
  testWidgets('HomeInitialPage first frame 390', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeInitialPage(),
      ),
    );
    
    debugPrint('Rendered widget tree:');
    debugPrint(tester.element(find.byType(HomeInitialPage)).toStringDeep());
    
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
