/// Uma posição salva no banco.
class Localizacao {
  final int? id; // null enquanto ainda não foi salva
  final double latitude;
  final double longitude;
  final double precisao; // em metros
  final DateTime instante; // sempre em UTC

  const Localizacao({
    this.id,
    required this.latitude,
    required this.longitude,
    required this.precisao,
    required this.instante,
  });

  /// Converte para o formato que o SQLite grava.
  Map<String, Object?> paraMapa() {
    return {
      if (id != null) 'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'precisao': precisao,
      'instante': instante.toUtc().toIso8601String(),
    };
  }

  /// Cria uma Localizacao a partir de uma linha lida do SQLite.
  factory Localizacao.deMapa(Map<String, Object?> mapa) {
    return Localizacao(
      id: mapa['id'] as int,
      latitude: (mapa['latitude'] as num).toDouble(),
      longitude: (mapa['longitude'] as num).toDouble(),
      precisao: (mapa['precisao'] as num).toDouble(),
      instante: DateTime.parse(mapa['instante'] as String),
    );
  }
}
