import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController(text: '60');
  
  DateTime? _dateOfBirth;
  String? _selectedGender;
  String? _selectedRace;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _races = ['Chinese', 'Malay', 'Indian', 'Other'];

  bool _fullNameError = false;
  bool _dobError = false;
  bool _genderError = false;
  bool _raceError = false;
  bool _emailError = false;
  bool _passwordError = false;
  bool _confirmPasswordError = false;
  bool _phoneError = false;
  bool _emailRegisteredError = false;
  bool _phoneRegisteredError = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
      firstDate: DateTime.now().subtract(const Duration(days: 36500)), // 100 years ago
      lastDate: DateTime.now().subtract(const Duration(days: 6570)), // 18 years ago
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  Future<void> _handleRegister() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    setState(() {
      _fullNameError = Validators.validateRequired(_fullNameController.text, 'Full name') != null;
      _dobError = _dateOfBirth == null;
      _genderError = _selectedGender == null;
      _raceError = _selectedRace == null;
      _phoneError = Validators.validatePhone(_phoneController.text) != null;
      _emailError = Validators.validateEmail(_emailController.text) != null;
      _passwordError = Validators.validatePassword(_passwordController.text) != null;
      _confirmPasswordError = Validators.validateConfirmPassword(_confirmPasswordController.text, _passwordController.text) != null;
      _emailRegisteredError = false;
      _phoneRegisteredError = false;
    });
    if (!isValid) return;
    if (!(_fullNameError || _dobError || _genderError || _raceError || _passwordError || _confirmPasswordError || _phoneError || _emailError || _phoneRegisteredError)) {
      // Check if phone number already exists
      try {
        final phoneExists = await context.read<AuthProvider>().isPhoneNumberExists(_phoneController.text);
        if (phoneExists) {
          setState(() {
            _phoneRegisteredError = true;
          });
          return;
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking phone number: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // proceed with registration
      try {
        await context.read<AuthProvider>().register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _fullNameController.text,
          phone: _phoneController.text,
          dateOfBirth: _dateOfBirth!,
          gender: _selectedGender!,
          race: _selectedRace!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please login.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          setState(() {
            _emailRegisteredError = true;
          });
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.message ?? e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6BC1D1), // Top
              Color(0xFF9CE09D), // Bottom
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                    Center(
                      child: ClipOval(
                        child: Image.asset(
                          'assets/poolpal-logo.png',
                          height: 120,
                          width: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Text(
                      'PoolPal',
                      style: GoogleFonts.pacifico(
                        fontSize: 32,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black12,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                // Full Name
                TextFormField(
                  controller: _fullNameController,
                  onChanged: (_) {
                    if (_fullNameError) setState(() => _fullNameError = false);
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.fullName,
                    prefixIcon: const Icon(Icons.person),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: _fullNameError ? Validators.validateRequired(_fullNameController.text, 'Full name') : null,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),

                // Date of Birth
                    TextFormField(
                      readOnly: true,
                      controller: TextEditingController(text: _dateOfBirth == null ? '' : DateFormat('dd/MM/yyyy').format(_dateOfBirth!)),
                      onTap: () {
                        if (_dobError) setState(() => _dobError = false);
                        _selectDate(context);
                      },
                      decoration: InputDecoration(
                      labelText: AppStrings.dateOfBirth,
                        prefixIcon: const Icon(Icons.calendar_today),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        floatingLabelStyle: const TextStyle(color: Colors.black),
                        errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        errorText: _dobError ? 'Date of birth is required' : null,
                    ),
                  ),
                const SizedBox(height: 16),

                // Gender
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                      decoration: InputDecoration(
                    labelText: AppStrings.gender,
                        prefixIcon: const Icon(Icons.people),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        floatingLabelStyle: const TextStyle(color: Colors.black),
                        errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        errorText: _genderError ? 'Please select your gender' : null,
                  ),
                  items: _genders.map((String gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                          _selectedGender = value;
                          if (_genderError) _genderError = false;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Race
                DropdownButtonFormField<String>(
                  value: _selectedRace,
                      decoration: InputDecoration(
                    labelText: AppStrings.race,
                        prefixIcon: const Icon(Icons.diversity_3),
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF65B36A)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red, width: 2),
                        ),
                        labelStyle: const TextStyle(color: Colors.black),
                        floatingLabelStyle: const TextStyle(color: Colors.black),
                        errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        errorText: _raceError ? 'Please select your race' : null,
                  ),
                  items: _races.map((String race) {
                    return DropdownMenuItem(
                      value: race,
                      child: Text(race),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() {
                          _selectedRace = value;
                          if (_raceError) _raceError = false;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  onChanged: (value) {
                    if (_phoneError || _phoneRegisteredError) setState(() {
                      _phoneError = false;
                      _phoneRegisteredError = false;
                    });
                    // Prevent deleting the '60' prefix
                    if (!value.startsWith('60')) {
                      final cursorPos = _phoneController.selection;
                      _phoneController.text = '60';
                      _phoneController.selection = TextSelection.fromPosition(
                        TextPosition(offset: 2),
                      );
                    }
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.phone,
                    prefixIcon: const Icon(Icons.phone),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: _phoneRegisteredError
                      ? 'Phone number is already registered'
                      : (_phoneError ? Validators.validatePhone(_phoneController.text) : null),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 4),
                Text(
                  '(This is your registered phone number and cannot be changed)',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),

                // Email
                TextFormField(
                  controller: _emailController,
                  onChanged: (_) {
                    if (_emailError || _emailRegisteredError) setState(() {
                      _emailError = false;
                      _emailRegisteredError = false;
                    });
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.email,
                    prefixIcon: const Icon(Icons.email),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: _emailRegisteredError
                      ? 'Email is already registered'
                      : (_emailError ? Validators.validateEmail(_emailController.text) : null),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 4),
                Text(
                  '(This is your registered email and cannot be changed)',
                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  onChanged: (_) {
                    if (_passwordError) setState(() => _passwordError = false);
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.password,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: _passwordError ? Validators.validatePassword(_passwordController.text) : null,
                  ),
                  obscureText: _obscurePassword,
                ),
                const SizedBox(height: 16),

                // Confirm Password
                TextFormField(
                  controller: _confirmPasswordController,
                  onChanged: (_) {
                    if (_confirmPasswordError) setState(() => _confirmPasswordError = false);
                  },
                  decoration: InputDecoration(
                    labelText: AppStrings.confirmPassword,
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF65B36A)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2C6D5E), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Colors.red, width: 2),
                    ),
                    labelStyle: const TextStyle(color: Colors.black),
                    floatingLabelStyle: const TextStyle(color: Colors.black),
                    errorStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    errorText: _confirmPasswordError ? Validators.validateConfirmPassword(_confirmPasswordController.text, _passwordController.text) : null,
                  ),
                  obscureText: _obscureConfirmPassword,
                ),
                const SizedBox(height: 24),

                // Register Button
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return ElevatedButton(
                      onPressed: auth.isLoading ? null : _handleRegister,
                      child: auth.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                              : const Text(AppStrings.signUp, style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Login Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: const Text(AppStrings.alreadyHaveAccount),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                          child: const Text(AppStrings.signIn, style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
} 