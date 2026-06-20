enum AppLanguage {
  english('en', 'English', 'English'),
  bangla('bn', 'Bangla', 'বাংলা');

  const AppLanguage(this.code, this.labelEn, this.labelBn);
  final String code;
  final String labelEn;
  final String labelBn;

  bool get isBangla => this == AppLanguage.bangla;

  static AppLanguage fromCode(String? code) {
    return code == 'bn' ? AppLanguage.bangla : AppLanguage.english;
  }
}

class AppText {
  const AppText(this.language);
  final AppLanguage language;

  String call(String english, String bangla) => language.isBangla ? bangla : english;
}
