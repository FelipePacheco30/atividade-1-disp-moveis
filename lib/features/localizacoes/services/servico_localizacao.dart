import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Resultado da verificação feita antes de iniciar a coleta.
enum StatusPermissao { concedida, gpsDesligado, negada, negadaPermanentemente }

class ServicoLocalizacao {
  /// Confere se o GPS está ligado e pede a permissão de localização se preciso.
  Future<StatusPermissao> verificarPermissao() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return StatusPermissao.gpsDesligado;
    }

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      return StatusPermissao.negada;
    }
    if (permissao == LocationPermission.deniedForever) {
      return StatusPermissao.negadaPermanentemente;
    }

    // Android 13+: sem esta permissão a notificação da coleta não aparece.
    // A coleta funciona mesmo se o usuário recusar.
    await Permission.notification.request();
    return StatusPermissao.concedida;
  }

  /// Stream que entrega uma nova posição a cada ~20 segundos.
  /// No Android, enquanto alguém escuta o stream, o geolocator mantém
  /// um serviço em primeiro plano com uma notificação fixa.
  Stream<Position> posicoes() {
    final configuracao = AndroidSettings(
      accuracy: LocationAccuracy.high,
      intervalDuration: const Duration(seconds: 20),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Coleta de localização ativa',
        notificationText: 'As posições estão sendo salvas no histórico.',
        notificationChannelName: 'Coleta de localização',
        notificationIcon: AndroidResource(
          name: 'icone_localizacoes',
          defType: 'drawable',
        ),
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
    return Geolocator.getPositionStream(locationSettings: configuracao);
  }

  Future<bool> abrirConfiguracoesDoApp() => Geolocator.openAppSettings();

  Future<bool> abrirConfiguracoesDoGps() => Geolocator.openLocationSettings();
}
