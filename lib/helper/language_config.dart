class AppLanguage {
  final String code;
  final String name;
  final String native;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.native,
  });

  static const List<AppLanguage> supported = [
    AppLanguage(code: 'en', name: 'English', native: 'English'),
    AppLanguage(code: 'hi', name: 'Hindi', native: 'हिन्दी'),
    AppLanguage(code: 'ta', name: 'Tamil', native: 'தமிழ்'),
    AppLanguage(code: 'te', name: 'Telugu', native: 'తెలుగు'),
    AppLanguage(code: 'mr', name: 'Marathi', native: 'मराठी'),
    AppLanguage(code: 'gu', name: 'Gujarati', native: 'ગુજરાતી'),
    AppLanguage(code: 'bn', name: 'Bengali', native: 'বাংলা'),
    AppLanguage(code: 'kn', name: 'Kannada', native: 'ಕನ್ನಡ'),
    AppLanguage(code: 'ml', name: 'Malayalam', native: 'മലയാളം'),
    AppLanguage(code: 'pa', name: 'Punjabi', native: 'ਪੰਜਾਬੀ'),
  ];

  static AppLanguage fromCode(String code) =>
      supported.firstWhere((l) => l.code == code,
          orElse: () => supported.first);
}
