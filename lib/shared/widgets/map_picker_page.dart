import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa OpenStreetMap (sin API key). Funciona igual en Android y web.
///
/// [MapPickerPage] deja tocar el mapa para fijar la ubicacion de la tienda y
/// devuelve el `LatLng` elegido (null si se cancela). [StoreMap] es el mapa
/// solo-lectura con el marcador, para la ficha de la tienda.
///
/// Uso de tiles de OSM: obligatorio identificar la app (userAgentPackageName)
/// y volumen moderado. Ver solicitud_servicios.md en el backend para pasar a
/// un proveedor de tiles con clave si crece el trafico.
const kOsmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const kUserAgent = 'com.negocios.chapaturepuesto';
// Centro por defecto: Chiclayo.
const kDefaultCenter = LatLng(-6.7714, -79.8409);

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key, this.initial});

  final LatLng? initial;

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  late LatLng? _picked = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ubicación de la tienda'),
        actions: [
          TextButton(
            onPressed: _picked == null
                ? null
                : () => Navigator.pop(context, _picked),
            child: const Text('Usar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Toca el mapa sobre tu local. Puedes arrastrar y hacer zoom.',
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: widget.initial ?? kDefaultCenter,
                initialZoom: widget.initial == null ? 13 : 16,
                onTap: (_, point) => setState(() => _picked = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: kOsmTiles,
                  userAgentPackageName: kUserAgent,
                ),
                if (_picked != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _picked!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          size: 40,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          if (_picked != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

/// Mapa fijo con el marcador de la tienda (ficha publica).
class StoreMap extends StatelessWidget {
  const StoreMap({super.key, required this.point, this.height = 180});

  final LatLng point;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: FlutterMap(
      options: MapOptions(
        initialCenter: point,
        initialZoom: 16,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(urlTemplate: kOsmTiles, userAgentPackageName: kUserAgent),
        MarkerLayer(
          markers: [
            Marker(
              point: point,
              width: 40,
              height: 40,
              alignment: Alignment.topCenter,
              child: const Icon(Icons.location_on, size: 40, color: Colors.red),
            ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
        ),
      ],
    ),
  );
}
