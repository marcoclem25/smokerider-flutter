import 'package:flutter/material.dart';

/// schermata iniziale per scegliere il ruolo dell’utente.
/// mostra due pulsanti: accedi come cliente o accedi come rider.
/// al click, naviga verso la pagina di login passando come argomento il ruolo scelto.
class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key}); // costruttore const con key opzionale

  @override
  Widget build(BuildContext context) {
    return Scaffold( // scaffold: struttura base di una schermata
      appBar: AppBar(
        title: const Text('Benvenuto in SmokeRider!'), // titolo appbar
      ),
      body: Center( // centra il contenuto
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // limita larghezza massima a 500
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20), // margine orizzontale
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // centra elementi verticalmente
              children: [
                // icona sopra al titolo
                const Icon(Icons.local_fire_department, size: 56, color: Colors.black54),
                const SizedBox(height: 16), // spaziatura

                // titolo principale
                const Text(
                  'Chi sei?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                /// pulsante principale: accedi come cliente
                FilledButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/login',       // route di destinazione
                    arguments: 'client', // passa il ruolo "client" alla pagina di login
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined), // icona sacchetto
                  label: const Text('Accedi come Cliente'),
                ),
                const SizedBox(height: 12),

                /// pulsante alternativo: accedi come rider
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/login',       // stessa route
                    arguments: 'rider',  // ma ruolo "rider"
                  ),
                  icon: const Icon(Icons.pedal_bike_outlined), // icona bici
                  label: const Text('Accedi come Rider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
