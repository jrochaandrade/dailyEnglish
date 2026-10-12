import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/sm2.dart';
import '../../models/contest_card.dart';
import '../../providers/contest_card_provider.dart';

const _contestCardPrompt =
    '''Você é um especialista em preparação para concursos públicos.

Crie 1 flashcard objetivo sobre o conteúdo que eu enviar. Use exatamente este formato, sem Markdown, sem numeração e sem texto antes ou depois:

Matéria: [nome da matéria]
Assunto: [assunto específico]
Pergunta: [pergunta clara para a frente do cartão]
Resposta: [resposta correta, completa e resumida]
Observação: [pegadinha, dica ou explicação curta; se não houver, deixe vazio]
Fonte: [lei, artigo, súmula, norma ou referência; se não houver, deixe vazio]

Regras:
- Gere somente um cartão.
- Não invente informações. Se o conteúdo estiver incompleto, indique isso na Observação.
- Preserve datas, números, exceções e palavras-chave importantes.
- Para questões de certo ou errado, escreva a afirmação na Pergunta e explique a resposta.

Conteúdo para transformar em flashcard:
[COLE AQUI O MATERIAL]''';

class ContestCardsScreen extends ConsumerStatefulWidget {
  const ContestCardsScreen({super.key});

  @override
  ConsumerState<ContestCardsScreen> createState() => _ContestCardsScreenState();
}

class _ContestCardsScreenState extends ConsumerState<ContestCardsScreen> {
  String? _subject;

  String _reviewPath() => Uri(
        path: '/concursos/review',
        queryParameters: _subject == null ? null : {'subject': _subject},
      ).toString();

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(contestCardListProvider);
    final subjects = ref.watch(contestSubjectsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Concursos'),
        leading: BackButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/')),
        actions: [
          IconButton(
            tooltip: 'Revisar cartões pendentes',
            onPressed: () => context.push(_reviewPath()),
            icon: const Icon(Icons.play_circle_outline_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/concursos/new'),
        backgroundColor: AppTheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Row(
              children: [
                Expanded(
                    child: Text('Organize por matéria e assunto',
                        style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant))),
                TextButton(
                    onPressed: () => context.push(_reviewPath()),
                    child: const Text('Revisar')),
              ],
            ),
          ),
          if (subjects.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ChoiceChip(
                      label: const Text('Todas'),
                      selected: _subject == null,
                      onSelected: (_) {
                        setState(() => _subject = null);
                        ref.read(contestCardListProvider.notifier).filter();
                      }),
                  ...subjects.map((subject) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                            label: Text(subject),
                            selected: _subject == subject,
                            onSelected: (_) {
                              setState(() => _subject = subject);
                              ref
                                  .read(contestCardListProvider.notifier)
                                  .filter(newSubject: subject);
                            }),
                      )),
                ],
              ),
            ),
          Expanded(
            child: cards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Erro ao carregar cartões: $e')),
              data: (items) => items.isEmpty
                  ? _EmptyContestState(
                      onAdd: () => context.push('/concursos/new'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: items.length,
                      itemBuilder: (_, index) =>
                          _ContestCardTile(card: items[index]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestCardTile extends ConsumerWidget {
  final ContestCard card;
  const _ContestCardTile({required this.card});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
            backgroundColor: AppTheme.secondary.withValues(alpha: .12),
            child: const Icon(Icons.quiz_outlined, color: AppTheme.secondary)),
        title: Text(card.front,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(fontWeight: FontWeight.w800)),
        subtitle: Text('${card.subject} · ${card.deck}',
            style: GoogleFonts.nunito(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              context.push('/concursos/edit', extra: card);
              return;
            }
            if (action == 'delete' && card.id != null) {
              await ref.read(contestCardListProvider.notifier).delete(card.id!);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Editar'),
                )),
            PopupMenuItem(
                value: 'delete',
                child: Text('Excluir',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
        isThreeLine: true,
        dense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => showDialog(
            context: context,
            builder: (_) => AlertDialog(
                    title: Text(card.front),
                    content: SingleChildScrollView(child: Text(card.back)),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Fechar'))
                    ])),
      ),
    );
  }
}

class _EmptyContestState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyContestState({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.school_outlined,
              size: 72, color: AppTheme.secondary),
          const SizedBox(height: 16),
          Text('Nenhum cartão de concurso ainda',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Crie cartões separados do seu conteúdo de inglês.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Criar cartão')),
        ]),
      ));
}

