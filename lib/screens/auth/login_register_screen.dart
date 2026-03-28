import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      UserCredential cred;
      if (_isRegister) {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      final user = cred.user;
      if (user != null) {
        // Ensure user document exists
        final nameToSave = (_nameController.text.trim().isNotEmpty)
            ? _nameController.text.trim()
            : (user.email?.split('@').first ?? 'User_${user.uid.substring(0, 6)}');

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          <String, dynamic>{
            'name': nameToSave,
            'displayName': nameToSave,
            'email': user.email,
            'avatarUrl': null,
            'isLocationVisible': true,
            'study_status': 'Chưa cập nhật',
            'badges': <String>[],
            'streakDays': 0,
            'settings': <String, dynamic>{},
          },
          SetOptions(merge: true),
        );

        if (!mounted) return;
        Navigator.of(context).pop();
      }
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? e.code;
      if (e.code == 'configuration-not-found' || e.code == 'CONFIGURATION_NOT_FOUND') {
        msg = 'Provider chưa được cấu hình trên Firebase. Vào Firebase Console → Authentication → Sign-in method và bật Email/Password (và Anonymous nếu cần).';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      final uid = cred.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          <String, dynamic>{
            'name': 'User_$uid',
            'displayName': 'User_$uid',
            'avatarUrl': null,
            'isLocationVisible': true,
            'study_status': 'Chưa cập nhật',
            'badges': <String>[],
            'streakDays': 0,
            'settings': <String, dynamic>{},
          },
          SetOptions(merge: true),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      String msg = '$e';
      // If anonymous sign-in fails due to config, suggest enabling provider
      if (e is FirebaseAuthException &&
          (e.code == 'configuration-not-found' || e.code == 'CONFIGURATION_NOT_FOUND')) {
        msg = 'Anonymous sign-in chưa được bật trên Firebase. Vào Firebase Console → Authentication → Sign-in method và bật Anonymous.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isRegister ? 'Register' : 'Sign in'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_isRegister)
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) => null,
                      ),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter email';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Please enter password';
                        if (v.length < 6) return 'Password too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_isRegister ? 'Register' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () {
                              setState(() => _isRegister = !_isRegister);
                            },
                      child: Text(_isRegister ? 'Have an account? Sign in' : 'Create an account'),
                    ),
                    const Divider(),
                    TextButton(
                      onPressed: _loading ? null : _signInAnonymously,
                      child: const Text('Continue anonymously'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
