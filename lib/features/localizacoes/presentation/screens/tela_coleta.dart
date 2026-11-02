import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/repositories/repositorio_localizacoes.dart';
import '../../models/localizacao.dart';
import '../../services/servico_localizacao.dart';
import '../widgets/item_localizacao.dart';
import 'tela_localizacoes.dart';
import 'tela_mapa.dart';

/// Tela inicial: inicia/para a coleta e leva às outras telas.
class TelaColeta extends StatefulWidget {
  const TelaColeta({super.key});

  @override
  State<TelaColeta> createState() => _TelaColetaState();
}

class _TelaColetaState extends State<TelaColeta> {
  final _servico = ServicoLocalizacao();
  final _repositorio = RepositorioLocalizacoes();

  StreamSubscription<Position>? _assinatura; // null = coleta parada
  bool _iniciando = false; // verificando GPS e permissões
  bool _salvando = false; // gravando uma posição no banco
  int _salvasNestaSessao = 0;
  Localizacao? _ultima;

  bool get _coletando => _assinatura != null;

  @override
  void dispose() {
    _assinatura?.cancel();
    super.dispose();
  }

  Future<void> _iniciarColeta() async {
    if (_coletando || _iniciando) return; // evita assinatura duplicada
    setState(() => _iniciando = true);

    try {
      final status = await _servico.verificarPermissao();
      if (!mounted) return;

      if (status != StatusPermissao.concedida) {
        _orientarUsuario(status);
        return;
      }

      _assinatura = _servico.posicoes().listen(
        _salvarPosicao,
        onError: _erroNaLocalizacao,
      );
    } catch (e) {
      if (mounted) _mostrarMensagem('Não foi possível verificar a permissão.');
    } finally {
      // Roda sempre, mesmo depois de um return ou de um erro.
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _pararColeta() async {
    await _assinatura?.cancel(); // encerra o stream e a notificação
    if (!mounted) return;
    setState(() => _assinatura = null);
  }

  /// Chamado pelo stream a cada nova posição.
  Future<void> _salvarPosicao(Position posicao) async {
    if (_salvando) return; // evita gravações sobrepostas
    _salvando = true;

    final localizacao = Localizacao(
      latitude: posicao.latitude,
      longitude: posicao.longitude,
      precisao: posicao.accuracy,
      instante: posicao.timestamp.toUtc(),
    );

    try {
      await _repositorio.inserir(localizacao);
      if (!mounted) return;
      setState(() {
        _ultima = localizacao;
        _salvasNestaSessao++;
      });
    } catch (e) {
      if (mounted) _mostrarMensagem('Erro ao salvar a posição no banco.');
    } finally {
      _salvando = false;
    }
  }

  void _erroNaLocalizacao(Object erro) {
    if (!mounted) return;
    _mostrarMensagem(
      'Falha ao obter a localização. Verifique se o GPS está ligado.',
    );
  }

  void _orientarUsuario(StatusPermissao status) {
    switch (status) {
      case StatusPermissao.gpsDesligado:
        _mostrarMensagem(
          'O GPS está desligado. Ative a localização do aparelho.',
          acao: SnackBarAction(
            label: 'Ativar',
            onPressed: _servico.abrirConfiguracoesDoGps,
          ),
        );
      case StatusPermissao.negada:
        _mostrarMensagem(
          'Permissão negada. A coleta precisa acessar a localização.',
        );
      case StatusPermissao.negadaPermanentemente:
        _mostrarMensagem(
          'Permissão bloqueada. Libere a localização nas configurações do app.',
          acao: SnackBarAction(
            label: 'Abrir',
            onPressed: _servico.abrirConfiguracoesDoApp,
          ),
        );
      case StatusPermissao.concedida:
        break;
    }
  }

  void _mostrarMensagem(String texto, {SnackBarAction? acao}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), action: acao, persist: false),
    );
  }

  void _abrirHistorico() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TelaLocalizacoes(coletando: _coletando),
      ),
    );
  }

  void _abrirMapa() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => const TelaMapa()));
  }

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;

    final String status;
    if (_iniciando) {
      status = 'Verificando permissões...';
    } else if (_coletando) {
      status = 'Coleta em andamento';
    } else {
      status = 'Coleta parada';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Coleta de localização')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: _coletando ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(status, style: textos.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text('Posições salvas nesta sessão: $_salvasNestaSessao'),
          if (_ultima != null) ...[
            const SizedBox(height: 16),
            Text('Última posição salva', style: textos.labelLarge),
            Card.outlined(child: ItemLocalizacao(localizacao: _ultima!)),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _coletando || _iniciando ? null : _iniciarColeta,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Iniciar coleta'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _coletando ? _pararColeta : null,
            icon: const Icon(Icons.stop),
            label: const Text('Parar coleta'),
          ),
          const Divider(height: 40),
          OutlinedButton.icon(
            onPressed: _abrirHistorico,
            icon: const Icon(Icons.list),
            label: const Text('Consultar histórico'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _abrirMapa,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Ver mapa'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _servico.abrirConfiguracoesDoApp,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Configurações de permissão'),
          ),
        ],
      ),
    );
  }
}
