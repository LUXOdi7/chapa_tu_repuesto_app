import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../../shared/widgets/app_widgets.dart';

/// Barra de busqueda con dictado real (`speech_to_text`).
///
/// El texto reconocido va tal cual al parametro `q` del catalogo: el backend ya
/// hace busqueda por texto libre, la app no lo interpreta.
class VoiceSearchBar extends StatefulWidget {
  const VoiceSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  State<VoiceSearchBar> createState() => _VoiceSearchBarState();
}

/// Mensaje legible para el usuario a partir del codigo que devuelve el
/// reconocedor (Web Speech API en Chrome, SpeechRecognizer en Android).
String speechErrorText(String code) => switch (code) {
  'not-allowed' || 'service-not-allowed' || 'permission' =>
    'El navegador bloqueó el micrófono. Permítelo en el candado de la barra '
        'de direcciones. En web la página debe abrirse en localhost o con https.',
  'audio-capture' => 'No se detectó ningún micrófono conectado.',
  // Brave bloquea el servicio de voz de Google por privacidad: la API
  // existe (es Chromium) pero nunca devuelve audio y suele dar `network`.
  'network' =>
    'El navegador no pudo usar el servicio de dictado. Si usas '
        'Brave, actívalo en brave://settings/privacy (o Menú → Escudos) y '
        'recarga; si no, revisa tu conexión a internet.',
  'no-speech' || 'error_speech_timeout' =>
    'No se escuchó nada. Acércate al micrófono e inténtalo otra vez.',
  'not supported' || 'speech_not_supported' =>
    'Este navegador no soporta dictado. Usa Chrome o Edge.',
  _ => 'No se pudo usar el micrófono ($code).',
};

class _VoiceSearchBarState extends State<VoiceSearchBar> {
  final _speech = SpeechToText();

  /// Estado del reconocedor para la hoja: 'listening', 'notListening', 'done'
  /// o `error:<codigo>`. Sin esto la hoja se quedaba en "Escuchando..." para
  /// siempre cuando el navegador negaba el micrófono.
  final _status = ValueNotifier<String>('');
  String? _locale;
  bool _ready = false;

  @override
  void dispose() {
    _speech.cancel();
    _status.dispose();
    super.dispose();
  }

  /// `initialize` es quien pide el permiso de microfono en Android; solo hace
  /// falta la primera vez.
  Future<bool> _ensureReady() async {
    if (_ready) return true;
    _ready = await _speech.initialize(
      onError: (e) => _status.value = 'error:${e.errorMsg}',
      onStatus: (s) => _status.value = s,
    );
    if (_ready) {
      // Sin idioma explicito, en web se usa el del navegador: con Chrome en
      // ingles el dictado en español no reconoce nada.
      final locales = await _speech.locales();
      final es = locales.where(
        (l) => l.localeId.toLowerCase().startsWith('es'),
      );
      _locale = es.isNotEmpty
          ? es.first.localeId
          : (kIsWeb ? 'es-PE' : 'es_PE');
    }
    return _ready;
  }

  Future<void> _dictate() async {
    if (!await _ensureReady()) {
      if (mounted) {
        final code = _status.value.startsWith('error:')
            ? _status.value.substring(6)
            : 'not supported';
        showInfo(context, speechErrorText(code));
      }
      return;
    }
    if (!mounted) return;
    _status.value = '';

    final heard = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      builder: (_) =>
          _ListeningSheet(speech: _speech, status: _status, localeId: _locale),
    );
    await _speech.stop();

    if (heard == null || heard.isEmpty || !mounted) return;
    widget.controller.text = heard;
    widget.onChanged(heard);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Ej: pastillas de freno para Pulsar 200 del 2020',
        hintStyle: const TextStyle(fontSize: 13),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.controller.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Limpiar',
                onPressed: () {
                  widget.controller.clear();
                  widget.onChanged('');
                },
              ),
            IconButton.filled(
              icon: const Icon(Icons.mic),
              tooltip: 'Buscar por voz',
              // Ambar de marca: el azul sobre azul del default M3 casi no se ve
              // en tema oscuro, y este es el boton estrella de la pantalla.
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.white,
              ),
              onPressed: _dictate,
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

