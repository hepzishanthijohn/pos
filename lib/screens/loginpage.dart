import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:rcspos/screens/posconfigpage.dart';
import 'package:rcspos/utils/urls.dart';
import 'home.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor:  Colors.white,
      body: Center(
        child: isSmallScreen
            ? const SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Logo(),
                    _FormContent(),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 800),
                child: const Row(
                  children: [
                    Expanded(child: _Logo()),
                    Expanded(child: Center(child: _FormContent())),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        "RCS POS",
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color.fromARGB(255, 0, 124, 73)),
      ),
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent({super.key});

  @override
  State<_FormContent> createState() => __FormContentState();
}

class __FormContentState extends State<_FormContent> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = true;
  bool _isPasswordVisible = false;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadLoginData();
  }

  Future<void> _loadLoginData() async {
    final box = await Hive.openBox("login");
    final credentials = box.get("credentials");
    if (credentials != null) {
      _emailController.text = credentials["email"];
      _passwordController.text = credentials["password"];
      _rememberMe = credentials["status"];
      setState(() {});
    }
  }

  void _showSnackBar(String title, String message, ContentType type) {
    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      content: AwesomeSnackbarContent(
        title: title,
        message: message,
        contentType: type,
      ),
    );
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);
  }

void _handleLogin() async {
  final box = await Hive.openBox("login");

  try {
    const url = "${baseurl}web/session/authenticate/";
    final payload = {
      "params": {
        "db": DB,
        "login": _emailController.text.toLowerCase(),
        "password": _passwordController.text,
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data.containsKey("result")) {
        // ✅ Store session ID
        final session = response.headers[HttpHeaders.setCookieHeader]
            ?.split(';')
            .first ?? '';
        await box.put("session_id", session);

        // ✅ Store user info (entire result map)
        await box.put("userinfo", data['result']);

        // ✅ Store credentials only if "Remember me" is checked
        if (_rememberMe) {
          await box.put("credentials", {
            "email": _emailController.text,
            "password": _passwordController.text,
            "status": _rememberMe,
          });
        } else {
          await box.delete("credentials");
        }

        _showSnackBar("Login Successful!", "Welcome", ContentType.success);

        // Navigate to POS config page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const POSConfigPage()),
        );
      } else {
        _showSnackBar("Login Failed", "Invalid credentials", ContentType.failure);
      }
    } else {
      _showSnackBar("Server Error", "Please try again later", ContentType.failure);
    }
  } catch (e) {
    _showSnackBar("Error", "Cannot connect to server", ContentType.failure);
  } finally {
    setState(() => _isVerifying = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Username',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (val) => val == null || val.isEmpty ? 'Please enter password' : null,
            ),
            const SizedBox(height: 16),
           CheckboxListTile(
  value: _rememberMe,
  onChanged: (val) => setState(() => _rememberMe = val ?? true),
  title: const Text(
    "Remember me",
    style: TextStyle(
      color: Colors.black, // ✅ Text color
     
    ),
  ),
  controlAffinity: ListTileControlAffinity.leading,
  activeColor: const Color.fromARGB(255, 0, 124, 73), // ✅ Checkbox fill color
  checkColor: Colors.white, // Optional: check mark color
),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isVerifying
                  ? null
                  : () {
                      if (_formKey.currentState?.validate() ?? false) {
                        setState(() => _isVerifying = true);
                        _handleLogin();
                      }
                    },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: _isVerifying
    ? const CircularProgressIndicator(color: Color.fromARGB(255, 1, 139, 82))
    : const Text(
        'Sign in',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color.fromARGB(255, 1, 139, 82), // ✅ Green color
        ),
      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
