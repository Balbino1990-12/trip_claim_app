import 'package:flutter/material.dart';
import '../register/register_page.dart';
//import home page to navigate after login
import '../home/home_page.dart';
import '../technician/technician_landing_page.dart';
import '../../services/api_service.dart';
import '../../services/trip_claim_upload_service.dart';
import '../../services/technician_service.dart';
import '../../services/local_storage_service.dart';
import '../../config/app_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showApiUrlField = false;

  @override
  void initState() {
    super.initState();
    // Initialize with default API URL
    _apiUrlController.text = AppConfig.getApiUrl();
    // Set API URL on app start
    ApiService.setBaseUrl(AppConfig.getApiUrl());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _apiUrlController.dispose();
    super.dispose();
  }

  /// Check if the user is a technical/technician user based on response data
  bool _isTechnicalUser(Map<String, dynamic> userData) {
    // Check various possible field names for user role/type
    final role = userData['role']?.toString().toLowerCase() ?? '';
    final userType = userData['userType']?.toString().toLowerCase() ?? '';
    final type = userData['type']?.toString().toLowerCase() ?? '';
    final department = userData['department']?.toString().toLowerCase() ?? '';

    // Check if nested user object exists
    if (userData['user'] is Map<String, dynamic>) {
      final nestedUser = userData['user'] as Map<String, dynamic>;
      final nestedRole = nestedUser['role']?.toString().toLowerCase() ?? '';
      final nestedUserType =
          nestedUser['userType']?.toString().toLowerCase() ?? '';
      final nestedType = nestedUser['type']?.toString().toLowerCase() ?? '';
      final nestedDepartment =
          nestedUser['department']?.toString().toLowerCase() ?? '';

      return nestedRole.contains('technician') ||
          nestedRole.contains('technical') ||
          nestedUserType.contains('technician') ||
          nestedUserType.contains('technical') ||
          nestedType.contains('technician') ||
          nestedType.contains('technical') ||
          nestedDepartment.contains('technician') ||
          nestedDepartment.contains('technical');
    }

    // Check the direct fields
    return role.contains('technician') ||
        role.contains('technical') ||
        userType.contains('technician') ||
        userType.contains('technical') ||
        type.contains('technician') ||
        type.contains('technical') ||
        department.contains('technician') ||
        department.contains('technical');
  }

  Future<void> _handleLogin() async {
    final phone = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // Validate phone field
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Clean and validate phone number (extract digits only)
    final cleanedPhone = phone.replaceAll(RegExp(r'\D'), '');
    if (cleanedPhone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Phone number must be at least 10 digits (you entered ${cleanedPhone.length})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate password field
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate password length
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Set API URL from the text field
      ApiService.setBaseUrl(_apiUrlController.text);

      // Call real login API with cleaned phone number
      final loginResponse = await ApiService.login(
        identifier: cleanedPhone,
        password: password,
      );

      if (loginResponse.success && loginResponse.data != null) {
        // Extract token from response
        final token =
            loginResponse.data!['token'] ?? loginResponse.data!['accessToken'];

        if (token != null) {
          // Sync token to all services
          ApiService.setAuthToken(token);
          TripClaimUploadService.setAuthToken(token);
          TechnicianService.setAuthToken(token);
        }

        // persist any useful user data we received
        final userData = loginResponse.data?['user'];
        if (userData is Map<String, dynamic>) {
          final savedPhone = userData['phoneNumber'] ?? userData['phone'];
          if (savedPhone != null) {
            await LocalStorageService.saveUserPhone(savedPhone.toString());
          }
          final savedMeter = userData['meterNumber'] ?? userData['meter'];
          if (savedMeter != null) {
            await LocalStorageService.saveUserMeter(savedMeter.toString());
          }
        }

        // Check if user is a technical user
        final isTechnician = _isTechnicalUser(loginResponse.data!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isTechnician
                    ? 'Welcome Technician! Redirecting to dashboard...'
                    : loginResponse.message,
              ),
              backgroundColor: Colors.green,
            ),
          );

          // Redirect based on user type
          if (isTechnician) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TechnicianLandingPage(),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loginResponse.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: const Text('Login'),
        // leading: const Icon(Icons.card_travel),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('web/icons/logo_edtl.png', width: 140, height: 140),
              const SizedBox(height: 24),
              const Text(
                'Trip Claim App',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to your account',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              const SizedBox(height: 24),
              if (_showApiUrlField)
                Column(
                  children: [
                    TextField(
                      controller: _apiUrlController,
                      decoration: InputDecoration(
                        labelText: 'API URL',
                        hintText: 'Enter API server URL',
                        prefixIcon: const Icon(Icons.api),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Login'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showApiUrlField = !_showApiUrlField;
                  });
                },
                child: Text(
                  _showApiUrlField ? 'Hide API Settings' : 'API Settings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    child: Text(
                      'Sign up',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
