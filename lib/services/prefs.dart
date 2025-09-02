//serve a dare memoria locale e persistente ad alcune impostazioni base dell’utente (nome, stato online, id cliente)
//utile per non dover chiedere ogni volta a Firebase o all’utente le stesse informazioni
//usa il plugin shared_preferences
//  per salvare e leggere dati (chiave → valore) in memoria persistente del dispositivo (rimangono anche dopo che l’utente chiude l’app)

import 'dart:math';   // libreria matematica per usare Random
import 'package:shared_preferences/shared_preferences.dart';    // plugin per salvare dati semplici in locale (key-value persistenti)


class Prefs {
  // chiavi per shared_preferences (usate come identificatori)
  static const _kRiderName   = 'rider_name';   // nome rider
  static const _kRiderOnline = 'rider_online'; // stato online rider
  static const _kClientId    = 'client_id';    // id cliente

  /// legge il nome del rider salvato nelle preferenze (o null se assente)
  static Future<String?> getRiderName() async {
    final p = await SharedPreferences.getInstance(); // ottiene istanza prefs
    return p.getString(_kRiderName); // legge stringa con chiave rider_name
  }

  /// salva il nome del rider nelle preferenze
  static Future<void> setRiderName(String name) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRiderName, name); // scrive stringa con chiave rider_name
  }

  /// legge lo stato online/offline del rider (default = true se non impostato)
  static Future<bool> getRiderOnline() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kRiderOnline) ?? true; // se null ritorna true
  }

  /// salva lo stato online/offline del rider
  static Future<void> setRiderOnline(bool online) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kRiderOnline, online); // scrive bool con chiave rider_online
  }

  /// ottiene l'id del cliente persistente. se non esiste, lo genera e lo salva
  static Future<String> getClientId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(_kClientId); // prova a leggere id salvato
    if (id == null || id.isEmpty) {
      id = _generateClientId(); // se non esiste → genera nuovo id
      await p.setString(_kClientId, id); // salva id nelle prefs
    }
    return id;
  }

  /// genera un nuovo client id casuale (es: client_1724312345678_ab12z)
  static String _generateClientId() {
    final ts = DateTime.now().millisecondsSinceEpoch; // timestamp corrente
    final rand = _randBase36(5); // stringa casuale base36 di 5 caratteri
    return 'client_${ts}_$rand'; // costruisce id finale
  }

  /// genera una stringa randomica in base36 lunga 'len' caratteri
  static String _randBase36(int len) {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz'; // alfabeto base36
    final r = Random.secure(); // random sicuro (crypto)
    // genera lista di len caratteri random presi da chars, poi la unisce
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
