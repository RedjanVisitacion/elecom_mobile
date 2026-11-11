import 'package:flutter/material.dart';

/// Same centered cover crop for bundled and administrator-uploaded headers.
class HomeHeaderBackground extends StatelessWidget {
  const HomeHeaderBackground({super.key, this.imageUrl});
  final String? imageUrl;

  static String? trustedUrl(String? value) {
    final url = Uri.tryParse(value ?? '');
    return url?.scheme == 'https' && url?.host == 'res.cloudinary.com'
        ? url.toString()
        : null;
  }

  Widget _fallback() => Image.asset(
    'assets/USTP PICS/USTP_FRONT.png',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) =>
        const ColoredBox(color: Color(0xFF0C1E70)),
  );

  @override
  Widget build(BuildContext context) {
    final url = trustedUrl(imageUrl);
    return SizedBox(
      width: double.infinity,
      height: 170,
      child: url == null
          ? _fallback()
          : Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _fallback(),
              errorBuilder: (context, error, stackTrace) => _fallback(),
            ),
    );
  }
}
