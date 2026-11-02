import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/localizacao.dart';

/// Mostra os dados de uma localização. Usado no histórico, na tela de coleta
/// e nos detalhes de um marcador do mapa.
class ItemLocalizacao extends StatelessWidget {
  const ItemLocalizacao({super.key, required this.localizacao});

  final Localizacao localizacao;

  static final _formatoData = DateFormat('dd/MM/yyyy HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final dataLocal = localizacao.instante.toLocal();
    final latitude = localizacao.latitude.toStringAsFixed(6);
    final longitude = localizacao.longitude.toStringAsFixed(6);
    final precisao = localizacao.precisao.toStringAsFixed(1);

    return ListTile(
      leading: const Icon(Icons.place_outlined),
      title: Text(_formatoData.format(dataLocal)),
      subtitle: Text(
        'Lat: $latitude   Long: $longitude\nPrecisão: ± $precisao m',
      ),
      isThreeLine: true,
    );
  }
}