class ContestCardFormScreen extends ConsumerStatefulWidget {
  final ContestCard? card;

  const ContestCardFormScreen({super.key, this.card});
  @override
  ConsumerState<ContestCardFormScreen> createState() =>
      _ContestCardFormScreenState();
}

class _ContestCardFormScreenState extends ConsumerState<ContestCardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _deck = TextEditingController();
  final _front = TextEditingController();
  final _back = TextEditingController();
  final _note = TextEditingController();
  final _source = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    if (card != null) {
      _subject.text = card.subject;
      _deck.text = card.deck;
      _front.text = card.front;
      _back.text = card.back;
      _note.text = card.note ?? '';
      _source.text = card.source ?? '';
    }
  }

  Map<String, String> _parseClipboardText(String text) {
    final values = <String, String>{};
    String? current;
    final aliases = <String, String>{
      'materia': 'subject',
      'matéria': 'subject',
      'assunto': 'deck',
      'baralho': 'deck',
      'pergunta': 'front',
      'frente': 'front',
      'resposta': 'back',
      'verso': 'back',
      'observacao': 'note',
      'observação': 'note',
      'fonte': 'source',
    };
    for (final rawLine in text.replaceAll('\r', '').split('\n')) {
      final line = rawLine.trim();
      final separator = line.indexOf(':');
      if (separator > 0) {
        final label = line.substring(0, separator).trim().toLowerCase();
        final key = aliases[label];
        if (key != null) {
          current = key;
          values[current] = line.substring(separator + 1).trim();
          continue;
        }
      }
      if (current != null && line.isNotEmpty) {
        final key = current;
        values[key] = '${values[key] ?? ''}\n$line'.trim();
      }
    }
    return values;
  }

  Future<void> _pasteStandardContent() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('A área de transferência está vazia.')));
      }
      return;
    }
    final values = _parseClipboardText(text);
    if (values.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não encontrei o formato padronizado. Use o prompt do menu.')));
      }
      return;
    }
    setState(() {
      if (values['subject'] != null) _subject.text = values['subject']!;
      if (values['deck'] != null) _deck.text = values['deck']!;
      if (values['front'] != null) _front.text = values['front']!;
      if (values['back'] != null) _back.text = values['back']!;
      if (values['note'] != null) _note.text = values['note']!;
      if (values['source'] != null) _source.text = values['source']!;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Conteúdo preenchido automaticamente.')));
    }
  }

  Future<void> _copyPrompt() async {
    await Clipboard.setData(const ClipboardData(text: _contestCardPrompt));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Prompt copiado. Cole em uma IA e depois cole o resultado aqui.')));
    }
  }

  @override
  void dispose() {
    for (final c in [_subject, _deck, _front, _back, _note, _source]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final card = ContestCard(
      id: widget.card?.id,
      subject: _subject.text.trim(),
      deck: _deck.text.trim(),
      front: _front.text.trim(),
      back: _back.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      source: _source.text.trim().isEmpty ? null : _source.text.trim(),
      createdAt: widget.card?.createdAt ?? now,
      updatedAt: now,
      nextReviewAt: widget.card?.nextReviewAt,
      easeFactor: widget.card?.easeFactor ?? 2.5,
      repetitions: widget.card?.repetitions ?? 0,
      interval: widget.card?.interval ?? 0,
    );
    if (widget.card == null) {
      await ref.read(contestCardListProvider.notifier).add(card);
    } else {
      await ref.read(contestCardListProvider.notifier).updateCard(card);
    }
    if (mounted) context.pop();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Preencha este campo' : null;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.card == null ? 'Novo cartão' : 'Editar cartão'),
            leading: const BackButton(),
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Ferramentas de IA',
                onSelected: (value) {
                  if (value == 'copy_prompt') _copyPrompt();
                  if (value == 'paste') _pasteStandardContent();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'copy_prompt',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.content_copy_outlined),
                      title: Text('Copiar prompt para IA'),
                      subtitle: Text('Gerar conteúdo padronizado'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'paste',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.content_paste_rounded),
                      title: Text('Colar conteúdo da IA'),
                      subtitle: Text('Preencher cartão automaticamente'),
                    ),
                  ),
                ],
              ),
            ]),
        body: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(20), children: [
              OutlinedButton.icon(
                  onPressed: _pasteStandardContent,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Colar conteúdo padronizado')),
              const SizedBox(height: 8),
              Text(
                'Use o menu ⋮ para copiar o prompt e gerar este formato em uma IA.',
                style: GoogleFonts.nunito(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Text('Organização',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _subject,
                  decoration: const InputDecoration(
                      labelText: 'Matéria', hintText: 'Direito Constitucional'),
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _deck,
                  decoration: const InputDecoration(
                      labelText: 'Assunto ou baralho',
                      hintText: 'Direitos fundamentais'),
                  validator: _required),
              const SizedBox(height: 24),
              Text('Conteúdo',
                  style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _front,
                  decoration:
                      const InputDecoration(labelText: 'Frente / pergunta'),
                  minLines: 3,
                  maxLines: 6,
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _back,
                  decoration:
                      const InputDecoration(labelText: 'Verso / resposta'),
                  minLines: 4,
                  maxLines: 10,
                  validator: _required),
              const SizedBox(height: 12),
              TextFormField(
                  controller: _note,
                  decoration:
                      const InputDecoration(labelText: 'Observação (opcional)'),
                  minLines: 2,
                  maxLines: 4),
              const SizedBox(height: 12),
              TextFormField(
                controller: _source,
                decoration: const InputDecoration(
                    labelText: 'Fonte (opcional)', hintText: 'CF/88, art. 5º'),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save_outlined),
                  label: const Text('Salvar cartão')),
            ])),
      );
}

