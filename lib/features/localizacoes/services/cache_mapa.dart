import 'package:flutter_map/flutter_map.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class CacheMapa {
  /// Prepara o cache das imagens do mapa numa pasta privada do app.
  /// Deve ser chamado antes de o mapa começar a baixar as imagens.
  /// O cache respeita o tempo de validade enviado pelo servidor do mapa.
  static Future<MapCachingProvider> preparar() async {
    final pastaPrivada = await getApplicationCacheDirectory();
    return BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: join(pastaPrivada.path, 'mapa'),
    );
  }
}
