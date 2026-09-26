import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

/// Boton oficial de Google (popup). En web es el flujo recomendado: no
/// depende del One Tap/FedCM ni de tener sesion abierta en el navegador.
Widget googleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    text: web.GSIButtonText.continueWith,
    shape: web.GSIButtonShape.pill,
  ),
);
