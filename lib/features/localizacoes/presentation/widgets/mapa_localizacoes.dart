import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/localizacao.dart';
import 'item_localizacao.dart';

/// Mapa com as ruas do OpenStreetMap e um marcador por localização.
/// Espera a lista ordenada da mais recente para a mais antiga.
class MapaLocalizacoes extends StatefulWidget {
  const MapaLocalizacoes({
    super.key,
    required this.localizacoes,
    required this.cache,
  });

  final List<Localizacao> localizacoes;
  final MapCachingProvider cache;

  @override
  State<MapaLocalizacoes> createState() => _MapaLocalizacoesState();
}

class _MapaLocalizacoesState extends State<MapaLocalizacoes> {
  final _controlador = MapController();
  late final _imagens = NetworkTileProvider(cachingProvider: widget.cache);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  /// Posição da câmera que mostra todos os pontos de uma vez.
  CameraFit get _enquadramento {
    return CameraFit.coordinates(
      coordinates: [
        for (final l in widget.localizacoes) LatLng(l.latitude, l.longitude),
      ],
      padding: const EdgeInsets.all(48),
      maxZoom: 17,
    );
  }

  void _enquadrarTodos() {
    _controlador.fitCamera(_enquadramento);
  }

  void _mostrarDetalhes(Localizacao localizacao) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ItemLocalizacao(localizacao: localizacao),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maisRecente = widget.localizacoes.first;

    return Stack(
      children: [
        FlutterMap(
          mapController: _controlador,
          options: MapOptions(initialCameraFit: _enquadramento),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'br.fatec.localizacoes',
              tileProvider: _imagens,
            ),
            MarkerLayer(
              markers: [
                // De trás para frente: a mais recente é desenhada por último
                // e fica por cima das outras.
                for (final l in widget.localizacoes.reversed)
                  Marker(
                    point: LatLng(l.latitude, l.longitude),
                    width: 36,
                    height: 36,
                    alignment: Alignment.topCenter, // ponta do pino no ponto
                    child: GestureDetector(
                      onTap: () => _mostrarDetalhes(l),
                      child: Icon(
                        Icons.location_on,
                        size: 36,
                        color: l == maisRecente
                            ? Colors.red
                            : Colors.blueGrey.shade700,
                      ),
                    ),
                  ),
              ],
            ),
            RichAttributionWidget(
              attributions: [
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () => launchUrl(
                    Uri.parse('https://www.openstreetmap.org/copyright'),
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            onPressed: _enquadrarTodos,
            tooltip: 'Enquadrar todos os pontos',
            child: const Icon(Icons.fit_screen),
          ),
        ),
      ],
    );
  }
}
