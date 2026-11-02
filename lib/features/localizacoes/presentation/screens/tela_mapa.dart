import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/repositories/repositorio_localizacoes.dart';
import '../../models/localizacao.dart';
import '../../services/cache_mapa.dart';
import '../widgets/mapa_localizacoes.dart';

/// Carrega as últimas 100 posições e mostra no mapa.
class TelaMapa extends StatefulWidget {
  const TelaMapa({super.key});

  @override
  State<TelaMapa> createState() => _TelaMapaState();
}

class _TelaMapaState extends State<TelaMapa> {
  final _repositorio = RepositorioLocalizacoes();

  List<Localizacao> _localizacoes = [];
  MapCachingProvider? _cache;
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final cache = await CacheMapa.preparar();
      final lista = await _repositorio.buscarUltimas();
      if (!mounted) return;
      setState(() {
        _cache = cache;
        _localizacoes = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar as localizações.';
        _carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _conteudo(),
    );
  }

  Widget _conteudo() {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(child: Text(_erro!));
    }
    if (_localizacoes.isEmpty) {
      return const Center(
        child: Text('Nenhuma localização salva. Inicie a coleta primeiro.'),
      );
    }
    // Ao atualizar, o mapa é recriado e enquadra os pontos de novo.
    return MapaLocalizacoes(localizacoes: _localizacoes, cache: _cache!);
  }
}
