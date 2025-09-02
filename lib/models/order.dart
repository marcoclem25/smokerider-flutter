//file che definisce l'entità Order


// modello di dominio + enum stato

// enum che rappresenta lo stato di un ordine
// pending   = creato ma non ancora accettato
// accepted  = accettato da un rider
// delivered = consegnato al cliente
// expired   = scaduto senza rider
enum OrderStatus { pending, accepted, delivered, expired }

// classe che rappresenta un ordine
class Order {
  final String id;           // id univoco dell’ordine
  final String address;      // indirizzo di consegna
  final String brand;        // marca/etichetta ordine
  final int quantity;        // quantità pezzi
  final DateTime createdAt;  // istante creazione ordine
  final DateTime expiresAt;  // istante scadenza ordine
  final double? lat;         // latitudine (opzionale)
  final double? lng;         // longitudine (opzionale)
  OrderStatus status;        // stato corrente dell’ordine
  String? acceptedBy;        // nome rider che ha accettato (se presente)

  // costruttore: imposta i valori obbligatori e opzionali
  Order({
    required this.id,
    required this.address,
    required this.brand,
    required this.quantity,
    required this.createdAt,
    required this.expiresAt,
    this.lat,
    this.lng,
    this.status = OrderStatus.pending, // default = pending
    this.acceptedBy,
  });

  /// calcola la durata totale (in secondi) tra creazione e scadenza
  /// se expiresAt <= createdAt, ritorna 600 come fallback di sicurezza
  int get totalSeconds {
    final t = expiresAt.difference(createdAt).inSeconds;
    return t <= 0 ? 600 : t; // fallback: 10 min
  }

  /// calcola il progresso [0..1] da usare in una progress bar countdown
  /// 0 = scaduto, 1 = appena creato
  double get remainingProgress {
    final rem = remainingSeconds; // secondi rimanenti
    if (rem <= 0) return 0;       // già scaduto
    if (rem >= totalSeconds) return 1; // appena creato
    return rem / totalSeconds;    // frazione
  }

  /// calcola quanti secondi mancano alla scadenza. può essere < 0 se ordine già scaduto
  int get remainingSeconds =>
      expiresAt.difference(DateTime.now()).inSeconds;

  /// ritorna il countdown in formato "mm:ss". se scaduto, clamp a "00:00"
  String get remainingMMSS {
    final s = remainingSeconds < 0 ? 0 : remainingSeconds; // clamp min 0
    final mm = (s ~/ 60).toString().padLeft(2, '0');      // minuti
    final ss = (s % 60).toString().padLeft(2, '0');       // secondi
    return '$mm:$ss';                                     // es. "09:32"
  }
}
