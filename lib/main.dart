import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'providers/auth_provider.dart' as local_auth;
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/user/user_dashboard.dart';
import 'utils/constants.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => local_auth.AuthProvider()),
      ],
      child: MaterialApp(
        title: AppStrings.appName,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboard(),
          '/home': (context) => const UserDashboard(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _loading = true;
  bool _userLoaded = false;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Load user data from Firestore
        await Provider.of<local_auth.AuthProvider>(context, listen: false).loadUserFromFirebase();
        setState(() {
          _userLoaded = true;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userModel = Provider.of<local_auth.AuthProvider>(context).user;
    
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // If Firebase user exists but we haven't loaded user data yet, show loading
    if (user != null && !_userLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (user != null && userModel != null) {
      // Check user role and route accordingly
      print('User role: ${userModel.role}'); // Debug print
      print('User UID: ${userModel.uid}'); // Debug print
      
      if (userModel.role == 'admin') {
        print('Routing to admin dashboard'); // Debug print
        return const AdminDashboard();
      } else {
        print('Routing to user dashboard'); // Debug print
        return const UserDashboard();
      }
    } else {
      print('No user found, routing to login'); // Debug print
      return const LoginScreen();
    }
  }
}
