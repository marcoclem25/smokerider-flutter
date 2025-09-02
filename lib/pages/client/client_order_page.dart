// Pagina cliente per creare un nuovo ordine
// Gestisce indirizzo, carrello prodotti e invio ordine su Firestore
// Contiene anche catalogo di esempio e validazioni base


import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';    //Firebase Auth per utente loggato
import 'package:cloud_firestore/cloud_firestore.dart';//Firestore per lettura/scrittura documenti

import '../../services/auth_service.dart';            // service wrapper per autenticazione
import '../../services/firestore_orders.dart';        // service wrapper per creare ordini
import 'place_autocomplete_page.dart';                // per restituire indirizzo scelto con lat/lng


class ClientOrderPage extends StatefulWidget {        // Stateful: ha stato mutabile nel time (campi, carrello)
  const ClientOrderPage({super.key});                 // Costruttore const + parametro opzionale 'key'

  @override
  State<ClientOrderPage> createState() => _ClientOrderPageState(); // Crea lo State associato
}

// Classe privata (underscore = private nel file) che contiene lo stato e la logica
class _ClientOrderPageState extends State<ClientOrderPage> {
  // ---- Indirizzo / geo ----
  final _addressCtrl = TextEditingController();       // Controller del TextField indirizzo
  double? _lat;                                       // Coordinate possono essere nulle => tipo nullable (double?)
  double? _lng;
  bool _addressError = false;                         // Flag: se true mostra errore sul campo indirizzo

  // ---- Catalogo / carrello ----
  final _searchCtrl = TextEditingController();        // Controller del campo di ricerca prodotti
  ProductCategory? _selectedCategory;                 // Categoria selezionata (null = tutte)
  final Map<String, int> _qtyByName = {};             // Quantità corrente per prodotto (anche fuori carrello)
  final Map<String, int> _cart = {};                  // Carrello: nome prodotto -> quantità

  // Getter (sola lettura) che calcola una proprietà "derivata": true se indirizzo + lat/lng presenti
  bool get _hasAddress =>
      _addressCtrl.text.trim().isNotEmpty && _lat != null && _lng != null;

  @override
  void dispose() {                                    // Lifecycle: chiamato quando il widget viene rimosso
    _addressCtrl.dispose();                           // Rilascia risorse dei controller per evitare memory leak
    _searchCtrl.dispose();
    super.dispose();
  }

  // ADDRESS SEARCH
  // Apre la pagina di autocomplete e attende un risultato asincrono
  Future<void> _openSearch() async {
    final res = await Navigator.push<PlaceAutocompleteResult>( // push: apre nuova pagina e aspetta risultato
      context,
      MaterialPageRoute(builder: (_) => const PlaceAutocompletePage()), // route verso la pagina di ricerca
    );
    if (res != null) {                                       // Se l’utente ha selezionato un indirizzo
      setState(() {
        _addressCtrl.text = res.address;                     // Aggiorna testo indirizzo
        _lat = res.lat;                                      // Salva coordinate
        _lng = res.lng;
        _addressError = false;                               // Rimuove eventuale stato d’errore
      });
    }
  }

