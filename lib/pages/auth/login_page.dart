import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// pagina di registrazione
import 'register_page.dart';

/// pagina di login: permette accesso tramite email/password.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key}); // costruttore const con key opzionale

  @override
  State<LoginPage> createState() => _LoginPageState(); // crea lo state associato
}

class _LoginPageState extends State<LoginPage> {
  // chiave per validazione form
  final _formKey = GlobalKey<FormState>();
  // controller per campo email
  final _emailCtrl = TextEditingController();
  // controller per campo password
  final _passCtrl = TextEditingController();

  bool _obscure = true; // gestisce visibilità password
  bool _busy = false;   // stato caricamento (disabilita bottoni quando true)

  // recupera il ruolo passato come argomento alla route
  String get _role {
    final arg = ModalRoute.of(context)?.settings.arguments as String?;
    return (arg == 'rider') ? 'rider' : 'client'; // default client
  }

  @override
  void dispose() {
    // libera i controller quando la pagina viene distrutta
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  /// metodo che esegue il login con firebase auth
  Future<void> _login() async {
    // valida il form: se non valido, non procede
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _busy = true); // setta busy = true → disabilita bottoni
    try {
      // tenta login firebase con email e password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      // decide la prossima pagina in base al ruolo
      final next = (_role == 'rider') ? '/rider' : '/client';
      // naviga e rimuove tutte le pagine precedenti
      Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // messaggio di errore base
      String msg = 'Accesso non riuscito.';
      // gestione errori specifici di firebase
      if (e.code == 'user-not-found') msg = 'Utente non trovato.';
      if (e.code == 'wrong-password') msg = 'Password errata.';
      if (e.code == 'invalid-credential') msg = 'Credenziali non valide.';
      // mostra dialog di errore
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Errore di accesso'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      // rimette busy = false (se ancora montato)
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // controlla se ruolo = rider
    final isRider = _role == 'rider';
    // titolo dinamico
    final title = isRider ? 'Accedi come rider' : 'Accedi come cliente';

    return Scaffold(
      appBar: AppBar(title: Text(title)), // titolo appbar
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520), // larghezza max
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey, // form con validazione
              child: ListView(
                shrinkWrap: true,
                children: [
                  // testo che indica se si accede come cliente o rider
                  Text(
                    'Stai accedendo come ${isRider ? 'Rider' : 'Cliente'}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  // campo email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Inserisci l’email' : null,
                  ),
                  const SizedBox(height: 12),
                  // campo password
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure, // mostra/nasconde testo
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton( // bottone per mostrare/nascondere password
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) =>
                    (v == null || v.isEmpty) ? 'Inserisci la password' : null,
                  ),
                  const SizedBox(height: 16),
                  // bottone accedi
                  FilledButton(
                    onPressed: _busy ? null : _login, // se busy → disabilitato
                    child: _busy
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Accedi'),
                  ),
                  const Divider(height: 32),
                  // link alla registrazione
                  Center(
                    child: TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                        // naviga alla pagina di registrazione
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterPage(initialRole: _role),
                          ),
                        );
                      },
                      child: const Text('Non hai un account? Registrati'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