/// Hoja de escucha: muestra la transcripcion parcial y se cierra sola cuando el
/// reconocedor da el resultado final.
class _ListeningSheet extends StatefulWidget {
  const _ListeningSheet({
    required this.speech,
    required this.status,
    this.localeId,
  });

  final SpeechToText speech;
  final ValueNotifier<String> status;
  final String? localeId;

  @override
  State<_ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<_ListeningSheet> {
  String _partial = '';
  String? _error;

  /// Algunos navegadores (Brave) no emiten ni audio ni error: sin esto la hoja
  /// se queda "Escuchando..." sin explicar nada.
  Timer? _silence;
  bool _silent = false;

  /// La hoja tiene TRES formas de cerrarse (boton, resultado final del
  /// reconocedor y cambio de estado a `done`/`notListening`) y en Android
  /// llegan casi juntas: al tocar "Usar lo dictado", el `stop()` del
  /// reconocedor dispara el estado y se llamaba a `Navigator.pop` por segunda
  /// vez mientras el primero seguia en curso ->
  /// `Failed assertion: '!_debugLocked'`. Un unico punto de salida, con
  /// cerrojo, lo evita.
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    widget.status.addListener(_onStatus);
    _silence = Timer(const Duration(seconds: 8), () {
      if (mounted && _partial.isEmpty && _error == null) {
        setState(() => _silent = true);
      }
    });
    widget.speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        localeId: widget.localeId,
        listenFor: const Duration(seconds: 30),
        // `pauseFor` se reinicia con los eventos de nivel de sonido, que la
        // Web Speech API no emite: en web cortaba la escucha a los 3 s aunque
        // el usuario todavia no hubiera empezado a hablar.
        pauseFor: kIsWeb ? null : const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  @override
  void dispose() {
    _silence?.cancel();
    widget.status.removeListener(_onStatus);
    super.dispose();
  }

  /// Unico punto de salida de la hoja. El cerrojo `_closed` garantiza un solo
  /// `pop`, venga del boton, del resultado final o del cambio de estado.
  void _close(String? heard) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context, heard);
  }

  /// El reconocedor avisa por aqui: error (permiso, sin micro, silencio) o
  /// fin de la escucha. Sin esto la hoja se quedaba colgada en "Escuchando...".
  void _onStatus() {
    if (!mounted || _closed) return;
    final value = widget.status.value;
    if (value.startsWith('error:')) {
      setState(() => _error = speechErrorText(value.substring(6)));
      return;
    }
    if (value == 'done' || value == 'notListening') _close(_partial);
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted || _closed) return;
    setState(() => _partial = result.recognizedWords);
    if (result.finalResult) _close(result.recognizedWords);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      // Scroll: la hoja no puede pasar de media pantalla y con el aviso de
      // error o el de "no se recibe audio" el contenido se desbordaba por
      // abajo (y tapaba los botones) en celulares chicos.
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: scheme.secondary,
              child: const Icon(Icons.mic, size: 34, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              _error == null ? 'Escuchando...' : 'Micrófono',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error ??
                  (_partial.isEmpty
                      ? 'Di una frase completa: repuesto, marca, modelo y año.\n'
                            'Ej: "kit de arrastre para Honda XR 150 del 2018"'
                      : _partial),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: _error != null
                    ? scheme.error
                    : (_partial.isEmpty ? scheme.outline : scheme.primary),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_silent && _error == null) ...[
              const SizedBox(height: 10),
              Text(
                'No se está recibiendo audio. Algunos navegadores (Brave, Firefox) '
                'bloquean el dictado: prueba en Chrome o escribe tu búsqueda.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: scheme.error),
              ),
            ],
            const SizedBox(height: 20),
            if (_error == null) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _close(null),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => _close(_partial),
                  child: const Text('Usar lo dictado'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
