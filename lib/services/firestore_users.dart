// Gestisce i documenti utente su Firestore (collezione `users`)
// Si occupa di creare/aggiornare i dati base come email, nome, ruolo e over18
// metodi per leggere o cambiare il ruolo di un utente

import 'package:cloud_firestore/cloud_firestore.dart'; // sdk firestore
import 'package:firebase_auth/firebase_auth.dart';    // sdk firebase auth per gestire User

/// gestione documenti utente su Firestore.
/// collezione: `users` (doc id = uid)
/// campi principali: email, displayName, role ('client'|'rider'), over18 (bool), createdAt
class FirestoreUsers {
  FirestoreUsers._(); // costruttore privato (pattern singleton)
  static final instance = FirestoreUsers._(); // istanza unica accessibile ovunque

  final _db = FirebaseFirestore.instance; // riferimento al database
  CollectionReference<Map<String, dynamic>> get _col => _db.collection('users');
  // getter: collezione 'users'

  /// crea il documento utente se non esiste
  /// (la logica di aggiornamento è stata commentata perché non serve in questa app)
  Future<void> ensureUserDoc({
    required User user, // utente firebase
    String? role,       // opzionale: ruolo ('client' o 'rider')
    bool? over18,       // opzionale: conferma maggiorenne
  }) async {
    final ref = _col.doc(user.uid); // riferimento al documento con id = uid
    final snap = await ref.get();   // leggi documento
    final now = Timestamp.now();    // timestamp corrente lato server

    if (!snap.exists) {
      // se il documento non esiste → crealo con i dati di base
      await ref.set({
        'email': user.email,
        'displayName': user.displayName,
        'role': role,          // può essere null all’inizio
        'over18': over18,
        'createdAt': now,
      });
    }
    /*  MODIFICA USER
    else {
      // se il documento esiste → aggiorna i campi di base
      final update = <String, dynamic>{
        'email': user.email,
        'displayName': user.displayName,
      };
      if (role != null) update['role'] = role;        // aggiorna ruolo se passato
      if (over18 != null) update['over18'] = over18;  // aggiorna over18 se passato
      await ref.set(update, SetOptions(merge: true)); // merge: aggiorna senza cancellare altri campi
    }
    */
  }

  /// imposta o aggiorna solo il ruolo dell’utente con uid specificato
  Future<void> setRole(String uid, String role) async {
    await _col.doc(uid).set(
      {'role': role},
      SetOptions(merge: true), // aggiorna solo il campo 'role'
    );
  }

  /// legge e restituisce il ruolo dell’utente (stringa 'client' o 'rider')
  /// ritorna null se il campo non esiste
  Future<String?> getRole(String uid) async {
    final d = await _col.doc(uid).get(); // recupera il documento utente
    return (d.data() ?? const {})['role'] as String?; // estrai il campo 'role' se presente
  }
}