class ContestReviewScreen extends ConsumerStatefulWidget {
  final String? subject;
  final String? deck;
  final String mode;
  const ContestReviewScreen(
      {super.key, this.subject, this.deck, this.mode = 'due'});
  @override
  ConsumerState<ContestReviewScreen> createState() =>
      _ContestReviewScreenState();
}

class _ContestReviewScreenState extends ConsumerState<ContestReviewScreen> {
  List<ContestCard> _cards = [];
  int _index = 0;
  bool _loading = true;
  bool _revealed = false;
  bool _answering = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repository = ref.read(contestCardRepositoryProvider);
    final all =
        await repository.getAll(subject: widget.subject, deck: widget.deck);
    final cards = switch (widget.mode) {
      'all' => all,
      'difficult' => all.where((card) => card.easeFactor < 2.5).toList(),
      _ => all
          .where((card) =>
              card.nextReviewAt == null ||
              !card.nextReviewAt!.isAfter(DateTime.now()))
          .toList(),
    };
    if (mounted) {
      setState(() {
        _cards = cards;
        _loading = false;
      });
    }
  }

  Future<void> _answer(int quality) async {
    if (_answering || _index >= _cards.length) return;
    setState(() => _answering = true);
    final card = _cards[_index];
    try {
      final result = computeSM2(
          currentInterval: card.interval,
          easeFactor: card.easeFactor,
          repetitions: card.repetitions,
          quality: quality);
      await ref.read(contestCardRepositoryProvider).updateReview(card.copyWith(
          nextReviewAt: result.nextReviewAt,
          easeFactor: result.easeFactor,
          repetitions: result.repetitions,
          interval: result.interval));
      // Atualiza imediatamente as telas que abriram a revisão. Assim, ao
      // voltar antes de concluir o baralho, o cartão já aparece com o novo
      // intervalo sem exigir sair e entrar novamente no aplicativo.
      ref.invalidate(contestCardListProvider);
    } catch (error) {
      if (mounted) {
        setState(() => _answering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível salvar a revisão: $error')),
        );
      }
      return;
    }
    if (!mounted) return;
    if (_index + 1 >= _cards.length) {
      ref.invalidate(contestCardListProvider);
      setState(() {
        _index++;
        _answering = false;
      });
    } else {
      setState(() {
        _index++;
        _revealed = false;
        _answering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_index >= _cards.length) {
      return Scaffold(
        appBar: AppBar(title: const Text('Revisão concluída')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.check_circle_outline,
                size: 80, color: AppTheme.primary),
            const SizedBox(height: 16),
            const Text('Muito bem!'),
            const SizedBox(height: 20),
            ElevatedButton(
                onPressed: () => context.pop(), child: const Text('Voltar')),
          ]),
        ),
      );
    }
    final card = _cards[_index];
    return Scaffold(
      appBar: AppBar(
        title: Text('Revisão ${_index + 1}/${_cards.length}'),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          LinearProgressIndicator(
              value: (_index + 1) / _cards.length, color: AppTheme.secondary),
          const SizedBox(height: 24),
          Text('${card.subject} · ${card.deck}',
              style: GoogleFonts.nunito(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: _ContestFlipCard(
                front: card.front,
                back: card.back,
                note: card.note,
                source: card.source,
                revealed: _revealed,
                onTap: () => setState(() => _revealed = !_revealed),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!_revealed)
            ElevatedButton.icon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Mostrar resposta'))
          else
            Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in [
                    (0, 'Errei', AppTheme.error),
                    (3, 'Difícil', AppTheme.warning),
                    (4, 'Bom', AppTheme.secondary),
                    (5, 'Fácil', AppTheme.primary),
                  ])
                    OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: item.$3,
                          side: BorderSide(color: item.$3, width: 1.5),
                          backgroundColor: item.$3.withValues(alpha: .12),
                        ),
                        onPressed: _answering ? null : () => _answer(item.$1),
                        child: Text(item.$2)),
                ]),
        ]),
      ),
    );
  }
}

