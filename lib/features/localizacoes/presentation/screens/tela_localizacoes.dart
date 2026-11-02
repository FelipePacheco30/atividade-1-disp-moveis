import 'package:flutter/material.dart';

import '../../data/repositories/repositorio_localizacoes.dart';
import '../../models/localizacao.dart';
import '../widgets/item_localizacao.dart';

/// Histórico: últimas 100 posições, da mais recente para a mais antiga.
class TelaLocalizacoes extends StatefulWidget {
  const TelaLocalizacoes({super.key, required this.coletando});

  final bool coletando; // usado no aviso do diálogo de limpeza

  @override
  State<TelaLocalizacoes> createState() => _TelaLocalizacoesState();
}

class _TelaLocalizacoesState extends State<TelaLocalizacoes> {
  final _repositorio = RepositorioLocalizacoes();

  List<Localizacao> _localizacoes = [];
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
      final lista = await _repositorio.buscarUltimas();
      if (!mounted) return;
      setState(() {
        _localizacoes = lista;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar o histórico.';
        _carregando = false;
      });
    }
  }

  Future<void> _confirmarLimpeza() async {
    final avisoColeta = widget.coletando
        ? '\n\nA coleta está ativa: novas posições continuarão sendo salvas.'
        : '';

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar histórico?'),
        content: Text(
          'Todos os registros serão excluídos permanentemente, inclusive '
          'os que não aparecem nesta lista.$avisoColeta',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar histórico'),
          ),
        ],
      ),
    );

    // null = fechou o diálogo tocando fora dele
    if (confirmou != true) return;

    try {
      await _repositorio.excluirTodas();
      if (!mounted) return;
      _carregar();
      _mostrarMensagem('Histórico apagado.');
    } catch (e) {
      if (!mounted) return;
      _mostrarMensagem('Não foi possível limpar o histórico.');
    }
  }

  void _mostrarMensagem(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
          IconButton(
            onPressed: _localizacoes.isEmpty ? null : _confirmarLimpeza,
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpar histórico',
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
      return const Center(child: Text('Nenhuma localização salva.'));
    }
    return ListView.separated(
      itemCount: _localizacoes.length,
      separatorBuilder: (context, i) => const Divider(height: 1),
      itemBuilder: (context, i) =>
          ItemLocalizacao(localizacao: _localizacoes[i]),
    );
  }
}
