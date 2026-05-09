# Daily English — Sub-projeto 1: Fundação + Dicionário

**Data:** 2026-05-09
**Status:** Aprovado
**Escopo:** Setup do projeto Flutter, tema visual, navegação, banco SQLite, CRUD completo de palavras.

---

## Contexto

O Daily English é um dicionário pessoal inteligente para inglês com gamificação, flashcards, phrasal verbs e diário interativo. Este é o Sub-projeto 1 de 7, responsável por estabelecer a fundação técnica e o módulo de palavras.

O app é desenvolvido com Flutter/Dart, destinado a Android e iOS, com interface bilíngue (labels em inglês, feedback ao usuário em português).

---

## Arquitetura

**Padrão:** Clean Architecture em camadas.

```
Screen → Provider (Riverpod) → Repository → SQLite
```

Cada camada conhece apenas a camada imediatamente abaixo. O banco é acessado exclusivamente pelos repositories. Os providers expõem estado reativo para as telas.

### Estrutura de Pastas

```
lib/
├── main.dart
├── app.dart
│
├── core/
│   ├── database/
│   │   └── app_database.dart
│   ├── theme/
│   │   └── app_theme.dart
│   └── router/
│       └── app_router.dart
│
├── models/
│   └── word.dart
│
├── repositories/
│   └── word_repository.dart
│
├── providers/
│   └── word_provider.dart
│
└── screens/
    ├── home/
    │   └── home_screen.dart
    └── words/
        ├── words_screen.dart
        ├── word_form_screen.dart
        └── word_detail_screen.dart
```

### Pacotes

| Pacote | Versão | Uso |
|---|---|---|
| `flutter_riverpod` | ^2.x | Gerenciamento de estado |
| `sqflite` | ^2.x | Banco de dados local SQLite |
| `path` | ^1.x | Localização do arquivo do banco |
| `go_router` | ^13.x | Navegação declarativa |
| `google_fonts` | ^6.x | Tipografia (Nunito) |

---

## Camada de Dados

### Modelo `Word`