  //  SUBMIT (INVIO UN SOLO ORDINE)
  Future<void> _submit() async {
    // 1) Vincolo: indirizzo obbligatorio. Se manca: bordo rosso + popup, e ritorno.
    if (!_hasAddress) {
      setState(() => _addressError = true);                  // Attiva visualizzazione errore sul TextField
      showDialog<void>(                                      // Mostra un dialog di avviso
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Indirizzo mancante'),
          content: const Text('Devi prima selezionare un indirizzo di consegna.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),       // Chiude il dialog
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;                                                // Interrompe la funzione
    }

    // 2) Vincolo: carrello non vuoto
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(            // Mostra snackbar in basso
        const SnackBar(content: Text('Seleziona almeno un prodotto.')),
      );
      return;
    }

    // 3) Utente loggato (usa '!' perché presuppone che non sia null => attenzione in produzione)
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // 4) Costruzione lista 'items' per Firestore partendo dal carrello
    final items = _cart.entries.map((e) {                    // entries = Iterable<MapEntry<name, qty>>
      final product = _kCatalog.firstWhere((p) => p.name == e.key); // Trova prodotto nel catalogo per nome
      return {
        'name': product.name,                                // Nome del prodotto
        'qty': e.value,                                      // Quantità nel carrello
        'price': product.price,                              // Prezzo unitario
        'category': product.category.label,                  // Etichetta categoria (es. "Sigarette")
      };
    }).toList();                                             // Converte da Iterable a List<Map<String, dynamic>>

    // 5) Totali
    final totalQty = _cart.values.fold<int>(0, (a, b) => a + b); // Somma delle quantità (pezzi totali)
    final totalPrice = _cart.entries.fold<double>(               // Somma prezzi * quantità
      0,
          (sum, e) => sum + (_kCatalog.firstWhere((p) => p.name == e.key).price * e.value),
    );

    // 6) Compatibilità: alcune viste si aspettano "brand/quantity" singoli
    String brandLabel;
    int displayQty;
    if (_cart.length == 1) {                                  // Se c’è un solo prodotto
      final only = _cart.entries.first;                       // Prendi l’unica entry
      brandLabel = only.key;                                  // brand = nome del prodotto
      displayQty = only.value;                                // quantity = sua quantità
    } else {
      brandLabel = 'Carrello';                                // Altrimenti etichetta generica
      displayQty = totalQty;                                  // quantity = pezzi totali
    }

    // 7) Crea documento di ordine “base” con il service
    final orderId = await FirestoreOrders.instance.createOrder(
      clientId: uid,
      address: _addressCtrl.text.trim(),                      // Indirizzo (string)
      brand: brandLabel,                                      // Compatibilità con modelli esistenti
      quantity: displayQty,
      lat: _lat,                                              // double? (accetta null, ma qui non dovrebbero esserlo)
      lng: _lng,
    );

    // 8) Aggiorna lo stesso documento con dettagli “ricchi” del carrello
    try {
      await FirebaseFirestore.instance
          .collection('orders')                               // Collezione 'orders'
          .doc(orderId)                                       // Documento appena creato
          .update({
        'items': items,                                       // Lista oggetti (name, qty, price, category)
        'itemsCount': _cart.length,                           // Numero di prodotti DISTINCT
        'totalPrice': totalPrice,                             // Totale in euro (double)
      });
    } catch (_) {}                                            // Ignora eventuali errori (migliorabile)

    // 9) Feedback e navigazione
    if (!mounted) return;                                     // Safety: verifica se lo State è ancora attivo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ordine inviato!')),
    );
    Navigator.pushNamed(context, '/client/orders');           // Vai alla lista ordini cliente (ora mostra solo l’ultimo)
  }

