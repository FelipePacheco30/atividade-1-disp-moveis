# Guia de estudo — App Localizações

Este guia explica o app inteiro, arquivo por arquivo e função por função, em linguagem simples.
No final tem um checklist dos requisitos do PDF e **exercícios no estilo da prova** (completar trechos), com gabarito.

---

## Sumário

1. [O que o app faz](#1-o-que-o-app-faz)
2. [Mapa do projeto](#2-mapa-do-projeto)
3. [Como as peças conversam](#3-como-as-peças-conversam)
4. [Dependências (pubspec.yaml)](#4-dependências-pubspecyaml)
5. [Arquivo por arquivo](#5-arquivo-por-arquivo)
6. [Navegação entre telas (as "rotas")](#6-navegação-entre-telas-as-rotas)
7. [Parte Android: permissões, serviço em primeiro plano e ícone](#7-parte-android)
8. [Fluxos completos, passo a passo](#8-fluxos-completos-passo-a-passo)
9. [Conceitos de Dart/Flutter que aparecem no código](#9-conceitos-de-dartflutter-que-aparecem-no-código)
10. [Checklist: requisito do PDF → onde está no código](#10-checklist-requisito-do-pdf--onde-está-no-código)
11. [Exercícios estilo prova (com gabarito)](#11-exercícios-estilo-prova)

---

## 1. O que o app faz

- Na **tela inicial** o usuário toca em **Iniciar coleta**.
- O app confere se o GPS está ligado e se tem permissão de localização.
- Se estiver tudo certo, ele começa a **escutar um stream** (um "cano" que vai soltando posições ao longo do tempo). O intervalo pedido é de **20 segundos**.
- **Cada posição** que chega é **salva no SQLite** (banco `localizacoes.db`, tabela `localizacoes`).
- Enquanto coleta, o Android mostra uma **notificação fixa** (serviço em primeiro plano). Isso permite continuar coletando com o app minimizado.
- **Parar coleta** cancela o stream → a notificação some.
- **Consultar histórico** mostra as últimas 100 posições numa lista, com botão de atualizar e de limpar tudo.
- **Ver mapa** mostra as últimas 100 posições como marcadores num mapa do OpenStreetMap. A mais recente fica **vermelha**.
- **Configurações de permissão** abre a tela de configurações do app no Android.

---

## 2. Mapa do projeto

```
lib/
├── main.dart                         → liga o Flutter e roda o App
├── app.dart                          → MaterialApp (tema + tela inicial)
└── features/localizacoes/
    ├── models/
    │   └── localizacao.dart          → classe Localizacao (os dados de 1 posição)
    ├── data/
    │   ├── database/
    │   │   └── banco_localizacoes.dart     → abre o banco e cria a tabela
    │   └── repositories/
    │       └── repositorio_localizacoes.dart → inserir, buscar e excluir
    ├── services/
    │   ├── servico_localizacao.dart  → GPS, permissões, stream de posições
    │   └── cache_mapa.dart           → pasta de cache das imagens do mapa
    └── presentation/
        ├── screens/
        │   ├── tela_coleta.dart      → tela inicial (iniciar/parar + botões)
        │   ├── tela_localizacoes.dart→ histórico (lista)
        │   └── tela_mapa.dart        → carrega dados e mostra o mapa
        └── widgets/
            ├── item_localizacao.dart → mostra 1 localização (reutilizado)
            └── mapa_localizacoes.dart→ o mapa em si (ruas + marcadores)

assets/icons/localizacoes.png         → imagem original do ícone (1024x1024)
android/app/src/main/AndroidManifest.xml → permissões e ícone do app
android/app/src/main/res/...          → arquivos do ícone em cada tamanho
test/localizacao_test.dart            → teste da conversão do modelo
```

**Regra de ouro da organização:** cada pasta tem um papel.

| Pasta | Papel | Pode falar com |
|---|---|---|
| `models` | Só descreve os dados | ninguém |
| `data/database` | Abre o SQLite | sqflite |
| `data/repositories` | Faz o SQL (insert/query/delete) | o banco |
| `services` | Fala com o sistema (GPS, permissões, pastas) | geolocator, path_provider |
| `presentation` | Telas e widgets | repositório e serviços |

> As **telas nunca escrevem SQL**. Elas pedem ao repositório: `_repositorio.inserir(...)`, `_repositorio.buscarUltimas()`, `_repositorio.excluirTodas()`.

---

## 3. Como as peças conversam

```
                 ┌───────────────────────┐
                 │      TelaColeta       │  (tela inicial)
                 └──────────┬────────────┘
     verificarPermissao()   │    inserir(localizacao)
     posicoes() (stream)    │
          ┌─────────────────┴──────────────┐
          ▼                                ▼
 ┌──────────────────┐            ┌────────────────────────┐
 │ServicoLocalizacao│            │RepositorioLocalizacoes │
 │  (geolocator)    │            │  insert/query/delete   │
 └──────────────────┘            └───────────┬────────────┘
                                             │ abrir()
                                             ▼
                                 ┌────────────────────────┐
                                 │   BancoLocalizacoes    │
                                 │   localizacoes.db      │
                                 └────────────────────────┘

TelaLocalizacoes ──buscarUltimas()/excluirTodas()──► Repositório
TelaMapa ──CacheMapa.preparar()──► pasta de cache
         ──buscarUltimas()──► Repositório
         └──► MapaLocalizacoes (widget) ──► ItemLocalizacao (ao tocar no marcador)
```

O objeto que viaja entre as camadas é sempre um **`Localizacao`** (nunca o `Map` cru do SQLite).

---

## 4. Dependências (pubspec.yaml)

| Pacote | Para que usamos | Onde |
|---|---|---|
| `geolocator` | GPS ligado?, permissão, **stream de posições**, abrir configurações, serviço em primeiro plano | `servico_localizacao.dart`, `tela_coleta.dart` (tipo `Position`) |
| `permission_handler` | Pedir permissão de **notificação** (Android 13+) | `servico_localizacao.dart` |
| `sqflite` | Banco SQLite | `banco_localizacoes.dart` |
| `path` | `join()` para montar caminhos de arquivo | banco e cache |
| `path_provider` | Descobrir a pasta privada de cache do app | `cache_mapa.dart` |
| `flutter_map` | Widget de mapa, camada de ruas, marcadores, cache | `mapa_localizacoes.dart`, `tela_mapa.dart`, `cache_mapa.dart` |
| `latlong2` | Classe `LatLng` (latitude + longitude) que o flutter_map usa | `mapa_localizacoes.dart` |
| `intl` | `DateFormat` para formatar data/hora | `item_localizacao.dart` |
| `url_launcher` | Abrir o link de atribuição do OpenStreetMap | `mapa_localizacoes.dart` |
| `flutter_lints` (dev) | Regras do `flutter analyze` | `analysis_options.yaml` |
| `flutter_test` (dev) | Teste do modelo | `test/` |

---

## 5. Arquivo por arquivo

### 5.1 `lib/main.dart`

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}
```

- `main()` é a primeira função que roda.
- `WidgetsFlutterBinding.ensureInitialized()` "liga" o Flutter (prepara a ligação com o sistema). É obrigatório quando se usa plugins antes do `runApp`; aqui deixamos explícito porque o PDF pede "inicializar o Flutter".
- `runApp(const App())` coloca o widget raiz (`App`) na tela.

### 5.2 `lib/app.dart`

```dart
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Localizações',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF22594C)),
      home: const TelaColeta(),
    );
  }
}
```

- `StatelessWidget`: não guarda estado, só monta a interface.
- `MaterialApp`: configura o app no padrão Material (tema, navegação, textos).
- `colorSchemeSeed`: uma cor "semente" (verde escuro, a mesma do ícone). O Flutter gera todas as outras cores a partir dela.
- `debugShowCheckedModeBanner: false`: tira a faixa "DEBUG" do canto.
- `home: const TelaColeta()`: **a tela inicial**.

### 5.3 `models/localizacao.dart` — o modelo

```dart
class Localizacao {
  final int? id; // null enquanto ainda não foi salva
  final double latitude;
  final double longitude;
  final double precisao; // em metros
  final DateTime instante; // sempre em UTC
  ...
}
```

- É um **registro tipado**: em vez de passar `Map` pra lá e pra cá, usamos um objeto com campos certinhos.
- `final` = depois de criado, não muda.
- `int? id` → o `?` diz que pode ser `null`. Antes de salvar não existe id; o SQLite gera o id (autoincremento).

**Construtor:**

```dart
const Localizacao({
  this.id,
  required this.latitude,
  ...
});
```

- Parâmetros nomeados (entre `{}`). `required` = obrigatório. `id` não é obrigatório.

**`paraMapa()` — objeto → Map (para gravar no SQLite)**

```dart
Map<String, Object?> paraMapa() {
  return {
    if (id != null) 'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'precisao': precisao,
    'instante': instante.toUtc().toIso8601String(),
  };
}
```

- As **chaves** do Map são os **nomes das colunas** da tabela.
- `if (id != null) 'id': id,` → "collection if": só coloca a chave `id` se ela existir. Na inserção ela não existe, então o banco gera.
- `toUtc().toIso8601String()` → transforma a data em texto **UTC no formato ISO 8601**, ex.: `2026-11-02T18:30:15.000Z` (o `Z` significa UTC).

**`Localizacao.deMapa()` — Map → objeto (ao ler do SQLite)**

```dart
factory Localizacao.deMapa(Map<String, Object?> mapa) {
  return Localizacao(
    id: mapa['id'] as int,
    latitude: (mapa['latitude'] as num).toDouble(),
    longitude: (mapa['longitude'] as num).toDouble(),
    precisao: (mapa['precisao'] as num).toDouble(),
    instante: DateTime.parse(mapa['instante'] as String),
  );
}
```

- `factory` = construtor que **devolve** um objeto (aqui, montado a partir do Map).
- `as int`, `as String` → "confia, isso é desse tipo" (cast).
- `(... as num).toDouble()` → por segurança: se o valor vier como inteiro (ex.: `5`), vira `5.0`.
- `DateTime.parse(...)` lê o texto ISO 8601 de volta para `DateTime`. Como o texto termina em `Z`, o `DateTime` volta em UTC.

### 5.4 `data/database/banco_localizacoes.dart` — o banco

```dart
class BancoLocalizacoes {
  static const nomeArquivo = 'localizacoes.db';
  static const versao = 1;
  static const tabela = 'localizacoes';

  static Database? _banco;
  ...
}
```

- Tudo é `static`: pertence à **classe**, não a um objeto. Assim existe **um banco só** para o app inteiro, sem precisar criar `BancoLocalizacoes()`.
- `_banco` começa `null`. O `_` na frente = privado ao arquivo.

**`abrir()`**

```dart
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
```

Passo a passo:
1. Se já abriu antes (`_banco != null`), **reutiliza** a conexão.
2. `getDatabasesPath()` → pasta padrão de bancos do app (no Android: `/data/data/br.fatec.localizacoes/databases`).
3. `join(pasta, 'localizacoes.db')` → caminho completo do arquivo.
4. `openDatabase(...)` abre (ou cria) o arquivo.
   - `version: 1` → versão do esquema.
   - `onCreate: _criarTabela` → função chamada **só na primeira vez**, quando o arquivo ainda não existe.
5. **Nova tentativa se falhar:** se `openDatabase` lançar erro, a linha `_banco = await ...` não termina, `_banco` continua `null` e o erro sobe para quem chamou. Na próxima chamada de `abrir()`, ele tenta de novo.
- `_banco!` → o `!` diz "aqui com certeza não é null".

**`_criarTabela()`**

```sql
CREATE TABLE localizacoes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  precisao REAL NOT NULL,
  instante TEXT NOT NULL
)
```

| Coluna | Tipo | Significado |
|---|---|---|
| `id` | INTEGER | chave primária; `AUTOINCREMENT` = o banco numera sozinho (1, 2, 3…) |
| `latitude` | REAL (número decimal) | `NOT NULL` = obrigatória |
| `longitude` | REAL | obrigatória |
| `precisao` | REAL | obrigatória, em metros |
| `instante` | TEXT | obrigatória; data/hora UTC em ISO 8601 |

### 5.5 `data/repositories/repositorio_localizacoes.dart` — o repositório

É o **único lugar com operações no banco**. Todas as funções começam igual: `final db = await BancoLocalizacoes.abrir();`

**Inserir**

```dart
Future<void> inserir(Localizacao localizacao) async {
  final db = await BancoLocalizacoes.abrir();
  await db.insert(BancoLocalizacoes.tabela, localizacao.paraMapa());
}
```
- Converte o objeto em Map e faz o `INSERT`.

**Buscar as últimas 100**

```dart
Future<List<Localizacao>> buscarUltimas({int limite = 100}) async {
  final db = await BancoLocalizacoes.abrir();
  final linhas = await db.query(
    BancoLocalizacoes.tabela,
    orderBy: 'id DESC',
    limit: limite,
  );
  return linhas.map(Localizacao.deMapa).toList();
}
```
- Equivale a: `SELECT * FROM localizacoes ORDER BY id DESC LIMIT 100`.
- `orderBy: 'id DESC'` → do maior id para o menor. Como o id cresce a cada inserção, **o maior id é o registro mais recente**.
- `limit: 100` → o limite é **só na consulta**. Registros antigos continuam no banco (nada é apagado automaticamente).
- `linhas.map(Localizacao.deMapa).toList()` → transforma cada linha (Map) em `Localizacao`. As telas recebem `List<Localizacao>`, nunca Map cru.

**Excluir todas**

```dart
Future<void> excluirTodas() async {
  final db = await BancoLocalizacoes.abrir();
  await db.delete(BancoLocalizacoes.tabela);
}
```
- `db.delete(tabela)` **sem `where`** = `DELETE FROM localizacoes` → apaga **todas as linhas** (inclusive as que não apareciam entre as 100).
- A **tabela continua existindo** e o **arquivo do banco também** (não é `DROP TABLE` nem `deleteDatabase`).

### 5.6 `services/servico_localizacao.dart` — GPS, permissões e stream

**O enum**

```dart
enum StatusPermissao { concedida, gpsDesligado, negada, negadaPermanentemente }
```
- Um `enum` é uma lista fechada de valores possíveis. A tela usa ele para decidir o que falar para o usuário.

**`verificarPermissao()`**

```dart
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

  await Permission.notification.request();
  return StatusPermissao.concedida;
}
```

1. **GPS ligado?** `isLocationServiceEnabled()`. Se não → `gpsDesligado`.
2. **Já tem permissão?** `checkPermission()` só *consulta*, não mostra nada.
3. Se está `denied` (nunca deu ou negou uma vez) → `requestPermission()` **mostra a caixinha** do Android pedindo permissão.
4. Se depois disso continua `denied` → usuário negou → `negada`.
5. `deniedForever` → o usuário marcou "não perguntar de novo" (ou negou duas vezes). O app **não consegue mais pedir**; só nas configurações → `negadaPermanentemente`.
6. Pede permissão de **notificação** (Android 13+), senão a notificação da coleta fica escondida. Se o usuário recusar, a coleta funciona igual.
7. Tudo certo → `concedida`.

**`posicoes()` — o stream**

```dart
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
```

- `Stream<Position>` = sequência de posições que vão chegando com o tempo.
- `accuracy: LocationAccuracy.high` → **alta precisão** (usa GPS).
- `intervalDuration: 20 segundos` → **intervalo solicitado**. O Android pode entregar um pouco antes/depois.
- `foregroundNotificationConfig` → faz o geolocator rodar um **serviço em primeiro plano** com **notificação visível** enquanto o stream estiver sendo escutado. É isso que deixa a coleta continuar com o app minimizado.
  - `notificationIcon` → ícone pequeno da notificação. Usamos o pino branco do ícone adaptativo (`drawable/icone_localizacoes`).
  - `enableWakeLock: true` → evita que o processador "durma" durante a coleta.
  - `setOngoing: true` → a notificação não pode ser arrastada para fora enquanto coleta.
- **O stream só começa a funcionar quando alguém chama `.listen()`** (na tela de coleta). E para quando a assinatura é cancelada.

**Abrir configurações**

```dart
Future<bool> abrirConfiguracoesDoApp() => Geolocator.openAppSettings();
Future<bool> abrirConfiguracoesDoGps() => Geolocator.openLocationSettings();
```
- `=>` é uma função de uma linha só (retorna o que está à direita).
- `openAppSettings()` → tela de configurações **do app** (onde ficam as permissões).
- `openLocationSettings()` → tela para **ligar o GPS**.

### 5.7 `services/cache_mapa.dart` — cache das imagens do mapa

```dart
static Future<MapCachingProvider> preparar() async {
  final pastaPrivada = await getApplicationCacheDirectory();
  return BuiltInMapCachingProvider.getOrCreateInstance(
    cacheDirectory: join(pastaPrivada.path, 'mapa'),
  );
}
```

- O mapa é feito de várias imagens quadradas (os "tiles"). Para não baixar a mesma imagem toda hora, guardamos em **cache**.
- `getApplicationCacheDirectory()` → **pasta privada** de cache do app (outros apps não acessam).
- `getOrCreateInstance(...)` → cria o cache do flutter_map nessa pasta (ou reaproveita, se já criou).
- O cache do flutter_map **respeita o tempo de validade que o servidor do OpenStreetMap manda** (cabeçalhos HTTP). Isso é parte das regras de uso do provedor.
- É chamado **antes** de mostrar o mapa (na `TelaMapa`) — por isso "preparar antes de carregá-las".

### 5.8 `presentation/widgets/item_localizacao.dart`

```dart
static final _formatoData = DateFormat('dd/MM/yyyy HH:mm:ss');

@override
Widget build(BuildContext context) {
  final dataLocal = localizacao.instante.toLocal();
  final latitude = localizacao.latitude.toStringAsFixed(6);
  final longitude = localizacao.longitude.toStringAsFixed(6);
  final precisao = localizacao.precisao.toStringAsFixed(1);

  return ListTile(
    leading: const Icon(Icons.place_outlined),
    title: Text(_formatoData.format(dataLocal)),
    subtitle: Text(
      'Lat: $latitude   Long: $longitude\nPrecisão: ± $precisao m',
    ),
    isThreeLine: true,
  );
}
```

- `toLocal()` → converte o horário **UTC** salvo no banco para o **horário do aparelho** (ex.: Brasília).
- `DateFormat('dd/MM/yyyy HH:mm:ss')` → ex.: `02/11/2026 15:30:15`. `HH` = 0–23h.
- `toStringAsFixed(6)` → **6 casas decimais** (lat/long). `toStringAsFixed(1)` → **1 casa** (precisão).
- `ListTile` → linha pronta do Material: ícone à esquerda (`leading`), título e subtítulo.
- `isThreeLine: true` → o título + 2 linhas de subtítulo cabem direito.
- **Reutilizado em 3 lugares:** lista do histórico, card "Última posição salva" na tela inicial, e detalhes ao tocar num marcador do mapa.

### 5.9 `presentation/widgets/mapa_localizacoes.dart` — o mapa

É um `StatefulWidget` porque tem um **controlador** (`MapController`) que precisa ser liberado no `dispose`.

```dart
final _controlador = MapController();
late final _imagens = NetworkTileProvider(cachingProvider: widget.cache);

@override
void dispose() {
  _controlador.dispose();
  super.dispose();
}
```
- `MapController` → permite mover a câmera do mapa por código (usado no botão "enquadrar").
- `late final _imagens` → o provedor que baixa as imagens do mapa usando o cache. É `late` porque usa `widget.cache`, e `widget` só existe depois que o State é criado. Criamos uma vez só (não a cada `build`). O `TileLayer` libera esse provedor sozinho quando o mapa sai da tela.
- `dispose()` → libera o controlador quando a tela fecha (requisito: liberar controladores).

**Enquadramento**

```dart
CameraFit get _enquadramento {
  return CameraFit.coordinates(
    coordinates: [
      for (final l in widget.localizacoes) LatLng(l.latitude, l.longitude),
    ],
    padding: const EdgeInsets.all(48),
    maxZoom: 17,
  );
}

void _enquadrarTodos() {
  _controlador.fitCamera(_enquadramento);
}
```
- `get` → um "getter": parece variável, mas calcula na hora.
- `CameraFit.coordinates` → "mostre todos esses pontos na tela".
- `[for (...) ...]` → "collection for": monta a lista de `LatLng` a partir das localizações.
- `padding: 48` → deixa uma margem para os pinos não ficarem colados na borda.
- `maxZoom: 17` → se houver **um ponto só**, não dá zoom infinito.
- Usado em **dois lugares**:
  - `MapOptions(initialCameraFit: _enquadramento)` → **enquadra ao carregar**.
  - Botão `Icons.fit_screen` → `_enquadrarTodos()` → **enquadra de novo**.

**Detalhes ao tocar no marcador**

```dart
void _mostrarDetalhes(Localizacao localizacao) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ItemLocalizacao(localizacao: localizacao),
      ),
    ),
  );
}
```
- Abre uma folha de baixo para cima com o `ItemLocalizacao` (data, lat, long, precisão).

**O `build`** monta um `Stack` (camadas empilhadas): o mapa embaixo e o botão de enquadrar por cima.

Dentro do `FlutterMap`, a ordem dos `children` é a ordem das camadas (a primeira fica embaixo):

1. **`TileLayer`** — camada de ruas e referências geográficas.
   ```dart
   TileLayer(
     urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
     userAgentPackageName: 'br.fatec.localizacoes',
     tileProvider: _imagens,
   ),
   ```
   - `{z}` = zoom, `{x}`/`{y}` = posição do quadradinho.
   - `userAgentPackageName` → identifica o app para o servidor do OpenStreetMap (**regra de uso** deles).
2. **`MarkerLayer`** — um marcador por localização.
   ```dart
   for (final l in widget.localizacoes.reversed)
     Marker(
       point: LatLng(l.latitude, l.longitude),
       width: 36,
       height: 36,
       alignment: Alignment.topCenter,
       child: GestureDetector(
         onTap: () => _mostrarDetalhes(l),
         child: Icon(
           Icons.location_on,
           size: 36,
           color: l == maisRecente ? Colors.red : Colors.blueGrey.shade700,
         ),
       ),
     ),
   ```
   - `maisRecente = widget.localizacoes.first` → a lista vem da mais recente para a mais antiga, então a **primeira** é a mais recente → **vermelha**.
   - `.reversed` → desenha da mais antiga para a mais recente. Quem é desenhado por último fica **por cima**, então o pino vermelho nunca fica escondido.
   - `alignment: Alignment.topCenter` → o ícone fica *acima* do ponto, então a **ponta do pino** marca o lugar exato.
   - `GestureDetector(onTap: ...)` → tocar no pino abre os detalhes.
3. **`RichAttributionWidget`** — a **atribuição obrigatória** "OpenStreetMap contributors" (botão ⓘ no canto). Tocar abre `https://www.openstreetmap.org/copyright` com `launchUrl`.

### 5.10 `presentation/screens/tela_coleta.dart` — tela inicial (a mais importante)

**Estado da tela**

```dart
final _servico = ServicoLocalizacao();
final _repositorio = RepositorioLocalizacoes();

StreamSubscription<Position>? _assinatura; // null = coleta parada
bool _iniciando = false; // verificando GPS e permissões
bool _salvando = false; // gravando uma posição no banco
int _salvasNestaSessao = 0;
Localizacao? _ultima;

bool get _coletando => _assinatura != null;
```

| Variável | Para que serve |
|---|---|
| `_assinatura` | A "inscrição" no stream. **Se for `null`, a coleta está parada.** Se tiver valor, está coletando. |
| `_iniciando` | `true` enquanto confere GPS/permissão (para desabilitar o botão e não iniciar 2x). |
| `_salvando` | `true` enquanto uma posição está sendo gravada (para não gravar duas ao mesmo tempo). |
| `_salvasNestaSessao` | Contador mostrado na tela. |
| `_ultima` | Última posição salva, mostrada num card. |
| `_coletando` | Getter: `true` se `_assinatura != null`. |

**`dispose()`**

```dart
@override
void dispose() {
  _assinatura?.cancel();
  super.dispose();
}
```
- Quando a tela é destruída, cancela o stream (libera a assinatura). `?.` = só chama se não for null.

**`_iniciarColeta()`**

```dart
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
```

1. **Trava contra duplicação:** se já está coletando ou iniciando, sai.
2. Marca `_iniciando = true` → botão "Iniciar" fica desabilitado e o status mostra "Verificando permissões...".
3. `await verificarPermissao()` → espera o resultado (pode abrir a caixinha de permissão).
4. `if (!mounted) return;` → se a tela fechou enquanto esperava, não mexe em nada.
5. Se não foi concedida → mostra a orientação adequada e sai.
6. **`listen(...)`** → começa a escutar o stream.
   - `_salvarPosicao` → função chamada **a cada posição**.
   - `onError: _erroNaLocalizacao` → função chamada se o stream der erro (ex.: GPS desligado no meio).
   - O retorno do `listen` é a **assinatura** → guardada em `_assinatura`.
7. `catch` → se der erro na verificação, avisa.
8. `finally` → **sempre** roda no final: volta `_iniciando = false` e o `setState` redesenha a tela (agora com "Coleta em andamento").

**`_pararColeta()`**

```dart
Future<void> _pararColeta() async {
  await _assinatura?.cancel(); // encerra o stream e a notificação
  if (!mounted) return;
  setState(() => _assinatura = null);
}
```
- `cancel()` → para de receber posições; o geolocator encerra o serviço em primeiro plano e a notificação some.
- `_assinatura = null` → volta ao estado "parado" (botões trocam de habilitado).

**`_salvarPosicao()`** — chamada a cada posição do stream

```dart
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
```
- **Por que `_salvando`?** O `listen` **não espera** a função terminar. Se uma posição nova chegar enquanto a anterior ainda está sendo gravada, as duas gravações se sobreporiam. Com a trava, a nova é ignorada até a anterior terminar. (Com intervalo de 20 s isso é raro, mas o PDF pede para evitar.)
- Converte `Position` (do geolocator) em `Localizacao` (nosso modelo):
  - `accuracy` → `precisao` (metros).
  - `timestamp.toUtc()` → instante em UTC.
- Salva pelo **repositório** (a tela não faz SQL).
- Atualiza a tela (`_ultima` e contador) só se `mounted`.
- `finally` → libera a trava mesmo se der erro.

**`_erroNaLocalizacao()`** → mostra "Falha ao obter a localização. Verifique se o GPS está ligado." A coleta **não** é cancelada; se o GPS voltar, continua.

**`_orientarUsuario()`** — orientação conforme o problema

```dart
switch (status) {
  case StatusPermissao.gpsDesligado:      // mensagem + botão "Ativar" → configurações de localização
  case StatusPermissao.negada:            // mensagem explicando que precisa da permissão
  case StatusPermissao.negadaPermanentemente: // mensagem + botão "Abrir" → configurações do app
  case StatusPermissao.concedida:         // nada
}
```
- Em Dart 3 o `switch` de enum precisa cobrir **todos** os valores (por isso existe o `case concedida: break;`).
- Se foi `negada`, o usuário pode tocar em **Iniciar** de novo e a caixinha aparece outra vez.

**`_mostrarMensagem()`**

```dart
void _mostrarMensagem(String texto, {SnackBarAction? acao}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(texto), action: acao, persist: false),
  );
}
```
- `SnackBar` = barrinha de aviso na parte de baixo.
- `acao` opcional = botão dentro da barra ("Ativar", "Abrir").
- `persist: false` → some sozinha depois de alguns segundos (nas versões novas do Flutter, uma SnackBar com botão ficaria parada até ser tocada).

**Navegação** → ver [seção 6](#6-navegação-entre-telas-as-rotas).

**`build()`** — o que aparece na tela, de cima para baixo:

1. Bolinha (verde = coletando, cinza = parado) + texto de status.
2. "Posições salvas nesta sessão: N".
3. Se já salvou alguma: card "Última posição salva" com `ItemLocalizacao`. (`if (_ultima != null) ...[ ... ]` = collection if + spread `...` para inserir vários widgets.)
4. **Iniciar coleta** → `onPressed: _coletando || _iniciando ? null : _iniciarColeta`
5. **Parar coleta** → `onPressed: _coletando ? _pararColeta : null`
6. Divisória.
7. **Consultar histórico**, **Ver mapa**, **Configurações de permissão**.

> **Botão com `onPressed: null` fica desabilitado (cinza).** É assim que os botões Iniciar/Parar se habilitam conforme o estado: nunca dá para iniciar duas vezes nem parar o que não começou.

### 5.11 `presentation/screens/tela_localizacoes.dart` — histórico

Recebe `coletando` (bool) da tela inicial, para saber se avisa no diálogo de limpeza.

**Estado**

```dart
List<Localizacao> _localizacoes = [];
bool _carregando = true;
String? _erro;
```
Três estados possíveis na tela: **carregando** (spinner), **erro** (texto), **lista** (ou "Nenhuma localização salva." se vazia).

**`initState()`** → chama `_carregar()` assim que a tela abre.

**`_carregar()`**

```dart
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
```
- Mostra o spinner → busca no repositório → mostra a lista. Em erro, mostra a mensagem.
- **Atualizar sem interromper a coleta:** essa função só *lê* o banco. A assinatura do stream continua viva na `TelaColeta`, que está embaixo na pilha de telas.

**`_confirmarLimpeza()`**

```dart
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
```
- `showDialog<bool>` abre o diálogo e **espera** ele fechar. O valor passado em `Navigator.pop(context, valor)` é o que o `await` devolve.
  - **Cancelar** → `false`. **Limpar histórico** → `true`. Tocar fora do diálogo → `null`.
- O texto avisa que é **permanente** e que apaga **inclusive os que não aparecem** (além dos 100).
- `avisoColeta` → se `widget.coletando` for `true`, acrescenta: "A coleta está ativa: novas posições continuarão sendo salvas."
- `if (confirmou != true) return;` → só segue se confirmou de verdade.
- Depois de excluir: **atualiza a lista** (`_carregar()`) e mostra **mensagem de sucesso**. Em erro: **mensagem de erro**.

**AppBar**
- Botão **Atualizar** (`Icons.refresh`) → `_carregar`. Desabilitado enquanto carrega.
- Botão **Limpar histórico** (`Icons.delete_outline`) → `_confirmarLimpeza`. Desabilitado se a lista está vazia.

**`_conteudo()`** → escolhe o que mostrar: spinner, erro, "vazio" ou `ListView.separated` (lista com divisória entre os itens), em que cada item é um `ItemLocalizacao`.

### 5.12 `presentation/screens/tela_mapa.dart` — mapa

Mesmo esqueleto da tela de histórico (`_carregando`, `_erro`, `_localizacoes`, `_carregar()`), com duas diferenças:

```dart
final cache = await CacheMapa.preparar();
final lista = await _repositorio.buscarUltimas();
```
1. **Prepara o cache antes** de o mapa existir.
2. Guarda o cache em `_cache` e passa para o `MapaLocalizacoes`.

**Estados tratados antes de mostrar o mapa:** espera (spinner), erro (texto), histórico vazio ("Nenhuma localização salva. Inicie a coleta primeiro."). Só se tiver dados é que monta `MapaLocalizacoes`.

**Botão Atualizar** (AppBar) → `_carregar()`. Como ele volta para o estado "carregando", o mapa sai da tela e é **criado de novo** com os dados novos → o `initialCameraFit` roda outra vez e **re-enquadra** os pontos.

---

## 6. Navegação entre telas (as "rotas")

O app usa **navegação imperativa** com `Navigator.push` e `MaterialPageRoute` (não usa rotas nomeadas).

```dart
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
```

| De | Ação | Para | Como volta |
|---|---|---|---|
| `TelaColeta` (home) | Consultar histórico | `TelaLocalizacoes(coletando: ...)` | seta voltar (pop automático) |
| `TelaColeta` | Ver mapa | `TelaMapa()` | seta voltar |
| `TelaLocalizacoes` | Limpar | `AlertDialog` (também é uma rota) | `Navigator.pop(context, true/false)` |
| `MapaLocalizacoes` | Toca no pino | `showModalBottomSheet` | arrastar para baixo / tocar fora |
| `TelaColeta` | Configurações de permissão | tela do Android (fora do app) | botão voltar do Android |

**Pilha de telas:** o `Navigator` funciona como uma pilha de pratos.

```
push(TelaMapa)          pop (voltar)
┌──────────────┐
│  TelaMapa    │  ← topo
├──────────────┤        ┌──────────────┐
│  TelaColeta  │        │  TelaColeta  │
└──────────────┘        └──────────────┘
```

> **Por que a coleta continua ao trocar de tela?** O `push` coloca a nova tela **por cima**; a `TelaColeta` **não é destruída** (seu `dispose` não é chamado). A `_assinatura` continua viva lá embaixo, recebendo e salvando posições.
>
> **E ao minimizar?** O serviço em primeiro plano (notificação) mantém o processo do app vivo.
>
> **E se o processo for encerrado ou o celular reiniciar?** A coleta para e não volta sozinha — o PDF diz que isso não é obrigatório.

---

## 7. Parte Android

### 7.1 `AndroidManifest.xml` — permissões

| Permissão | Por quê |
|---|---|
| `ACCESS_FINE_LOCATION` | Localização precisa (GPS) |
| `ACCESS_COARSE_LOCATION` | Localização aproximada (obrigatório declarar junto) |
| `FOREGROUND_SERVICE` | Rodar serviço em primeiro plano |
| `FOREGROUND_SERVICE_LOCATION` | Android 14+: serviço em primeiro plano do **tipo localização** |
| `WAKE_LOCK` | Usada pelo `enableWakeLock: true` (CPU não dorme durante a coleta) |
| `POST_NOTIFICATIONS` | Android 13+: mostrar a notificação da coleta |
| `INTERNET` | Baixar as imagens do mapa |

Também no manifest:
- `android:label="Localizações"` → nome que aparece embaixo do ícone.
- `android:icon="@mipmap/ic_localizacoes"` → **ícone do app** (substitui o `ic_launcher` padrão do Flutter, que foi apagado).
- `<queries>` com `VIEW` + `https` → necessário no Android 11+ para o `url_launcher` abrir o link da atribuição.
- O `<service>` do geolocator (`GeolocatorLocationService`, tipo `location`) é declarado **pelo próprio plugin**, por isso não aparece no nosso manifest.

### 7.2 Ícone

| Arquivo | O que é |
|---|---|
| `assets/icons/localizacoes.png` | Imagem **original** 1024×1024 (fundo verde + pino branco). |
| `res/mipmap-mdpi … xxxhdpi/ic_localizacoes.png` | Ícone "clássico" em 5 tamanhos (48, 72, 96, 144, 192 px), para Android antigo. |
| `res/mipmap-anydpi-v26/ic_localizacoes.xml` | **Ícone adaptativo** (Android 8+). Junta um fundo e uma frente. |
| `res/drawable-nodpi/icone_localizacoes.png` | A **frente** do ícone adaptativo: só o pino branco, fundo transparente (432×432). `nodpi` = não redimensionar por densidade. |
| `res/values/icone_localizacoes.xml` | A **cor de fundo** do ícone (`#22594C`). |

```xml
<adaptive-icon>
    <background android:drawable="@color/icone_localizacoes_fundo" />
    <foreground android:drawable="@drawable/icone_localizacoes" />
</adaptive-icon>
```
- No Android 8+, o launcher recorta o ícone adaptativo no formato dele (círculo, quadrado arredondado…). O pino fica dentro da "zona segura" central para nunca ser cortado.
- O mesmo `drawable/icone_localizacoes` é usado como **ícone pequeno da notificação** (ícones de notificação precisam ser brancos com fundo transparente).

---

## 8. Fluxos completos, passo a passo

### 8.1 Iniciar coleta
1. Usuário toca **Iniciar coleta** → `_iniciarColeta()`.
2. Já coletando/iniciando? Sai. Senão `_iniciando = true` (botão desabilita).
3. `ServicoLocalizacao.verificarPermissao()`:
   GPS ligado? → permissão? (pede se precisar) → permissão de notificação.
4. Problema? → `_orientarUsuario()` mostra a SnackBar certa (com botão para as configurações quando faz sentido).
5. OK → `posicoes().listen(_salvarPosicao, onError: _erroNaLocalizacao)` → guarda em `_assinatura`.
6. Android mostra a **notificação** "Coleta de localização ativa".
7. `finally` → `_iniciando = false`, tela redesenha: bolinha verde, "Iniciar" desabilitado, "Parar" habilitado.

### 8.2 Cada posição recebida (a cada ~20 s)
1. Stream entrega um `Position` → `_salvarPosicao(posicao)`.
2. Se ainda está gravando a anterior → ignora.
3. Cria `Localizacao` (instante em UTC).
4. `RepositorioLocalizacoes.inserir()` → `BancoLocalizacoes.abrir()` → `db.insert('localizacoes', paraMapa())`.
5. Atualiza o card "Última posição salva" e o contador.

### 8.3 Parar coleta
1. **Parar coleta** → `_pararColeta()` → `_assinatura.cancel()`.
2. Geolocator para as atualizações e remove a notificação.
3. `_assinatura = null` → botões voltam ao normal.

### 8.4 Histórico
1. **Consultar histórico** → `push(TelaLocalizacoes(coletando: ...))`.
2. `initState` → `_carregar()` → `buscarUltimas()` (`ORDER BY id DESC LIMIT 100`).
3. Lista de `ItemLocalizacao`: data/hora **local**, lat/long com **6 casas**, precisão com **1 casa**.
4. **Atualizar** → `_carregar()` de novo (a coleta segue rodando).

### 8.5 Limpar histórico
1. Ícone de lixeira → `_confirmarLimpeza()`.
2. Diálogo: **Cancelar** / **Limpar histórico**, avisa que é permanente (+ aviso se a coleta está ativa).
3. Confirmou → `excluirTodas()` → `DELETE FROM localizacoes` (tabela e arquivo continuam).
4. Recarrega a lista (fica vazia) + SnackBar "Histórico apagado." (ou mensagem de erro).

### 8.6 Mapa
1. **Ver mapa** → `push(TelaMapa())`.
2. `_carregar()` → `CacheMapa.preparar()` → `buscarUltimas()`.
3. Espera / erro / vazio são tratados antes.
4. `MapaLocalizacoes` → ruas (OSM) + marcadores (último em **vermelho**) + atribuição. Enquadra os pontos ao abrir.
5. Botão **enquadrar** (canto superior direito) → `fitCamera`. Botão **atualizar** (AppBar) → recarrega e re-enquadra.
6. Toque num pino → folha com os detalhes (`ItemLocalizacao`).

---

## 9. Conceitos de Dart/Flutter que aparecem no código

| Conceito | Explicação curta | Exemplo no app |
|---|---|---|
| `Future` | Valor que fica pronto **depois** | `Future<List<Localizacao>> buscarUltimas()` |
| `async` / `await` | `await` pausa a função até o Future terminar, sem travar a tela | `final lista = await _repositorio.buscarUltimas();` |
| `Stream` | Vários valores chegando ao longo do tempo | `Stream<Position> posicoes()` |
| `listen` | Começa a escutar o stream; devolve uma `StreamSubscription` | `_servico.posicoes().listen(_salvarPosicao, ...)` |
| `StreamSubscription.cancel()` | Para de escutar | `_assinatura?.cancel()` |
| `StatelessWidget` | Widget sem estado | `App`, `ItemLocalizacao` |
| `StatefulWidget` + `State` | Widget com dados que mudam | as 3 telas e o mapa |
| `setState` | Muda o estado **e** redesenha a tela | `setState(() => _iniciando = true);` |
| `initState` | Roda 1 vez quando a tela é criada | carrega o histórico |
| `dispose` | Roda quando a tela é destruída: liberar recursos | cancela assinatura / `MapController.dispose()` |
| `mounted` | `true` se a tela ainda está na árvore. **Checar depois de todo `await` antes de `setState`/usar `context`** | `if (!mounted) return;` |
| `try / catch / finally` | Tratar erro; `finally` sempre roda | gravação e permissões |
| `?` / `!` / `?.` | pode ser null / "garanto que não é null" / chama só se não for null | `int? id`, `_banco!`, `_assinatura?.cancel()` |
| `static` | Pertence à classe, não ao objeto | `BancoLocalizacoes.abrir()` |
| `factory` | Construtor que monta e devolve um objeto | `Localizacao.deMapa` |
| `enum` + `switch` | Lista fechada de valores; switch cobre todos | `StatusPermissao` |
| `late final` | Inicializa depois, mas só uma vez | `_imagens` no mapa |
| `get` | Getter (calcula na hora) | `_coletando`, `_enquadramento` |
| collection `if` / `for` / spread `...` | Montar listas/maps com condição e laço | `if (id != null) 'id': id`, `[for (final l in ...) LatLng(...)]`, `...[ ... ]` |
| `const` | Objeto criado em tempo de compilação (mais leve) | `const Text('Mapa')` |
| `onPressed: null` | Botão desabilitado | Iniciar/Parar |

---

## 10. Checklist: requisito do PDF → onde está no código

| Requisito | Onde |
|---|---|
| Botões Iniciar, Parar, Consultar histórico, Ver mapa, Configurações de permissão | `tela_coleta.dart` → `build()` |
| Verificar serviço de localização | `servico_localizacao.dart` → `isLocationServiceEnabled()` |
| Verificar e solicitar permissão | `checkPermission()` / `requestPermission()` |
| Orientar se negada / precisa ir nas configurações | `tela_coleta.dart` → `_orientarUsuario()` |
| Stream, alta precisão, 20 s | `servico_localizacao.dart` → `posicoes()` |
| Salvar cada posição no SQLite | `_salvarPosicao()` → `repositorio.inserir()` |
| Evitar assinatura duplicada | `if (_coletando \|\| _iniciando) return;` + botão desabilitado |
| Evitar gravações sobrepostas | flag `_salvando` |
| Serviço em primeiro plano com notificação (Android) | `ForegroundNotificationConfig` + permissões no manifest |
| Continuar ao navegar e minimizar | `TelaColeta` fica na pilha + serviço em primeiro plano |
| Parar cancela a assinatura | `_pararColeta()` → `cancel()` |
| Botões habilitados conforme estado | `onPressed: ... ? null : ...` |
| Últimas 100, mais recente primeiro | `buscarUltimas()` → `orderBy: 'id DESC', limit: 100` |
| Data/hora local, lat, long, precisão | `item_localizacao.dart` (`toLocal()`) |
| 6 casas (lat/long) e 1 casa (precisão) | `toStringAsFixed(6)` / `toStringAsFixed(1)` |
| Atualizar sem parar a coleta | botão Atualizar → `_carregar()` |
| Limpar tudo (inclusive além dos 100) | `excluirTodas()` → `db.delete(tabela)` |
| Diálogo Cancelar / Limpar histórico, permanente, aviso de coleta ativa | `_confirmarLimpeza()` |
| Atualizar lista + mensagem de sucesso / erro | `_confirmarLimpeza()` |
| Mapa: últimas 100, ruas, marcadores, recente em vermelho | `mapa_localizacoes.dart` |
| Enquadrar ao carregar / botão enquadrar / botão atualizar | `initialCameraFit`, `_enquadrarTodos()`, AppBar da `TelaMapa` |
| Espera, erro, vazio antes do mapa | `tela_mapa.dart` → `_conteudo()` |
| Banco `localizacoes.db`, tabela e colunas | `banco_localizacoes.dart` |
| Instante UTC ISO 8601 / exibição local | `paraMapa()` / `ItemLocalizacao` |
| Limite só na consulta | `limit` na query, nada é apagado sozinho |
| Limpeza preserva tabela e arquivo | `DELETE` sem `where` (não é `DROP`) |
| Reutilizar conexão e permitir nova tentativa | `BancoLocalizacoes.abrir()` |
| Ícone próprio, substitui o padrão, original em assets | seção 7.2 |
| Sem SQL nas telas; telas usam `Localizacao` | todo SQL está no repositório/banco |
| Sem `Timer.periodic` / `workmanager` | só stream do geolocator |
| Sem backend remoto | só SQLite local |
| Tratar erros (permissão, localização, banco) | `try/catch` + `onError` |
| Liberar assinaturas e controladores | `dispose()` da `TelaColeta` e do `MapaLocalizacoes` |
| Verificar `mounted` | depois de cada `await` nas telas |
| Atribuição e cache do provedor do mapa | `RichAttributionWidget`, `userAgentPackageName`, `CacheMapa` |
| Não versionar bancos com coordenadas | `.gitignore` → `*.db` |
| Código formatado e `flutter analyze` sem problemas | `dart format .` e `flutter analyze` → "No issues found!" |

---

## 11. Exercícios estilo prova

Tente completar **sem olhar** o código. Gabarito no final.

**1.** Complete a criação da tabela:
```sql
CREATE TABLE localizacoes (
  id INTEGER ________________________,
  latitude REAL ________,
  longitude REAL NOT NULL,
  precisao REAL NOT NULL,
  instante ______ NOT NULL
)
```

**2.** Complete o `paraMapa()` para gravar o instante em UTC no formato ISO 8601:
```dart
'instante': instante.________().________________(),
```

**3.** Complete a reutilização da conexão:
```dart
static Future<Database> abrir() async {
  if (________ != null) return _banco!;
  final caminho = join(await ______________(), nomeArquivo);
  _banco = await openDatabase(caminho, version: versao, ________: _criarTabela);
  return _banco!;
}
```

**4.** Complete a consulta das últimas 100, da mais recente para a mais antiga, devolvendo objetos `Localizacao`:
```dart
final linhas = await db.query(
  BancoLocalizacoes.tabela,
  orderBy: '____________',
  limit: ______,
);
return linhas.map(________________).toList();
```

**5.** Complete a exclusão de todos os registros (mantendo a tabela):
```dart
await db.________(BancoLocalizacoes.tabela);
```

**6.** Complete a verificação de permissão:
```dart
if (!await Geolocator.__________________________()) {
  return StatusPermissao.gpsDesligado;
}
var permissao = await Geolocator.________________();
if (permissao == LocationPermission.denied) {
  permissao = await Geolocator.__________________();
}
if (permissao == LocationPermission.______________) {
  return StatusPermissao.negadaPermanentemente;
}
```

**7.** Complete a configuração do stream (alta precisão, 20 segundos):
```dart
final configuracao = AndroidSettings(
  accuracy: LocationAccuracy.______,
  intervalDuration: const Duration(________: 20),
  foregroundNotificationConfig: ...,
);
return Geolocator.__________________(locationSettings: configuracao);
```

**8.** Complete o início da coleta:
```dart
if (_coletando || _iniciando) ________;
...
_assinatura = _servico.posicoes().________(
  _salvarPosicao,
  ________: _erroNaLocalizacao,
);
```

**9.** Complete a parada da coleta:
```dart
Future<void> _pararColeta() async {
  await _assinatura?.________();
  if (!________) return;
  setState(() => _assinatura = ______);
}
```

**10.** Complete a trava contra gravações sobrepostas:
```dart
Future<void> _salvarPosicao(Position posicao) async {
  if (__________) return;
  _salvando = ______;
  try {
    await _repositorio.inserir(localizacao);
    ...
  } ________ {
    _salvando = false;
  }
}
```

**11.** Complete os botões para habilitar conforme o estado:
```dart
FilledButton.icon(
  onPressed: _coletando || _iniciando ? ______ : _iniciarColeta,
  ...
),
OutlinedButton.icon(
  onPressed: _coletando ? ____________ : null,
  ...
),
```

**12.** Complete a formatação no `ItemLocalizacao`:
```dart
final dataLocal = localizacao.instante.__________();
final latitude = localizacao.latitude.______________(6);
final precisao = localizacao.precisao.toStringAsFixed(___);
```

**13.** Complete o diálogo para que `confirmou` seja `true` só ao tocar em "Limpar histórico":
```dart
TextButton(
  onPressed: () => Navigator.pop(context, ______),
  child: const Text('Cancelar'),
),
FilledButton(
  onPressed: () => Navigator.pop(context, ______),
  child: const Text('Limpar histórico'),
),
...
if (confirmou != ______) return;
```

**14.** Complete o marcador para que a localização mais recente fique vermelha:
```dart
final maisRecente = widget.localizacoes.________;
...
color: l == maisRecente ? Colors.______ : Colors.blueGrey.shade700,
```

**15.** Complete o botão que enquadra todos os pontos e o `dispose` do mapa:
```dart
void _enquadrarTodos() {
  _controlador.__________(_enquadramento);
}

@override
void dispose() {
  _controlador.________();
  super.dispose();
}
```

**16.** Complete a navegação para o mapa:
```dart
Navigator.of(context).______(
  ________________(builder: (context) => const TelaMapa()),
);
```

**17.** Complete a camada de ruas respeitando as regras do OpenStreetMap:
```dart
TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{___}/{___}/{___}.png',
  ____________________: 'br.fatec.localizacoes',
  tileProvider: _imagens,
),
```

**18.** Perguntas rápidas:
- a) Por que a coleta continua quando o usuário abre o histórico?
- b) O que acontece se `openDatabase` lançar um erro? A próxima chamada funciona?
- c) Por que checamos `mounted` depois de um `await`?
- d) O limite de 100 apaga registros antigos?
- e) Qual a diferença entre `db.delete(tabela)` e `DROP TABLE`?
- f) Onde fica o SQL do app? Por que não nas telas?
- g) Por que os marcadores são desenhados com `.reversed`?
- h) Para que serve o `finally` em `_iniciarColeta`?

