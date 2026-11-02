import 'package:flutter_test/flutter_test.dart';
import 'package:localizacoes/features/localizacoes/models/localizacao.dart';

void main() {
  test('converte para mapa e volta sem perder dados', () {
    final original = Localizacao(
      latitude: -23.550520,
      longitude: -46.633308,
      precisao: 4.5,
      instante: DateTime.utc(2026, 11, 2, 15, 30),
    );

    final mapa = original.paraMapa();
    expect(mapa.containsKey('id'), isFalse);
    expect(mapa['instante'], '2026-11-02T15:30:00.000Z');

    final lida = Localizacao.deMapa({...mapa, 'id': 1});
    expect(lida.id, 1);
    expect(lida.latitude, original.latitude);
    expect(lida.longitude, original.longitude);
    expect(lida.precisao, original.precisao);
    expect(lida.instante, original.instante);
    expect(lida.instante.isUtc, isTrue);
  });
}
