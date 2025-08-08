
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:rcspos/components/snackbar_helper.dart';
import 'package:rcspos/screens/posconfigpage.dart';
import 'package:rcspos/utils/urls.dart';

class Login extends StatelessWidget {
 

  const Login({
    super.key,

    });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _Logo(),
              SizedBox(height: 32),
              _CardWrapper(child: _FormContent()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column( // Use a Column to stack the logo and potentially a smaller title/slogan
        children: [
          Image.asset(
            'assets/rcslogo.png', // Path to your logo
            height: 200, // Adjust height as needed
            width: 200,  // Adjust width as needed, or remove for natural sizing
            // You can add other properties like fit: BoxFit.contain,
          ),
          const SizedBox(height: 0), // Spacing between logo and text
          Text(
            "RCS POS", // You can keep a smaller text title if desired
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith( 
              // Smaller headline for a subtitle
                  color: Color.fromARGB(255, 44, 145, 113),
                  fontWeight: FontWeight.bold,
                  // You can still apply Arial if loaded, e.g., fontFamily: 'Arial'
                  fontSize: 22, // Adjusted font size
                ),
          ),
        ],
      ),
    );
  }
}

class _CardWrapper extends StatelessWidget {
  final Widget child;
  const _CardWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBFF), // Optional soft background
     
      child: Padding(
        padding: const EdgeInsets.all(2.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: child,
        ),
      ),
    );
  }
}

class _FormContent extends StatefulWidget {
  const _FormContent();

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


 void _handleLogin() async {
  final box = await Hive.openBox("login");

  setState(() => _isVerifying = true);

  const url = "${baseurl}web/session/authenticate/";
  final payload = {
    "params": {
      "db": DB,
      "login": _emailController.text.toLowerCase(),
      "password": _passwordController.text,
    }
  };

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      if (data.containsKey("result")) {
        final session = response.headers[HttpHeaders.setCookieHeader]
                ?.split(';')
                .first ??
            '';
        await box.put("session_id", session);
        await box.put("userinfo", data['result']);
showCustomSnackBar(
  context: context,
  title: "Login Successful!",
  message: "Welcome",
  backgroundColor: Colors.green,
  icon: Icons.check_circle,
);

        if (_rememberMe) {
          await box.put("credentials", {
            "email": _emailController.text,
            "password": _passwordController.text,
            "status": _rememberMe,
          });
        } else {
          await box.delete("credentials");
        }
showCustomSnackBar(
  context: context,
  title: "Login Successful!",
  message: "Welcome",
  backgroundColor: Colors.green,
  icon: Icons.check_circle,
);




Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => const POSConfigPage()),
);


      } else {
 showCustomSnackBar(
  context: context,
  title: "Login Failed",
  message: "Invalid credentials",
  backgroundColor: Colors.red,
  icon: Icons.error,
);
     }
    } else {
     showCustomSnackBar(context: context,
  title:"Offline Mode",  message:"You're logged in as offline user", backgroundColor: Colors.orange,icon: Icons.wifi_off);
    }
  } catch (e) {
    // 🔌 Offline fallback logic
    final saved = box.get("credentials");
    if (saved != null &&
        saved["email"] == _emailController.text &&
        saved["password"] == _passwordController.text) {
      // Simulate userinfo with placeholder
      await box.put("userinfo", {
        "name": saved["email"],
        "offline": true,
      });

showCustomSnackBar(
  context: context,
  title: "Offline Mode",
  message:"You're currently logged in as an offline user",
  backgroundColor:Colors.orange, // background color
 icon:  Icons.wifi_off, // icon
);



Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (context) => POSConfigPage()),
);

   } else {
     showCustomSnackBar(
      context: context,
 title:  "Offline Login Failed",
  message:  "No saved credentials found",
 backgroundColor:  Colors.red,          // Use red for failure
  icon:Icons.error_outline, // Use an error icon
);

    }
  } finally {
    setState(() => _isVerifying = false);
  }
}


  @override
  Widget build(BuildContext context) {
    return Form(
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
            validator: (val) =>
                val == null || val.isEmpty ? 'Please enter password' : null,
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            value: _rememberMe,
            onChanged: (val) => setState(() => _rememberMe = val ?? true),
            title: const Text(
              "Remember me",
              style: TextStyle(
                color: Colors.black,
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Color.fromARGB(255, 49, 163, 127),
            checkColor: Colors.white,
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(40),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: _isVerifying
                  ? const CircularProgressIndicator(
                      color: Color.fromARGB(255, 1, 139, 82),
                    )
                  : const Text(
                      'Sign in',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 1, 139, 82),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
