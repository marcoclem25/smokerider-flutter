import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';  // per inizializzare Firebase
import 'firebase_options.dart';

// import delle varie pagine del progetto
import 'pages/role_select_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/auth/register_page.dart';
import 'pages/client/client_order_page.dart';
import 'pages/client/client_orders_list_page.dart';
import 'pages/rider/rider_orders_page.dart';
import 'pages/rider/rider_my_jobs_page.dart';

// funzione main: punto di ingresso dell’app
Future<void> main() async {
  // assicura che il binding di Flutter sia inizializzato (necessario per async nel main)
  WidgetsFlutterBinding.ensureInitialized();

  // inizializza Firebase con le opzioni corrette per la piattaforma (Android/iOS/Web)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // avvia l’app chiamando runApp con il widget principale
  runApp(const SmokeRiderApp());
}

// widget principale dell'app
// StatelessWidget = non ha stato interno, viene ricostruito solo se cambia qualcosa sopra di lui
class SmokeRiderApp extends StatelessWidget {
  const SmokeRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    // MaterialApp = punto di ingresso per un’app Flutter con design Material
    return MaterialApp(
      title: 'SmokeRider',              // titolo dell’app (può apparire in multitasking)
      debugShowCheckedModeBanner: false,// nasconde la scritta “debug” in alto a destra

      // route iniziale, schermata da cui parte l’app
      initialRoute: '/',

      // mappa delle route con nome -> widget corrispondente
      routes: {
        // Home: scelta profilo (cliente o rider)
        '/': (context) => const RoleSelectPage(),

        // Flusso autenticazione
        '/login':    (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),

        // Flusso Cliente
        '/client':        (context) => const ClientOrderPage(),
        '/client/orders': (context) => const ClientOrdersListPage(),

        // Flusso Rider
        '/rider':      (context) => const RiderOrdersPage(),
        '/rider/jobs': (context) => const RiderMyJobsPage(),
      },

      // se viene chiamata una rotta non definita, torniamo alla scelta profilo
      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const RoleSelectPage()),

      // tema dell’app: Material 3
      theme: ThemeData(
        useMaterial3: true,              // attiva le nuove linee guida Material 3
        colorSchemeSeed: Colors.indigo,  // colore di base per pulsanti, appbar ecc.
      ),
    );
  }
}
