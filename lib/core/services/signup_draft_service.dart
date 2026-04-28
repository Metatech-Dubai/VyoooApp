/// Temporary in-memory signup data kept between Create Account and OTP verify.
class SignupDraft {
  const SignupDraft({
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.channel,
  });

  final String name;
  final String email;
  final String phoneNumber;
  final String password;
  final String channel;
}

class SignupDraftService {
  SignupDraftService._();
  static final SignupDraftService _instance = SignupDraftService._();
  factory SignupDraftService() => _instance;

  SignupDraft? _current;

  SignupDraft? get current => _current;

  void save(SignupDraft draft) {
    _current = draft;
  }

  void clear() {
    _current = null;
  }
}
