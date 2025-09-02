// Mostra l’ultimo incarico accettato dal rider (stream live da Firestore)
// Dà accesso veloce a indirizzo (mappa in-app) e pulsante “Segna consegnato”

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_orders.dart';
import '../common/in_app_map_page.dart'; // webview interna per le mappe

class RiderMyJobsPage extends StatefulWidget {
  const RiderMyJobsPage({super.key});

  @override
  State<RiderMyJobsPage> createState() => _RiderMyJobsPageState();
}

class _RiderMyJobsPageState extends State<RiderMyJobsPage> {
  late final String riderName;

  @override
  void initState() {
    super.initState();
    final u = FirebaseAuth.instance.currentUser;
    final dn = (u?.displayName ?? '').trim();
    // Se non ho displayName prendo la parte prima di @ della mail, altrimenti "Rider"
    riderName = dn.isNotEmpty ? dn : (u?.email?.split('@').first ?? 'Rider');
  }

  /// Marca l’ordine come consegnato e mostra uno snackbar
  Future<void> _deliver(String orderId) async {
    await FirestoreOrders.instance.markDelivered(orderId);
    if (!mounted) return; // evita usare context se il widget è stato smontato
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ordine segnato come consegnato')),
    );
  }

  // ---- Helpers -------------------------------------------------------------

  /// Titolo “umano” dei prodotti:
  /// - se ho items: [{name/brand, qty}] → "Marlboro ×2, Camel ×1"
  /// - altrimenti fallback su brand/quantity
  String _productsTitle(Map<String, dynamic> m) {
    final raw = m['items'];
    if (raw is List) {
      final items = raw.whereType<Map>().toList();
      if (items.isNotEmpty) {
        return items
            .map((it) {
          final name = (it['name'] ?? it['brand'] ?? '').toString();
          final q = (it['qty'] as num?)?.toInt() ?? 1;
          if (name.trim().isEmpty) return null; // skippa item vuoti
          return '$name ×$q';
        })
            .whereType<String>()
            .join(', ');
      }
    }
    final brand = (m['brand'] as String?) ?? 'Carrello';
    final qty = (m['quantity'] as num?)?.toInt() ?? 1;
    return '$brand • x$qty';
  }

  /// Quantità totale complessiva (somma qty su items o usa quantity)
  int _totalQty(Map<String, dynamic> m) {
    final raw = m['items'];
    if (raw is List) {
      final items = raw.whereType<Map>().toList();
      if (items.isNotEmpty) {
        return items.fold<int>(0, (sum, it) => sum + ((it['qty'] as num?)?.toInt() ?? 0));
      }
    }
    return (m['quantity'] as num?)?.toInt() ?? 1;
  }

  /// Data/ora formattata “dd/MM/yyyy alle HH:mm”
  String _fmtDateTime(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} alle ${two(d.hour)}:${two(d.minute)}';
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ultimo incarico')),
      body: StreamBuilder<Map<String, dynamic>?>(
        // Stream: ultimo ordine con acceptedBy == riderName (o null se non c’è)
        stream: FirestoreOrders.instance.watchLatestAcceptedBy(riderName),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator()); // loading iniziale
          }
          if (s.hasError) {
            return Center(child: Text('Errore: ${s.error}'));
          }
          final m = s.data;
          if (m == null) {
            return const Center(child: Text('Nessun incarico al momento.'));
          }

          // Estraggo i campi che mi servono
          final id = m['id'] as String;
          final addr = (m['address'] as String?) ?? '';
          final status = (m['status'] as String?) ?? 'accepted';
          final createdAt = (m['createdAt'] as Timestamp?)?.toDate();

          final title = _productsTitle(m);
          final totalQty = _totalQty(m);
          final delivered = status == 'delivered';

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ListTile(
                leading: CircleAvatar(child: Text(totalQty.toString())), // badge con totale pezzi
                title: Text(title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Indirizzo cliccabile → apre la mappa in-app (stessa azione dell’icona trailing)
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InAppMapPage(address: addr),
                        ),
                      ),
                      child: Text(
                        addr,
                        style: const TextStyle(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      delivered ? 'Consegnato' : 'In consegna',
                      style: TextStyle(color: delivered ? Colors.green : null),
                    ),
                    if (createdAt != null)
                      Text(
                        'Creato il ${_fmtDateTime(createdAt)}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    if (!delivered) ...[
                      const SizedBox(height: 8),
                      // CTA per chiudere la consegna
                      FilledButton.icon(
                        onPressed: () => _deliver(id),
                        icon: const Icon(Icons.check),
                        label: const Text('Segna consegnato'),
                      ),
                    ],
                  ],
                ),
                isThreeLine: true,
                // L’icona fa la STESSA cosa del tap sull’indirizzo: apre la mappa in-app
                trailing: IconButton(
                  tooltip: 'Apri mappa (in-app)',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InAppMapPage(address: addr),
                    ),
                  ),
                  icon: const Icon(Icons.map_outlined),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
