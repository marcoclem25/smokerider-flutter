// importa flutter material per i widget base
import 'package:flutter/material.dart';
// importa il servizio di autenticazione custom (gestisce registrazione firebase)
import '../../services/auth_service.dart';
// importa la pagina di login per permettere la navigazione inversa
import 'login_page.dart';

/// pagina di registrazione: permette di creare un nuovo account come client o rider.
/// se client, richiede anche conferma età 18+.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key, this.initialRole});

  /// ruolo iniziale: 'client' | 'rider' (default: 'client')
  final String? initialRole;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // chiave per validazione form
  final _form = GlobalKey<FormState>();
  // controller per i campi testo
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  String _role = 'client'; // ruolo selezionato
  bool _adultOk = false;   // conferma età 18+ (solo client)
  bool _loading = false;   // stato caricamento
  bool _obscure = true;    // mostra/nascondi password

  @override
  void initState() {
    super.initState();
    // imposta ruolo iniziale in base a parametro ricevuto
    _role = (widget.initialRole == 'rider') ? 'rider' : 'client';
    // se non client, disattiva checkbox adultOk
    if (_role != 'client') _adultOk = false;
  }

  @override
  void dispose() {
    // libera controller quando pagina viene distrutta
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  /// metodo che valida input e registra un nuovo account
  Future<void> _submit() async {
    // valida form
    if (!_form.currentState!.validate()) return;

    // se ruolo = client, richiede conferma età
    if (_role == 'client' && !_adultOk) {
      _showAlert(
        title: 'Conferma età',
        message:
        'Per registrarti come Cliente devi confermare di avere almeno 18 anni.',
      );
      return;
    }

    setState(() => _loading = true); // mostra spinner e disabilita pulsanti
    try {
      // chiama AuthService.signUp con dati raccolti
      await AuthService.instance.signUp(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        displayName: _name.text.trim(),
        role: _role,
        isAdultConfirmed: _role == 'client' ? true : false,
      );

      if (!mounted) return;
      // naviga alla home appropriata in base al ruolo
      final next = _role == 'rider' ? '/rider' : '/client';
      Navigator.pushNamedAndRemoveUntil(context, next, (_) => false);
    } catch (e) {
      if (!mounted) return;
      // mostra alert con messaggio di errore
      _showAlert(title: 'Registrazione non riuscita', message: '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// metodo helper per mostrare un popup di alert
  void _showAlert({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_loading;            // abilita pulsante se non loading
    final showAdult = _role == 'client';    // mostra checkbox adult solo se client
    final roleLabel = _role == 'rider' ? 'Rider' : 'Cliente'; // label dinamico

    return Scaffold(
      appBar: AppBar(title: const Text('Registrati')), // titolo appbar
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // max larghezza form
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // testo iniziale con ruolo
                Text(
                  'Stai registrandoti come $roleLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),

                // campo nome visibile
                TextFormField(
                  controller: _name,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Nome visibile',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Inserisci un nome' : null,
                ),
                const SizedBox(height: 12),

                // campo email
                TextFormField(
                  controller: _email,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                  (v == null || !v.contains('@')) ? 'Email valida' : null,
                ),
                const SizedBox(height: 12),

                // campo password
                TextFormField(
                  controller: _pass,
                  enabled: !_loading,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton( // bottone mostra/nascondi
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (v) =>
                  (v == null || v.length < 6) ? 'Min 6 caratteri' : null,
                ),
                const SizedBox(height: 12),

                // scelta ruolo (cliente o rider)
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'client',
                      label: Text('Cliente'),
                      icon: Icon(Icons.person),
                    ),
                    ButtonSegment(
                      value: 'rider',
                      label: Text('Rider'),
                      icon: Icon(Icons.delivery_dining),
                    ),
                  ],
                  selected: {_role}, // ruolo attuale
                  onSelectionChanged: _loading
                      ? null
                      : (s) => setState(() {
                    _role = s.first; // aggiorna ruolo
                    if (_role != 'client') _adultOk = false; // reset adultOk
                  }),
                ),

                // se client, mostra checkbox adult
                if (showAdult) ...[
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _adultOk,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() => _adultOk = v ?? false),
                    title: const Text('Confermo di avere almeno 18 anni'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],

                const SizedBox(height: 20),
                // pulsante submit
                FilledButton(
                  onPressed: canSubmit ? _submit : null,
                  child: _loading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Crea account'),
                ),

                const SizedBox(height: 12),
                // link a login se già registrato
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                      // torna alla pagina login, passando ruolo selezionato
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoginPage(),
                          settings: RouteSettings(arguments: _role),
                        ),
                      );
                    },
                    child: const Text('Hai già un account? Accedi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
