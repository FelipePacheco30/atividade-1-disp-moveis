# Localizações

Atividade 1 – Coleta e visualização de localizações
Programação para Dispositivos Móveis I – Prof. Arley – Fatec

## Integrante

- Felipe Ferreira Pacheco

## O que o app faz

Aplicativo Flutter (Android) que coleta a localização do aparelho a cada ~20 segundos
usando um stream, salva cada posição em SQLite (`localizacoes.db`) e mostra o histórico
em uma lista e em um mapa (OpenStreetMap).

## Como executar

```bash
flutter pub get
flutter run
```

## Verificação

```bash
dart format .
flutter analyze
flutter test
```

A explicação completa do código está em [GUIA_DE_ESTUDO.md](GUIA_DE_ESTUDO.md).
