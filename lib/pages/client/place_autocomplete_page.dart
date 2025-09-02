// Pagina che permette al cliente di cercare un indirizzo con Google Places
// Usa autocomplete con debounce, mostra risultati e ritorna lat/lng + indirizzo
// Serve per scegliere l’indirizzo di consegna in modo preciso


import 'dart:async'; // Timer per debounce delle ricerche
import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

// classe risultato che contiene latitudine, longitudine e indirizzo
class PlaceAutocompleteResult {
  final double lat;     // latitudine
  final double lng;     // longitudine
  final String address; // indirizzo testuale
  PlaceAutocompleteResult({
    required this.lat,
    required this.lng,
    required this.address,
  });
}

// schermata per cercare un indirizzo tramite Google Places Autocomplete
class PlaceAutocompletePage extends StatefulWidget {
  const PlaceAutocompletePage({super.key});

  @override
  State<PlaceAutocompletePage> createState() => _PlaceAutocompletePageState();
}

class _PlaceAutocompletePageState extends State<PlaceAutocompletePage> {
  // chiave API di Google Places
  static const _apiKey = 'AIzaSyC-owciZSSyLcOjEEghDlV4kvMaccZO-8s';

  late final FlutterGooglePlacesSdk _places; // istanza sdk Places
  final _ctrl = TextEditingController();     // controller input testo
  List<AutocompletePrediction> _predictions = []; // risultati autocomplete
  bool _loading = false;                     // flag caricamento
  Timer? _debounce;                          // debounce digitazione

  @override
  void initState() {
    super.initState();
    _places = FlutterGooglePlacesSdk(_apiKey); // inizializza SDK
  }

  @override
  void dispose() {
    _debounce?.cancel(); // cancella timer se ancora attivo
    _ctrl.dispose();     // rilascia controller
    super.dispose();
  }

  // metodo richiamato ad ogni cambiamento input
  void _onChanged(String input) {
    _debounce?.cancel();
    // nuovo timer: evita chiamate continue → chiama _search dopo 250ms
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _search(input);
    });
  }

  // chiama le API di autocomplete
  Future<void> _search(String input) async {
    final query = input.trim();
    if (query.length < 2) {
      setState(() => _predictions = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final resp = await _places.findAutocompletePredictions(
        query,
        countries: const ['IT'], // limita a Italia
        newSessionToken: true,
      );
      if (!mounted) return;
      setState(() => _predictions = resp.predictions);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore ricerca: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // quando l’utente seleziona un risultato
  Future<void> _onPick(AutocompletePrediction p) async {
    try {
      // richiede dettagli luogo (solo Location lat/lng)
      final det = await _places.fetchPlace(
        p.placeId!,
        fields: const [PlaceField.Location],
      );
      final place = det.place;
      final loc = place?.latLng;

      // costruisce stringa indirizzo leggibile
      final addr = p.fullText ??
          [p.primaryText, p.secondaryText].whereType<String>().join(', ');

      // ritorna risultato alla pagina chiamante
      if (loc != null && addr.isNotEmpty && mounted) {
        Navigator.pop(
          context,
          PlaceAutocompleteResult(
            lat: loc.lat,
            lng: loc.lng,
            address: addr,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Errore dettaglio luogo: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = !_loading && _predictions.isEmpty && _ctrl.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Cerca indirizzo')),
      body: Column(
        children: [
          // campo input ricerca
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cerca luogo o indirizzo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (empty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Nessun risultato',
                    style: TextStyle(color: Colors.black54)),
              ),
            ),
          // lista risultati
          Expanded(
            child: ListView.separated(
              itemCount: _predictions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _predictions[i];
                return ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(p.primaryText ?? p.fullText ?? ''),
                  subtitle:
                  (p.secondaryText != null) ? Text(p.secondaryText!) : null,
                  onTap: () => _onPick(p),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
