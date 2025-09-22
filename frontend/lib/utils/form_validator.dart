class FormValidator {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'メールアドレスを入力してください';
    }
    
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email)) {
      return '有効なメールアドレスを入力してください';
    }
    
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'パスワードを入力してください';
    }
    
    if (password.length < 8) {
      return 'パスワードは8文字以上で入力してください';
    }
    
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(password)) {
      return 'パスワードは大文字、小文字、数字を含む必要があります';
    }
    
    return null;
  }

  static String? validateName(String? name) {
    if (name == null || name.isEmpty) {
      return '名前を入力してください';
    }
    
    if (name.length < 2) {
      return '名前は2文字以上で入力してください';
    }
    
    if (name.length > 50) {
      return '名前は50文字以内で入力してください';
    }
    
    return null;
  }

  static String? validateConfirmPassword(String? password, String? confirmPassword) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'パスワード（確認）を入力してください';
    }
    
    if (password != confirmPassword) {
      return 'パスワードが一致しません';
    }
    
    return null;
  }
}