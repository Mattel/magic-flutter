import 'package:flutter/material.dart';
import 'package:magic_demo/tabs/home.dart';
import 'package:magic_ext_oauth/oauth_configuration.dart';
import 'package:magic_sdk/magic_sdk.dart';
import 'package:magic_ext_oauth/magic_ext_oauth.dart';

import 'alert.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  Magic magic = Magic.instance;

  final myController = TextEditingController(text: 'jerry@magic.link');

  @override
  void initState() {
    super.initState();
    var future = magic.user.isLoggedIn();
    future.then((isLoggedIn) {
      if (isLoggedIn) {
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => const HomePage()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Magic Demo Login'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: TextFormField(
              controller: myController,
              decoration: const InputDecoration(
                hintText: 'Enter your email',
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                return null;
              },
            ),
          ),
          TextButton(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(Colors.blue),
            ),
            onPressed: () async {
              var token =
                  await magic.auth.loginWithMagicLink(email: myController.text);
              showResult(context, 'token, $token');

              if (token.isNotEmpty) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const HomePage()));
              }
            },
            child: const Text('Login With Magic Link'),
          ),
          TextButton(
            style: ButtonStyle(
              foregroundColor: MaterialStateProperty.all<Color>(Colors.blue),
            ),
            onPressed: () async {
              var configuration = OAuthConfiguration(provider: OAuthProvider.GITHUB, redirectURI: 'link.magic.demo://');
              var token = await magic.oauth.loginWithPopup(configuration);

              if (token.magic!.userMetadata!.email != null) {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const HomePage()));
              }
              showResult(context, 'publicAddress, ${token.magic!.userMetadata!.publicAddress}');
            },
            child: const Text('Github Login'),
          ),
        ])));
  }
}
