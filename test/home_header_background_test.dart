import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elecom_mobile/features/elecom/student_dashboard/widgets/home_header_background.dart';

void main() {
  test('accepts only HTTPS Cloudinary backgrounds', () {
    expect(
      HomeHeaderBackground.trustedUrl(
        'https://res.cloudinary.com/demo/header.jpg',
      ),
      isNotNull,
    );
    expect(
      HomeHeaderBackground.trustedUrl('http://res.cloudinary.com/header.jpg'),
      isNull,
    );
    expect(
      HomeHeaderBackground.trustedUrl('https://example.com/header.jpg'),
      isNull,
    );
  });
  testWidgets('default header preserves height and cover crop', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HomeHeaderBackground())),
    );
    expect(tester.getSize(find.byType(HomeHeaderBackground)).height, 170);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
  });
}
