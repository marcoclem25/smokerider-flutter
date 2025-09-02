// per mostra Google Maps in una WebView interna
// Gestisce i link (intent, geo, comgooglemaps) aprendoli nelle app native
// Permette al rider di vedere l’indirizzo senza uscire dall’app

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class InAppMapPage extends StatelessWidget {
  final String address;
  const InAppMapPage({super.key, required this.address});

  @override
  Widget build(BuildContext context) {
    final q = Uri.encodeComponent(address.trim());
    // URL web “puro”, viene caricato nella WebView interna
    final startUrl = 'https://www.google.com/maps/search/?api=1&query=$q&hl=it';

    // 1) crea il controller per la WebView
    final controller = WebViewController();

    // 2) funzione helper per gestire i link cliccati nella WebView
    Future<NavigationDecision> _onNav(NavigationRequest request) async {
      final url = request.url;

      // Caso chiave: il pulsante "Apri app" su Android usa intent://
      if (url.startsWith('intent://')) {
        await _openInMaps(address); // → apri direttamente nell’app di mappe
        return NavigationDecision.prevent;
      }

      // blocca schemi non http/https (es. geo:, comgooglemaps:)
      final uri = Uri.parse(url);
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        // prova ad aprire il deep link nell’app esterna
        await _safeLaunch(uri, preferNonBrowser: true);
        return NavigationDecision.prevent;
      }

      return NavigationDecision.navigate; // altrimenti continua nella WebView
    }

    // 3) setup del controller
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.setBackgroundColor(const Color(0x00000000));
    controller.setNavigationDelegate(
      NavigationDelegate(onNavigationRequest: _onNav),
    );
    controller.loadRequest(Uri.parse(startUrl));

    return Scaffold(
      appBar: AppBar(title: const Text('Mappa')),
      body: WebViewWidget(controller: controller),
    );
  }

  /// apre l’indirizzo nell’app di mappe nativa (Google Maps su Android, Apple Maps su iOS)
  Future<void> _openInMaps(String address) async {
    final q = Uri.encodeComponent(address.trim());

    if (Platform.isAndroid) {
      if (await _safeLaunch(Uri.parse('geo:0,0?q=$q'), preferNonBrowser: true)) return;
      if (await _safeLaunch(Uri.parse('comgooglemaps://?q=$q'), preferNonBrowser: true)) return;
      await _safeLaunch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'));
      return;
    }

    if (Platform.isIOS) {
      if (await _safeLaunch(Uri.parse('comgooglemaps://?q=$q'), preferNonBrowser: true)) return;
      if (await _safeLaunch(Uri.parse('http://maps.apple.com/?q=$q'))) return;
      await _safeLaunch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'));
      return;
    }

    // fallback per altre piattaforme
    await _safeLaunch(Uri.parse('https://www.google.com/maps/search/?api=1&query=$q'));
  }

  /// prova ad aprire un link esterno; se preferNonBrowser=true evita browser e custom tabs
  Future<bool> _safeLaunch(Uri uri, {bool preferNonBrowser = false}) async {
    try {
      final mode = preferNonBrowser
          ? LaunchMode.externalNonBrowserApplication
          : LaunchMode.externalApplication;
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }
}