  // Logout: usa il tuo AuthService e pulisce lo stack
  Future<void> _logout() async {
    await AuthService.instance.signOut();                     // Esegue signOut
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false); // Torna alla root, rimuovendo tutte le route
  }

  //HELPERS CATALOGO

  // Ritorna la lista filtrata dei prodotti in base a categoria e testo ricercato
  List<Product> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();         // Query in minuscolo per confronto case-insensitive
    return _kCatalog.where((p) {
      final byCat = _selectedCategory == null || p.category == _selectedCategory; // Filtra per categoria
      final byText = q.isEmpty || p.name.toLowerCase().contains(q);               // Filtra per testo
      return byCat && byText;                                                     // Deve soddisfare entrambi
    }).toList();
  }

  // Ritorna la quantità “corrente” impostata per un prodotto, default 1
  int _getQty(Product p) => _qtyByName[p.name] ?? 1;

  // Imposta nuova qty e, se il prodotto è già nel carrello, aggiorna anche lì
  void _setQty(Product p, int q) {
    setState(() {
      _qtyByName[p.name] = q.clamp(1, 99);                   // clamp: limita tra 1 e 99
      if (_cart.containsKey(p.name)) {
        _cart[p.name] = _qtyByName[p.name]!;                 // '!' perché dopo l’assegnazione non è null
      }
    });
  }

  // Aggiunge/aggiorna il prodotto nel carrello con la quantità corrente
  void _addToCart(Product p) {
    final q = _getQty(p);
    setState(() => _cart[p.name] = q);
    ScaffoldMessenger.of(context).showSnackBar(              // Feedback
      SnackBar(content: Text('Aggiunto: ${p.name} x$q')),
    );
  }

  // Rimuove il prodotto dal carrello
  void _removeFromCart(String name) {
    setState(() => _cart.remove(name));
  }

  // Ritorna il totale pezzi (somma delle quantità nel carrello)
  int get _totalItems => _cart.values.fold<int>(0, (a, b) => a + b);


  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;                               // Cache locale dei prodotti filtrati

    return Scaffold(                                          // Layout “schermata” base con AppBar e body
      appBar: AppBar(
        title: const Text('Nuovo ordine'),
        actions: [
          IconButton(
            tooltip: 'I miei ordini',
            onPressed: () => Navigator.pushNamed(context, '/client/orders'), // Shortcut a lista ordini
            icon: const Icon(Icons.list_alt),
          )
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),   // Layout a colonna centrato con maxWidth
          child: ListView(                                    // Scroll verticale (Form rimosso perché non usato)
            padding: const EdgeInsets.all(20),
            children: [
              //Indirizzo
              TextField(
                controller: _addressCtrl,                     // Campo indirizzo (solo lettura)
                readOnly: true,
                onTap: _openSearch,                           // Tocca per aprire la ricerca luoghi
                decoration: InputDecoration(
                  labelText: 'Indirizzo di consegna',
                  hintText: 'Tocca per cercare',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.search),
                  // Se _addressError è true mostra bordo rosso e messaggio
                  errorText:
                  _addressError ? 'Seleziona l’indirizzo dalla ricerca' : null,
                ),
              ),
              if (_lat != null && _lng != null)               // (opzionale) mostra coordinate
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Geo: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              const SizedBox(height: 16),

              //Filtro+ricerca
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(                     // Wrapper per dare look “TextField” al dropdown
                      decoration: const InputDecoration(
                        labelText: 'Categoria',
                        border: OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(     // Nasconde la riga sotto al Dropdown
                        child: DropdownButton<ProductCategory?>(
                          value: _selectedCategory,            // null = “Tutte”
                          isExpanded: true,                    // Prende tutta la larghezza
                          items: <DropdownMenuItem<ProductCategory?>>[
                            const DropdownMenuItem(
                              value: null,
                              child: Text('Tutte'),
                            ),
                            ...ProductCategory.values.map(     // Crea un item per ogni categoria enum
                                  (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.label),         // Usa l’estensione label
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v), // Aggiorna filtro categoria
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(                          // Campo di ricerca testuale
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),       // Rebuild per aggiornare lista filtrata
                      decoration: const InputDecoration(
                        labelText: 'Cerca prodotto',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              //Lista prodotti
              ...filtered.map(
                    (p) => _ProductCard(
                  product: p,
                  qty: _getQty(p),                            // Quantità corrente impostata (default 1)
                  inCart: _cart.containsKey(p.name),          // True se già in carrello
                  onMinus: () => _setQty(p, _getQty(p) - 1),
                  onPlus: () => _setQty(p, _getQty(p) + 1),
                  onAdd: () => _addToCart(p),
                ),
              ),

              const SizedBox(height: 12),

              //Riepilogo carrello
              if (_cart.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ListTile(
                          title: Text('Riepilogo ordine'),
                          subtitle: Text('Prodotti selezionati'),
                        ),
                        const Divider(height: 1),
                        ..._cart.entries.map(
                              (e) => ListTile(
                            title: Text(e.key),               // Nome prodotto
                            trailing: Row(                    // Lato destro: qty + pulsante elimina
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('x${e.value}'),
                                IconButton(
                                  tooltip: 'Rimuovi',
                                  onPressed: () => _removeFromCart(e.key),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Text(
                            'Totale pezzi: $_totalItems',     // Somma quantità
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,                           // Sempre cliccabile (la logica blocca se manca indirizzo)
                icon: const Icon(Icons.send),
                label: const Text('Invia ordine'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Dopo l’invio parte un timer di 10 minuti: un rider può accettare entro la scadenza.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextButton.icon(
            onPressed: _logout,                               // Esegue logout
            icon: const Icon(Icons.logout),
            label: const Text('Esci'),
          ),
        ),
      ),
    );
  }
}

// MODELLI (MVP)

enum ProductCategory { terea, sigarette }

extension _CategoryLabel on ProductCategory {
  String get label => switch (this) {
    ProductCategory.terea => 'Terea',
    ProductCategory.sigarette => 'Sigarette',
  };
}

class Product {
  final String name;
  final double price;
  final ProductCategory category;

  const Product({
    required this.name,
    required this.price,
    required this.category,
  });
}

const List<Product> _kCatalog = [
  // Terea
  Product(name: 'Terea Bronze',    price: 5.50, category: ProductCategory.terea),
  Product(name: 'Terea Amber',     price: 5.50, category: ProductCategory.terea),
  Product(name: 'Terea Blue',      price: 5.50, category: ProductCategory.terea),
  Product(name: 'Terea Turquoise', price: 5.50, category: ProductCategory.terea),

  // Sigarette
  Product(name: 'Marlboro Gold Touch', price: 6.50, category: ProductCategory.sigarette),
  Product(name: 'Marlboro Red',        price: 6.50, category: ProductCategory.sigarette),
  Product(name: 'Winston',             price: 6.00, category: ProductCategory.sigarette),
  Product(name: 'Camel Yellow',        price: 6.00, category: ProductCategory.sigarette),
  Product(name: 'Camel Blue',          price: 6.00, category: ProductCategory.sigarette),
  Product(name: 'Chesterfield Blue',   price: 5.20, category: ProductCategory.sigarette),
  Product(name: 'Lucky Strike',        price: 5.50, category: ProductCategory.sigarette),
];

//CARD PRODOTTO

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.qty,
    required this.inCart,
    required this.onMinus,
    required this.onPlus,
    required this.onAdd,
  });

  final Product product;
  final int qty;
  final bool inCart;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '€ ${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            // Stepper quantità
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(.08),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onMinus,
                    icon: const Icon(Icons.remove),
                    visualDensity: VisualDensity.compact,
                  ),
                  Text(qty.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: onPlus,
                    icon: const Icon(Icons.add),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: onAdd,
              child: Text(inCart ? 'Selezionato' : 'Aggiungi'),
            ),
          ],
        ),
      ),
    );
  }
}
