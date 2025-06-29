class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty || value == '60') {
      return 'Phone number is required';
    }

    // Must start with 60 and 1 after
    final phoneRegex = RegExp(r'^601\d{7,9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Invalid phone number';
    }

    final prefix = value.substring(2, 5);

    if ((prefix == '011' || prefix == '015') && value.length != 12) {
      return 'Invalid phone number';
    }

    if (!(prefix == '011' || prefix == '015') && value.length != 11) {
      return 'Invalid phone number';
    }

    return null;
  }

  static bool isValidPhoneNumber(String value) {
    // Basic international phone number validation
    // Allows + followed by country code and number
    final phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(value.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateDateOfBirth(DateTime? value) {
    if (value == null) {
      return 'Date of birth is required';
    }
    final now = DateTime.now();
    final age = now.year - value.year;
    if (age < 18) {
      return 'You must be at least 18 years old';
    }
    return null;
  }
} 