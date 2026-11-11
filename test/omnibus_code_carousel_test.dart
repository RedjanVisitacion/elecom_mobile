import 'package:flutter_test/flutter_test.dart';
import 'package:elecom_mobile/features/elecom/student_dashboard/widgets/omnibus_code_carousel.dart';

void main() {
  test('original pages remain available before server configuration', () {
    expect(omnibusPagePaths(null), hasLength(14));
    expect(omnibusPagePaths([]).first, 'assets/omnibus/page01.jpg');
  });
  test('custom image order and default pages are preserved', () {
    expect(
      omnibusPagePaths([
        {'image_url': 'https://res.cloudinary.com/demo/image/upload/page.jpg'},
        {'default_index': 3},
      ]),
      [
        'https://res.cloudinary.com/demo/image/upload/page.jpg',
        'assets/omnibus/page04.jpg',
      ],
    );
  });
  test('untrusted URLs are rejected without losing bundled defaults', () {
    expect(
      omnibusPagePaths([
        {'image_url': 'https://example.com/page.jpg', 'default_index': 1},
        {'image_url': 'http://res.cloudinary.com/page.jpg'},
      ]),
      ['assets/omnibus/page02.jpg'],
    );
    expect(
      omnibusPagePaths([
        {'default_index': 99},
      ]),
      hasLength(14),
    );
  });
}
