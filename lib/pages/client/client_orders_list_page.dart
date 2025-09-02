// Pagina cliente che mostra l’ultimo ordine effettuato
// Osserva lo stream di Firestore, mostra stato (pending/accepted/…) e countdown
// Permette anche di cancellare l’ordine se non ancora accettato/consegnato

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/firestore_orders.dart';
import '../common/in_app_map_page.dart';

class ClientOrdersListPage extends StatefulWidget {
  const ClientOrdersListPage({super.key});

  @override
  State<ClientOrdersListPage> createState() => _ClientOrdersListPageState();
}

class _ClientOrdersListPageState extends State<ClientOrdersListPage> {
  late final String _uid;  // uid dell’utente loggato

  @override
  void initState() {
    super.initState();
    // prendo l’uid dell’utente loggato per filtrare gli ordini
    _uid = FirebaseAuth.instance.currentUser!.uid;   // leggo uid subito all’avvio
  }

  /// Mostra dialog di conferma e poi prova a eliminare l’ordine (solo se cancellabile)
  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(    // apro un AlertDialog di conferma
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina ordine'),    // titolo dialog
        content: const Text('Sei sicuro di voler eliminare questo ordine?'),
        actions: [
          TextButton(   // bottone annulla → ritorna false
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(   // bottone elimina → ritorna true
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    ) ?? false;   // se chiuso senza scelta, considera false

    if (!ok) return;    // se annulla → non fare nulla

    final done = await FirestoreOrders.instance.deleteIfCancellable(
      orderId: id,    // id documento da cancellare
      clientId: _uid,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(   // feedback utente
      SnackBar(
        content: Text(done ? 'Ordine eliminato' : 'Impossibile eliminare'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ultimo ordine')),
      body: StreamBuilder<Map<String, dynamic>?>(
        // ascolta sempre l’ultimo ordine del cliente loggato
        stream: FirestoreOrders.instance.watchLatestClientOrder(_uid),
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());  // loading iniziale
          }
          if (s.hasError) {
            return Center(child: Text('Errore: ${s.error}'));   // mostra errore
          }
          final m = s.data;
          if (m == null) {
            return const Center(child: Text('Nessun ordine ancora.'));
          }

          // estraggo i campi principali dal documento
          final id = m['id'] as String;
          final brand = (m['brand'] as String?) ?? '';
          final qty = (m['quantity'] as num?)?.toInt() ?? 1;
          final addr = (m['address'] as String?) ?? '';
          final status = (m['status'] as String?) ?? 'pending';
          final acceptedBy = (m['acceptedBy'] as String?);
          final createdAt = (m['createdAt'] as Timestamp?)?.toDate();
          final expiresAt = (m['expiresAt'] as Timestamp?)?.toDate();

          // ---- logica “scaduto” lato client ----
          // un ordine è expired se:
          // - status già = 'expired'
          // - status = 'pending' ma expiresAt è già passato
          final now = DateTime.now();   // ora corrente
          final isExpired = status == 'expired' ||
              (status == 'pending' && (expiresAt != null && !expiresAt.isAfter(now)));

          final effectiveStatus = isExpired ? 'expired' : status;   // stato “effettivo” mostrato

          // un ordine si può eliminare solo se ancora pending o expired
          final canDelete = effectiveStatus == 'pending' || effectiveStatus == 'expired';

          return ListView(
            padding: const EdgeInsets.all(12),    // padding lista
            children: [
              ListTile(
                leading: CircleAvatar(child: Text(qty.toString())),
                title: Text('$brand • x$qty'),    // titolo ordine
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // indirizzo cliccabile → apre la mappa in-app
                    GestureDetector(
                      onTap: () {
                        Navigator.push(   // naviga alla webview interna
                          context,
                          MaterialPageRoute(
                            builder: (_) => InAppMapPage(address: addr),    // passa l’indirizzo
                          ),
                        );
                      },
                      child: Text(
                        addr,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,    // ellipsis se lungo
                        style: const TextStyle(
                          height: 1.2,
                          decoration: TextDecoration.underline,   // sottolineato = tappabile
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Riga di stato dinamica (pending/accepted/delivered/expired
                    _StatusLine(
                      status: effectiveStatus,
                      acceptedBy: acceptedBy,
                      createdAt: createdAt, // per barra/tempo
                      expiresAt: expiresAt, // per barra/tempo
                    ),
                  ],
                ),
                isThreeLine: true,    // ListTile alto
                trailing: Wrap(
                  spacing: 8,   // spazio tra icone
                  children: [
                    _stateIcon(effectiveStatus),    // icona stato
                    if (canDelete)    // se cancellabile → mostra cestino
                      IconButton(
                        tooltip: 'Elimina',
                        onPressed: () => _delete(id),   // conferma + elimina
                        icon: const Icon(Icons.delete_outline),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// icona diversa a seconda dello stato dell’ordine
  Widget _stateIcon(String status) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.hourglass_bottom);
      case 'accepted':
        return const Icon(Icons.delivery_dining);
      case 'delivered':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'expired':
        return const Icon(Icons.timer_off, color: Colors.redAccent);
      default:
        return const SizedBox.shrink();   //nessun icona
    }
  }
}

//  WIDGET DI STATO

/// Riga di stato:
/// - pending → barra + countdown
/// - accepted → testo blu con rider
/// - delivered → verde
/// - expired → rosso
class _StatusLine extends StatelessWidget {
  final String status;    // stato testo da mostrare
  final String? acceptedBy;
  final DateTime? createdAt;    // per calcolo progress bar
  final DateTime? expiresAt;

  const _StatusLine({
    required this.status,
    this.acceptedBy,
    this.createdAt,
    this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'pending':
        if (createdAt == null || expiresAt == null) {
          return const Text('In attesa');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MiniCountdownBar(createdAt: createdAt!, expiresAt: expiresAt!),    // barra residua
            const SizedBox(height: 2),
            _CountdownText(expiresAt: expiresAt!),    // testo mm:ss residuo
          ],
        );
      case 'accepted':
        final who = acceptedBy ?? 'rider';    // default in assenza nome
        return Text('Ordine in consegna, preso in carico da $who',
            style: const TextStyle(color: Colors.blue));
      case 'delivered':
        return const Text('Consegna effettuata',
            style: TextStyle(color: Colors.green));
      case 'expired':
        return const Text('Nessun rider ha accettato l’ordine',
            style: TextStyle(color: Colors.red));
      default:
        return Text(status);
    }
  }
}

//COUNTDOWN

class _CountdownText extends StatefulWidget {
  final DateTime expiresAt;   // scadenza
  const _CountdownText({required this.expiresAt});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _t;    // timer per refresh ogni secondo

  @override
  void initState() {
    super.initState();
    // aggiorna ogni secondo
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});   // invalida il widget → rebuild
    });
  }

  @override
  void dispose() {
    _t?.cancel();   // stoppa il timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = max(0, widget.expiresAt.difference(DateTime.now()).inSeconds);    // secondi residui clampati
    final mm = (s ~/ 60).toString().padLeft(2, '0');    // minuti 2 cifre
    final ss = (s % 60).toString().padLeft(2, '0');   // secondi 2 cifre
    return Text(
      'Scade tra $mm:$ss',
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }
}

/// Barra di progresso che decresce linearmente fino allo 0
class _MiniCountdownBar extends StatelessWidget {
  final DateTime createdAt;   // inizio finestra
  final DateTime expiresAt;    // fine finestra

  const _MiniCountdownBar({
    required this.createdAt,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) {
    final total = max(1, expiresAt.difference(createdAt).inSeconds);    // durata totale (>=1s)
    final rem = max(0, expiresAt.difference(DateTime.now()).inSeconds);   // residuo clampato
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),   // bordi arrotondati
      child: TweenAnimationBuilder<double>(   // anima value da begin → end
        tween: Tween(begin: rem / total, end: 0),   // parte da frazione residua e scende
        duration: Duration(seconds: rem),   // durata = tempo residuo
        curve: Curves.linear,   // decrescita lineare
        builder: (_, v, __) =>
            LinearProgressIndicator(value: v, minHeight: 6),    // progress bar
      ),
    );
  }
}

