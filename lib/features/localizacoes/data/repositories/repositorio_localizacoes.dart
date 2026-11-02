import '../../models/localizacao.dart';
import '../database/banco_localizacoes.dart';

/// Único lugar do app que lê e escreve na tabela de localizações.
class RepositorioLocalizacoes {
  Future<void> inserir(Localizacao localizacao) async {
    final db = await BancoLocalizacoes.abrir();
    await db.insert(BancoLocalizacoes.tabela, localizacao.paraMapa());
  }

  /// Últimos registros, do mais recente para o mais antigo.
  /// O id cresce a cada inserção, então o maior id é o mais recente.
  Future<List<Localizacao>> buscarUltimas({int limite = 100}) async {
    final db = await BancoLocalizacoes.abrir();
    final linhas = await db.query(
      BancoLocalizacoes.tabela,
      orderBy: 'id DESC',
      limit: limite,
    );
    return linhas.map(Localizacao.deMapa).toList();
  }

  /// Apaga todas as linhas. A tabela e o arquivo do banco continuam existindo.
  Future<void> excluirTodas() async {
    final db = await BancoLocalizacoes.abrir();
    await db.delete(BancoLocalizacoes.tabela);
  }
}
