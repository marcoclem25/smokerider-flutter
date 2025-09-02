// Gestisce la collezione `orders` su Firestore
// Crea ordini, li fa accettare ai rider, li marca come consegnati o cancellabili
// stream per vedere ordini pendenti o l’ultimo ordine di cliente/rider


import 'package:cloud_firestore/cloud_firestore.dart';

/// Collezione: `orders`
/// Campi: address, brand, quantity(int), status(pending|accepted|delivered|expired),
/// createdAt(Timestamp), expiresAt(Timestamp), acceptedBy(String?),
/// lat(double?), lng(double?), clientId(String)

class FirestoreOrders {
  FirestoreOrders._();
  static final instance = FirestoreOrders._();

  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('orders');

  Future<String> createOrder({
    // crea un nuovo ordine col clientId, indirizzo, marca e quantità sigarette
    // aggiunge anche timestamp di creazione e di scadenza (10 min di default)
    required String clientId,
    required String address,
    required String brand,
    required int quantity,
    double? lat,
    double? lng,
    int ttlMinutes = 10,
  }) async {
    final now = DateTime.now();
    final expires = now.add(Duration(minutes: ttlMinutes));

    final doc = await _col.add({
      'clientId': clientId,
      'address': address,
      'brand': brand,
      'quantity': quantity,
      'status': 'pending',  // stato iniziale sempre pending
      'createdAt': Timestamp.fromDate(now),
      'expiresAt': Timestamp.fromDate(expires),
      'acceptedBy': null,   // nessun rider all’inizio
      'lat': lat,
      'lng': lng,
    });
    return doc.id; // ritorna l’id dell’ordine creato
  }


  /// Accetta un ordine se ancora pending e non scaduto
  Future<bool> tryAcceptOrder({
    // un rider prova ad accettare un ordine
    // transazione: legge lo stato, controlla che sia pending e non scaduto
    // se valido -> aggiorna status ad 'accepted' e salva il nome del rider
    required String orderId,
    required String riderName,
  }) async {
    final ref = _col.doc(orderId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('Ordine non trovato');
        final data = snap.data() as Map<String, dynamic>;
        final status = (data['status'] as String?) ?? 'pending';
        final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
        final now = DateTime.now();
        final scaduto = expiresAt == null ? false : !expiresAt.isAfter(now);
        if (status != 'pending' || scaduto) {
          throw StateError('Non accettabile');
        }
        tx.update(ref, {'status': 'accepted', 'acceptedBy': riderName});
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markDelivered(String orderId) async {
    // marca un ordine come 'delivered' (consegnato)
    await _col.doc(orderId).update({'status': 'delivered'});
  }


  /// Elimina se non ancora accettato/consegnato (usata dal cliente)
  Future<bool> deleteIfCancellable({
    required String orderId,
    required String clientId,
  }) async {
    final ref = _col.doc(orderId);
    try {
      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) throw StateError('not found');
        final data = snap.data() as Map<String, dynamic>;
        if (data['clientId'] != clientId) throw StateError('forbidden');
        final status = (data['status'] as String?) ?? 'pending';
        if (status == 'accepted' || status == 'delivered') {
          throw StateError('not cancellable');
        }
        tx.delete(ref);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Ordini pending (per lista disponibilità rider)
  Stream<List<Map<String, dynamic>>> watchPending() {
    return _col
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  // STREAM "SOLO ULTIMO"

  ///  stream dell’ultimo ordine di un cliente (anche se pending/accepted/...)
  Stream<Map<String, dynamic>?> watchLatestClientOrder(String clientId) {
    return _col
        .where('clientId', isEqualTo: clientId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((qs) => qs.docs.isEmpty ? null : {'id': qs.docs.first.id, ...qs.docs.first.data()});
  }

  ///  stream dell’ultimo ordine accettato da un rider specifico
  Stream<Map<String, dynamic>?> watchLatestAcceptedBy(String riderName) {
    return _col
        .where('acceptedBy', isEqualTo: riderName)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((qs) => qs.docs.isEmpty ? null : {'id': qs.docs.first.id, ...qs.docs.first.data()});
  }
}
