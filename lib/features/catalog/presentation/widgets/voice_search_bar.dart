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

class _VoiceSearchBarState extends State<VoiceSearchBar> {
  final _speech = SpeechToText();
  bool _ready = false;

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  /// `initialize` es quien pide el permiso de microfono en Android; solo hace
  /// falta la primera vez.
  Future<bool> _ensureReady() async {
    if (_ready) return true;
    _ready = await _speech.initialize();
    return _ready;
  }

  Future<void> _dictate() async {
    if (!await _ensureReady()) {
      if (mounted) {
        showInfo(context,
            'No pudimos usar el micrófono. Revisa el permiso de audio.');
      }
      return;
    }
    if (!mounted) return;

    final heard = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      builder: (_) => _ListeningSheet(speech: _speech),
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
  const _ListeningSheet({required this.speech});

  final SpeechToText speech;

  @override
  State<_ListeningSheet> createState() => _ListeningSheetState();
}

class _ListeningSheetState extends State<_ListeningSheet> {
  String _partial = '';

  @override
  void initState() {
    super.initState();
    widget.speech.listen(
      onResult: _onResult,
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
      ),
    );
  }

  void _onResult(SpeechRecognitionResult result) {
    if (!mounted) return;
    setState(() => _partial = result.recognizedWords);
    if (result.finalResult) Navigator.pop(context, result.recognizedWords);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
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
            Text('Escuchando...',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _partial.isEmpty
                  ? 'Di una frase completa: repuesto, marca, modelo y año.\n'
                      'Ej: "kit de arrastre para Honda XR 150 del 2018"'
                  : _partial,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _partial.isEmpty ? scheme.outline : scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _partial),
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