class _ContestFlipCard extends StatefulWidget {
  final String front;
  final String back;
  final String? note;
  final String? source;
  final bool revealed;
  final VoidCallback onTap;

  const _ContestFlipCard({
    required this.front,
    required this.back,
    required this.note,
    required this.source,
    required this.revealed,
    required this.onTap,
  });

  @override
  State<_ContestFlipCard> createState() => _ContestFlipCardState();
}

class _ContestFlipCardState extends State<_ContestFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );

  @override
  void didUpdateWidget(covariant _ContestFlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revealed != widget.revealed) {
      widget.revealed ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * 3.141592653589793;
          final showBack = _controller.value >= .5;
          final content = showBack
              ? _ContestCardFace(
                  label: 'Resposta',
                  text: widget.back,
                  note: widget.note,
                  source: widget.source,
                  icon: Icons.lightbulb_outline_rounded,
                )
              : _ContestCardFace(
                  label: 'Pergunta',
                  text: widget.front,
                  icon: Icons.help_outline_rounded,
                );
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(showBack ? angle - 3.141592653589793 : angle),
            child: content,
          );
        },
      ),
    );
  }
}

class _ContestCardFace extends StatelessWidget {
  final String label;
  final String text;
  final String? note;
  final String? source;
  final IconData icon;

  const _ContestCardFace({
    required this.label,
    required this.text,
    required this.icon,
    this.note,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        // A área maior deixa a leitura confortável; textos muito longos
        // continuam rolando dentro da própria carta.
        height: 480,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.secondary, size: 30),
              const SizedBox(height: 16),
              Text(label.toUpperCase(),
                  style: GoogleFonts.nunito(
                      fontSize: 12,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
              Text(text,
                  style: GoogleFonts.nunito(
                      fontSize: 22, fontWeight: FontWeight.w900, height: 1.25)),
              if (note != null) ...[
                const Divider(height: 34),
                Text(note!,
                    style: GoogleFonts.nunito(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35)),
              ],
              if (source != null) ...[
                const SizedBox(height: 12),
                Text('Fonte: $source',
                    style: GoogleFonts.nunito(
                        fontSize: 13, fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
