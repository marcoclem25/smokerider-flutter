import 'package:firebase_auth/firebase_auth.dart';  //firebase_auth per utenti autenticati
import 'package:flutter/material.dart';   //material dart
import '../../services/auth_service.dart';    //servizio auth custom
// pagine che potrebbero essere mostrate
import '../auth/login_page.dart';
import '../client/client_order_page.dart';
import '../rider/rider_orders_page.dart';

/// widget che funge da "porta di accesso" (gate) in base allo stato di autenticazione
/// se l’utente non è loggato → mostra login
/// se loggato → recupera ruolo e redirige alla home corretta (cliente o rider)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key}); // costruttore const con key opzionale

  @override
  Widget build(BuildContext context) {
    // streambuilder che ascolta i cambiamenti nello stato di autenticazione firebase
    return StreamBuilder<User?>(
      // stream di auth (es. login/logout)
      stream: AuthService.instance.authState(),
      builder: (context, s) {
        // mentre la connessione allo stream non è pronta → mostra spinner
        if (s.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // prendo utente corrente dallo snapshot
        final user = s.data;

        // se user è null → non autenticato → vai a login
        if (user == null) return const LoginPage();

        // se utente autenticato → devo sapere che ruolo ha (client o rider)
        // uso un futurebuilder perché fetchRole() è async
        return FutureBuilder<String?>(
          future: AuthService.instance.fetchRole(), // recupera ruolo da firestore
          builder: (context, r) {
            // mentre il future non ha completato → spinner
            if (r.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // prendo ruolo (default: client se null)
            final role = r.data ?? 'client';

            // se ruolo rider → porta alla pagina ordini rider, altrimenti client
            return role == 'rider'
                ? const RiderOrdersPage()
                : const ClientOrderPage();
          },
        );
      },
    );
  }
}
