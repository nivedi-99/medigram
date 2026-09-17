import 'package:flutter/material.dart';

import '../services/app_launcher.dart';

/// Floating WhatsApp inquiry button (bottom-right on the landing page).
///
/// Opens a pre-filled chat with the MediGram sales number via wa.me:
/// - Web: opens in a new tab (hands off to WhatsApp Web / the installed app).
/// - Non-web: the app_launcher stub reports failure and we show the number.
class WhatsAppChatButton extends StatelessWidget {
  /// Sales number in international format (no '+', no leading zeros) —
  /// required by wa.me deep links.
  static const String _whatsappNumber = '919588423570';

  /// Pre-filled first message in the chat.
  static const String _prefilledMessage =
      'Hello MediGram! I would like to make an inquiry / request a '
      'quotation for your pharmaceutical products.';

  const WhatsAppChatButton({super.key});

  /// Builds a wa.me deep link with an arbitrary pre-filled [message].
  static String deepLink(String message) =>
      'https://wa.me/$_whatsappNumber?text=${Uri.encodeComponent(message)}';

  /// wa.me deep link with the URL-encoded inquiry text.
  static String get chatUrl => deepLink(_prefilledMessage);

  Future<void> _openChat(BuildContext context) async {
    final opened = await openExternalUrl(chatUrl);
    if (opened || !context.mounted) return;
    // Non-web fallback: at least surface the number.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chat with us on WhatsApp: +91 95884 23570'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'whatsapp_chat_fab',
      tooltip: 'Chat with us on WhatsApp',
      backgroundColor: const Color(0xFF25D366), // WhatsApp green
      onPressed: () => _openChat(context),
      child: const CustomPaint(
        size: Size.square(30),
        painter: _WhatsAppGlyphPainter(),
      ),
    );
  }
}

/// Hand-drawn WhatsApp-style glyph (no extra packages): a white speech
/// bubble with a lower-left tail and a green handset — a thick arc with
/// round ear/mouth pieces. Painted in a 100x100 space, scaled to the button.
class _WhatsAppGlyphPainter extends CustomPainter {
  const _WhatsAppGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final white = Paint()..color = Colors.white;
    final green = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    // Speech bubble: circle + pointed tail merged into one path.
    final bubble = Path.combine(
      PathOperation.union,
      Path()
        ..addOval(Rect.fromCircle(
            center: const Offset(50, 47), radius: 37)),
      Path()
        ..moveTo(15, 84)
        ..lineTo(27, 69)
        ..lineTo(39, 79)
        ..close(),
    );
    canvas.drawPath(bubble, white);

    // Handset: arc from the bottom-right end, through bottom/left, to the
    // top-left end — the classic receiver silhouette, plus round end dots.
    const center = Offset(50, 47);
    const radius = 16.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0.785, // start at the bottom-right end (45deg)
      3.142, // sweep through bottom and left to the top-left end
      false,
      green,
    );
    green.style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(61.3, 58.3), 6.5, green); // mouthpiece
    canvas.drawCircle(const Offset(38.7, 35.7), 6.5, green); // earpiece
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
