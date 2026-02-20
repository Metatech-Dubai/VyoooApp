/// A contact to share with; [app] is shown as small overlay on avatar (e.g. WhatsApp, SMS).
enum ShareApp { whatsapp, instagram, sms }

class ShareContact {
  const ShareContact({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.app,
  });

  final String id;
  final String name;
  final String avatarUrl;
  final ShareApp app;
}
