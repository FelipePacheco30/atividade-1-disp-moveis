import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BancoLocalizacoes {
  static const nomeArquivo = 'localizacoes.db';
  static const versao = 1;
  static const tabela = 'localizacoes';

  static Database? _banco;

  /// Abre o banco na primeira chamada e reutiliza a mesma conexão depois.
  /// Se a abertura falhar, _banco continua null e a próxima chamada tenta de novo.
  static Future<Database> abrir() async {
    if (_banco != null) return _banco!;

    final caminho = join(await getDatabasesPath(), nomeArquivo);
    _banco = await openDatabase(
      caminho,
      version: versao,
      onCreate: _criarTabela,
    );
    return _banco!;
  }

  /// Executado só quando o arquivo do banco ainda não existe.
  static Future<void> _criarTabela(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tabela (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        precisao REAL NOT NULL,
        instante TEXT NOT NULL
      )
    ''');
  }
}
