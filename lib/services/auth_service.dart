//gestisce login, registrazione, logout, lettura e aggiornamento dei dati utente

import 'package:cloud_firestore/cloud_firestore.dart';  //per interagire con il database Firestore di Firebase
import 'package:firebase_auth/firebase_auth.dart';    //per gestire autenticazione

class AuthService {   //dichiarazione classe
  AuthService._();    //def costruttore privato. impedisce di creare oggetti AuthService dall’esterno con new AuthService()
  static final instance = AuthService._();    //crea un’unica istanza statica. in tutta l’app ci sarà sempre lo stesso AuthService, richiamabile con AuthService.instance

  //final per valore non modificabile, _ per rendere privato
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  //authStateChanges() emette eventi ogni volta che lo stato dell’utente cambia
  Stream<User?> authState() => _auth.authStateChanges();    //Stream è una sequenza di eventi nel tempo
  User? get currentUser => _auth.currentUser;   //getter per recuperare l’utente attualmente loggato

  Future<void> signIn(String email, String password) async {    //metodo asincrono (Future<void>) che esegue il login
    await _auth.signInWithEmailAndPassword(email: email, password: password); //(il codice aspetta il completamento della chiamata senza bloccare la UI)
  }

  Future<void> signUp({     //metodo asincrono per registrare un nuovo utente
    required String email,
    required String password,
    required String displayName,
    required String role, // 'client' | 'rider'
    bool isAdultConfirmed = false,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(    //crea un nuovo utente in Firebase Auth
      email: email, password: password,   //cred contiene le credenziali dell’utente appena creato
    );
    await cred.user!.updateDisplayName(displayName);  //aggiorna il nome visualizzato dell’utente (! perché user non è null)

    //mappa con dati da salvare in firestore
    final data = <String, dynamic>{
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),    //FieldValue.serverTimestamp() fa inserire la data/ora dal server Firebase
    };
    if (role == 'client') {
      data['isAdultConfirmed'] = isAdultConfirmed; //aggiunge un campo extra isAdultConfirmed nella mappa
    }

    //salva i dati nella collezione users di Firestore
    await _db.collection('users').doc(cred.user!.uid).set(    //doc(cred.user!.uid) usa come ID il codice univoco dell’utente
      data,
      SetOptions(merge: true),    //merge: true unisce i dati nuovi a quelli esistenti, senza cancellarli
    );
  }

  //metodo che recupera il ruolo (client o rider) dell’utente loggato
  Future<String?> fetchRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;    //ritorna una String?
  }

  //aggiorna il nome visualizzato sia in Firebase Auth che nel database Firestore
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _db.collection('users').doc(uid).set(
        {'displayName': name}, SetOptions(merge: true),
      );
    }
  }

  //metodo per fare logout
  Future<void> signOut() => _auth.signOut();
}