---

### Gabarito

1. `PRIMARY KEY AUTOINCREMENT` · `NOT NULL` · `TEXT`
2. `toUtc` · `toIso8601String`
3. `_banco` · `getDatabasesPath` · `onCreate`
4. `'id DESC'` · `100` (ou `limite`) · `Localizacao.deMapa`
5. `delete`
6. `isLocationServiceEnabled` · `checkPermission` · `requestPermission` · `deniedForever`
7. `high` · `seconds` · `getPositionStream`
8. `return` · `listen` · `onError`
9. `cancel` · `mounted` · `null`
10. `_salvando` · `true` · `finally`
11. `null` · `_pararColeta`
12. `toLocal` · `toStringAsFixed` · `1`
13. `false` · `true` · `true`
14. `first` · `red`
15. `fitCamera` · `dispose`
16. `push` · `MaterialPageRoute`
17. `z`, `x`, `y` · `userAgentPackageName`
18.
   - a) Porque o `push` coloca o histórico **por cima** da `TelaColeta`; ela não é destruída e a `_assinatura` continua ativa.
   - b) `_banco` continua `null` e o erro sobe. Sim, a próxima chamada tenta abrir de novo.
   - c) Porque durante a espera a tela pode ter sido fechada; chamar `setState` ou usar `context` numa tela que não existe mais dá erro.
   - d) Não. O `LIMIT` é só na consulta; os registros antigos continuam no banco.
   - e) `delete` sem `where` apaga **as linhas** e mantém a tabela; `DROP TABLE` apagaria **a tabela inteira** (estrutura).
   - f) No `RepositorioLocalizacoes` (e o `CREATE TABLE` no `BancoLocalizacoes`). Para separar responsabilidades: tela só cuida da interface.
   - g) A lista vem da mais recente para a mais antiga; invertendo, a mais recente é desenhada por último e fica **por cima**, sem ser escondida.
   - h) Garante que `_iniciando` volte a `false` **em qualquer caso** (sucesso, `return` antecipado ou erro).
