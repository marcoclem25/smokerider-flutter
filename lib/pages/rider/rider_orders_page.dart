// Mostra gli ordini pending in tempo reale al rider (toggle online/offline).
// Puoi aprire la mappa per l’indirizzo e accettare l’ordine, con countdown visivo.

//librerie per timer e funzioni matematiche
import 'dart:async';
import 'dart:math';

//sdk firebase e flutter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

//servizi applicativi
import '../../services/auth_service.dart';
import '../../services/firestore_orders.dart';
import '../../services/prefs.dart';

//webview interna per le mappe
import '../common/in_app_map_page.dart';

// pagina che mostra al rider gli ordini pending in tempo reale e permette di accettarli
class RiderOrdersPage extends StatefulWidget {
  const RiderOrdersPage({super.key});

  @override
  State<RiderOrdersPage> createState() => _RiderOrdersPageState();
}

class _RiderOrdersPageState extends State<RiderOrdersPage> {
  bool online = true;
  String riderName = 'Rider';

  @override
  void initState() {
    super.initState();

    // Derivo un "nome rider" leggibile: displayName → parte prima di @ → fallback "Rider"
    final u = FirebaseAuth.instance.currentUser;
    final dn = (u?.displayName ?? '').trim();
    riderName = dn.isNotEmpty ? dn : (u?.email?.split('@').first ?? 'Rider');

    // IIFE async per caricare lo stato online salvato nelle preferenze locali
    () async {
      final savedOnline = await Prefs.getRiderOnline();
      if (!mounted) return;            // Evita setState se lo screen è stato dismesso
      setState(() => online = savedOnline);
    }();
  }

  Future<void> _accept(String orderId) async {
    // Provo ad accettare con transazione lato server (gestita in FirestoreOrders)
    final ok = await FirestoreOrders.instance.tryAcceptOrder(
      orderId: orderId,
      riderName: riderName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Ordine accettato!' : 'Impossibile accettare.')),
    );
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    // Pulisco lo stack e torno alla root
    Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
  }

  // Titolo leggibile dei prodotti (items moderni → fallback brand/quantity legacy)
  String _productsTitle(Map<String, dynamic> m) {
    final raw = m['items'];
    if (raw is List) {
      final parts = raw
          .whereType<Map>()
          .map((it) {
        final name = (it['name'] ?? it['brand'] ?? '').toString();
        final q = (it['qty'] as num?)?.toInt() ?? 0;
        if (name.trim().isEmpty || q <= 0) return null;
        return '$name ×$q';
      })
          .whereType<String>()
          .toList();
      if (parts.isNotEmpty) return parts.join(', ');
    }
    final brand = (m['brand'] as String?) ?? 'Carrello';
    final qty = (m['quantity'] as num?)?.toInt() ?? 1;
    return '$brand ×$qty';
  }

  // Quantità totale (somma su items o quantity legacy)
  int _totalQty(Map<String, dynamic> m) {
    final raw = m['items'];
    if (raw is List) {
      final tot = raw
          .whereType<Map>()
          .fold<int>(0, (sum, it) => sum + ((it['qty'] as num?)?.toInt() ?? 0));
      if (tot > 0) return tot;
    }
    return (m['quantity'] as num?)?.toInt() ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ordini disponibili'),
        actions: [
          IconButton(
            tooltip: 'I miei incarichi',
            onPressed: () => Navigator.pushNamed(context, '/rider/jobs'),
            icon: const Icon(Icons.assignment_turned_in_outlined),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: Text(
                riderName, // piccolo promemoria di chi è loggato
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // barra stato online/offline
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.black12.withOpacity(0.08)),
              ),
              child: ListTile(
                leading: Icon(
                  online ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: online ? Colors.green : Colors.grey,
                ),
                title: const Text('Stato rider'),
                subtitle: Text(
                  online ? 'Online — visibile ai nuovi ordini'
                      : 'Offline — non ricevi richieste',
                ),
                trailing: Switch(
                  value: online,
                  onChanged: (v) async {
                    setState(() => online = v); // update UX immediato
                    await Prefs.setRiderOnline(v); // persisto la scelta
                  },
                ),
              ),
            ),
          ),

          // lista ordini pending
          Expanded(
            child: online
                ? StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirestoreOrders.instance.watchPending(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Errore: ${snap.error}'));
                }

                // Normalizzo i dati e filtro client-side gli scaduti
                final raw = snap.data ?? [];
                final items = raw
                    .map((m) {
                  final createdAt =
                      (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                  final expiresAt =
                      (m['expiresAt'] as Timestamp?)?.toDate() ??
                          createdAt.add(const Duration(minutes: 10)); // fallback TTL
                  return {
                    'id': m['id'] as String,
                    'address': (m['address'] as String?) ?? '',
                    'createdAt': createdAt,
                    'expiresAt': expiresAt,
                    'raw': m,
                  };
                })
                    .where((o) => (o['expiresAt'] as DateTime).isAfter(DateTime.now()))
                    .toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Nessun ordine disponibile. Vedrai comparire un ordine '
                            'non appena un cliente lo effettuerà.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final o = items[i];
                    final id = o['id'] as String;
                    final addr = o['address'] as String;
                    final createdAt = o['createdAt'] as DateTime;
                    final expiresAt = o['expiresAt'] as DateTime;
                    final rawOrder = (o['raw'] as Map<String, dynamic>);

                    final title = _productsTitle(rawOrder);
                    final totalQty = _totalQty(rawOrder);

                    return ListTile(
                      leading: CircleAvatar(child: Text(totalQty.toString())),
                      title: Text(title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // indirizzo cliccabile → apre la webview interna (stessa UX della jobs page)
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => InAppMapPage(address: addr),
                                ),
                              );
                            },
                            child: Text(
                              addr,
                              style: const TextStyle(
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          _CountdownBar(
                            key: ValueKey(id), // Key stabile per animazione per-item
                            createdAt: createdAt,
                            expiresAt: expiresAt,
                          ),
                          const SizedBox(height: 2),
                          _CountdownText(expiresAt: expiresAt),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: FilledButton(
                        onPressed: () => _accept(id),
                        child: const Text('Accetta'),
                      ),
                    );
                  },
                );
              },
            )
                : const Center(
              child: Text('Sei offline. Imposta Online per ricevere richieste.'),
            ),
          ),
        ],
      ),

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Esci'),
          ),
        ),
      ),
    );
  }
}

// progress bar countdown
class _CountdownBar extends StatelessWidget {
  final DateTime createdAt;
  final DateTime expiresAt;

  const _CountdownBar({
    super.key,
    required this.createdAt,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    // Calcolo quota residua e la animo linearmente fino a 0
    final total = max(1, expiresAt.difference(createdAt).inSeconds);
    final rem = max(0, expiresAt.difference(DateTime.now()).inSeconds);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: rem / total, end: 0),
        duration: Duration(seconds: rem), // durate dinamiche per ogni elemento
        curve: Curves.linear,
        builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6),
      ),
    );
  }
}

// testo countdown mm:ss
class _CountdownText extends StatefulWidget {
  final DateTime expiresAt;
  const _CountdownText({super.key, required this.expiresAt});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // Tick ogni secondo: triggera setState per aggiornare il testo
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = max(0, widget.expiresAt.difference(DateTime.now()).inSeconds);
    final mm = (s ~/ 60).toString().padLeft(2, '0');
    final ss = (s % 60).toString().padLeft(2, '0');
    return Text(
      'Scade tra $mm:$ss',
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }
}
