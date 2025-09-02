// Store in memoria che gestisce gli ordini
// Tiene la lista ordini, aggiorna i pending → expired e notifica la UI
// metodi per creare, accettare e marcare consegnati gli ordini

import 'dart:async';                     // serve per Timer
import 'package:flutter/foundation.dart'; // ChangeNotifier e notifyListeners
import '../models/order.dart';           // modello Order (id, address, status, ecc.)

// classe che mantiene in memoria la lista ordini e notifica la UI ai cambiamenti
class OrderStore extends ChangeNotifier {
  final List<Order> _orders = []; // lista privata di ordini
  Timer? _ticker;                 // timer che scatta ogni secondo

  // costruttore privato: avvia un timer che ogni secondo controlla gli ordini pending
  // e li segna come expired se superano la scadenza
  OrderStore._internal() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final o in _orders) {
        if (o.status == OrderStatus.pending &&
            o.expiresAt.isBefore(DateTime.now())) {
          o.status = OrderStatus.expired; // scaduto
        }
      }
      notifyListeners(); // notifica la UI che c’è stato un cambiamento
    });
  }

  // istanza singleton accessibile ovunque
  static final OrderStore instance = OrderStore._internal();

  /// restituisce lista ordini cliente in sola lettura (unmodifiable)
  List<Order> get clientOrders => List.unmodifiable(_orders);

  /// restituisce lista ordini disponibili per rider (solo pending e non scaduti)
  List<Order> get riderAvailable => _orders
      .where((o) => o.status == OrderStatus.pending && o.expiresAt.isAfter(DateTime.now()))
      .toList();

  /// crea un nuovo ordine e lo inserisce in cima alla lista
  void createOrder({
    required String address,
    required String brand,
    required int quantity,
    double? lat,           // coordinate opzionali
    double? lng,
  }) {
    final now = DateTime.now(); // timestamp corrente
    final newOrder = Order(
      id: 'ord_${now.microsecondsSinceEpoch}', // id univoco basato sul tempo
      address: address,
      brand: brand,
      quantity: quantity,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)), // scadenza 10 minuti
      lat: lat,
      lng: lng,
    );
    _orders.insert(0, newOrder); // aggiunge ordine in testa alla lista
    notifyListeners(); // notifica la UI
  }

  /// prova ad accettare un ordine: ritorna true se accettato correttamente
  bool acceptOrder(String id, String riderName) {
    final i = _orders.indexWhere((o) => o.id == id); // cerca indice ordine
    if (i == -1) return false;                       // non trovato
    final o = _orders[i];
    if (o.status == OrderStatus.pending && o.expiresAt.isAfter(DateTime.now())) {
      o.status = OrderStatus.accepted;
      o.acceptedBy = riderName; // assegna rider
      notifyListeners();
      return true;
    }
    return false; // se già scaduto o non pending
  }

  /// marca un ordine come consegnato (solo se era accettato)
  void markDelivered(String id) {
    final i = _orders.indexWhere((o) => o.id == id);
    if (i == -1) return; // non trovato
    final o = _orders[i];
    if (o.status == OrderStatus.accepted) {
      o.status = OrderStatus.delivered;
      notifyListeners();
    }
  }

  // ferma il timer quando non serve più e libera risorse
  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