```dart
class Word {
  final int? id;
  final String word;
  final String translation;
  final String? meaning;
  final String? example1;
  final String? example2;
  final String? example3;
  final String? synonyms;
  final String? opposite;
  final String? category;
  final int difficulty;      // 1 = easy, 2 = medium, 3 = hard
  final String status;       // 'learning' | 'learned' | 'difficult'
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Tabela SQLite

```sql
CREATE TABLE words (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  word TEXT NOT NULL,
  translation TEXT NOT NULL,
  meaning TEXT,
  example_1 TEXT,
  example_2 TEXT,
  example_3 TEXT,
  synonyms TEXT,
  opposite TEXT,
  category TEXT,
  difficulty INTEGER DEFAULT 1,
  status TEXT DEFAULT 'learning',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
```

### `AppDatabase`

Classe singleton responsável por inicializar o SQLite, criar as tabelas e centralizar a instância do banco. Recebe o path via `path` package para compatibilidade Android/iOS.

### `WordRepository`

| Método | Assinatura | Descrição |
|---|---|---|
| `getAll` | `Future<List<Word>>` | Lista todas as palavras |
| `getById` | `Future<Word?> getById(int id)` | Busca por ID |
| `search` | `Future<List<Word>> search(String query)` | Busca em `word` e `translation` |
| `filterByCategory` | `Future<List<Word>> filterByCategory(String cat)` | Filtra por categoria |
| `filterByStatus` | `Future<List<Word>> filterByStatus(String status)` | Filtra por status |
| `insert` | `Future<int> insert(Word word)` | Cadastra, retorna ID |
| `update` | `Future<void> update(Word word)` | Edita palavra existente |
| `delete` | `Future<void> delete(int id)` | Remove por ID |

---

## Camada de Estado (Riverpod)

### `databaseProvider`

```dart
Provider<AppDatabase>
```

Instância única do banco, inicializado no `main.dart` via `ProviderScope`. Shared por todos os repositories.

### `wordRepositoryProvider`

```dart
Provider<WordRepository>
```

Instância do repository com o banco injetado.

### `wordListProvider`

```dart
AsyncNotifier<List<Word>>
```

Estado principal da lista de palavras. Suporta busca e filtros. Métodos expostos:

```dart
Future<void> addWord(Word word)
Future<void> updateWord(Word word)
Future<void> deleteWord(int id)
void setSearch(String query)
void setFilter({String? category, String? status})
```

Qualquer operação de escrita recarrega a lista automaticamente, mantendo a UI sempre sincronizada.

### `wordDetailProvider`

```dart
FutureProvider.family<Word?, int>
```

Carrega uma palavra específica pelo ID para a tela de detalhes.

---

## Interface e Navegação

### Tema Visual

| Token | Cor | Uso |
|---|---|---|
| `primary` | `#58CC02` verde | Botões principais, progresso |
| `secondary` | `#1CB0F6` azul | Palavras novas, destaques |
| `tertiary` | `#CE82FF` roxo | Phrasal verbs (sub-projeto 2) |
| `error` | `#FF4B4B` vermelho | Palavras difíceis, erros |
| `warning` | `#FF9600` laranja | Ofensiva (sub-projeto 5) |
| `surface` | `#FFFFFF` branco | Cards |
| `background` | `#F7F7F7` cinza claro | Fundo das telas |

Fonte: `Nunito` via Google Fonts — arredondada, amigável, próxima ao estilo Duolingo.

Componentes: cards arredondados (`BorderRadius.circular(16)`), sombra leve, botões com altura mínima de 48px (acessibilidade).

### Rotas (GoRouter)

| Rota | Tela |
|---|---|
| `/` | `HomeScreen` |
| `/words` | `WordsScreen` |
| `/words/new` | `WordFormScreen` (criar) |
| `/words/:id` | `WordDetailScreen` |
| `/words/:id/edit` | `WordFormScreen` (editar) |

### Telas

**`HomeScreen`**
Card de boas-vindas com nome do app, contagem de palavras cadastradas, botão "Add Word" (→ `/words/new`), botão "My Words" (→ `/words`). Placeholders visuais para módulos futuros (Phrasal Verbs, Diary, Flashcards) com estado desabilitado.

**`WordsScreen`**
- `SearchBar` no topo para busca em tempo real
- Chips horizontais de filtro: por categoria e por status
- Lista de `WordCard` — cada card mostra: palavra em destaque, tradução, badge colorido de status
- FAB `+` para adicionar nova palavra (→ `/words/new`)
- Estado vazio com mensagem "No words yet. Add your first word!"

**`WordFormScreen`** (criar e editar)
Formulário com todos os campos do modelo. Campos obrigatórios: `word`, `translation`. Campos opcionais: todos os demais. Seletor de categoria via dropdown com as categorias definidas no spec. Seletor de dificuldade via chips (Easy / Medium / Hard). Botão "Save" chama `addWord` ou `updateWord`. Validação inline antes de salvar.

**`WordDetailScreen`**
Exibe todos os campos preenchidos da palavra. Botão "Edit" (→ `/words/:id/edit`). Botão "Delete" com diálogo de confirmação. Seletor de status (Learning / Learned / Difficult) com atualização inline.

### Bilinguismo

- Labels de navegação e botões de ação: inglês (`Add Word`, `Save`, `Delete`, `Edit`, `My Words`)
- Mensagens de feedback/toast ao usuário: português (`Palavra salva com sucesso!`, `Palavra removida.`)
- Campos do formulário: inglês (`Word`, `Translation`, `Meaning`, `Examples`, `Synonyms`, `Opposite`)
- Categorias: inglês (`Work`, `Travel`, `Family`, `Daily Routine`, `Technology`, `IELTS`, `Verbs`, `Adjectives`, `Useful Phrases`, `Environmental Police`, `Immigration`, `Conversation`)
- Status: inglês (`Learning`, `Learned`, `Difficult`)

---

## Categorias de Palavras

```dart
const wordCategories = [
  'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
  'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
  'Environmental Police', 'Immigration', 'Conversation',
];
```

---

## Fora de Escopo (Sub-projeto 1)

Os seguintes itens estão planejados mas fora deste sub-projeto:

- Phrasal Verbs (Sub-projeto 2)
- Diário + Leitura Interativa (Sub-projeto 3)
- Flashcards (Sub-projeto 4)
- Gamificação / XP / Ofensiva (Sub-projeto 5)
- Conquistas + Notificações (Sub-projeto 6)
- Mini Games (Sub-projeto 7)

As telas futuras aparecem como placeholders desabilitados no `HomeScreen` para que a navegação já tenha estrutura visual.

---

## Critérios de Sucesso

- [ ] Projeto Flutter executa sem erros em Android e iOS
- [ ] Banco SQLite inicializa e cria a tabela `words` corretamente
- [ ] CRUD completo de palavras funciona (criar, ler, editar, excluir)
- [ ] Busca por palavra e tradução funciona em tempo real
- [ ] Filtros por categoria e status funcionam
- [ ] Status da palavra pode ser alterado diretamente na tela de detalhes
- [ ] Tema visual aplicado consistentemente em todas as telas
- [ ] Navegação entre todas as telas funciona sem erros
- [ ] App não perde dados ao fechar e reabrir
