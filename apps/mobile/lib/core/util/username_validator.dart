class UsernameValidator {
  UsernameValidator._();

  static String? validate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    return null;
  }
}
