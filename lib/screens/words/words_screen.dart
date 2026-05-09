import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/word_provider.dart';
import '../../models/word.dart';
import '../../core/theme/app_theme.dart';

Color _wordStatusColor(String s) =>
    s == 'learned' ? AppTheme.primary : s == 'difficult' ? AppTheme.error : AppTheme.secondary;

String _wordStatusLabel(String s) =>
    s == 'learning' ? 'Learning' : s == 'learned' ? 'Learned' : 'Difficult';

const _wordCategories = [
  'Work', 'Travel', 'Family', 'Daily Routine', 'Technology',
  'IELTS', 'Verbs', 'Adjectives', 'Useful Phrases',
  'Environmental Police', 'Immigration', 'Conversation',
];

const _wordStatuses = ['learning', 'learned', 'difficult'];

class WordsScreen extends ConsumerStatefulWidget {
  const WordsScreen({super.key});

  @override
  ConsumerState<WordsScreen> createState() => _WordsScreenState();
}

class _WordsScreenState extends ConsumerState<WordsScreen> {
  final _searchController = TextEditingController();
  String? _selectedCategory;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(wordListProvider.notifier).setFilter();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    ref.read(wordListProvider.notifier).setSearch(query);
    setState(() {
      _selectedCategory = null;
      _selectedStatus = null;
    });
  }

  void _onCategoryTap(String category) {
    final next = _selectedCategory == category ? null : category;
    setState(() {
      _selectedCategory = next;
      _selectedStatus = null;
      _searchController.clear();
    });
    ref.read(wordListProvider.notifier).setFilter(category: next);
  }

  void _onStatusTap(String status) {
    final next = _selectedStatus == status ? null : status;
    setState(() {
      _selectedStatus = next;
      _selectedCategory = null;
      _searchController.clear();
    });
    ref.read(wordListProvider.notifier).setFilter(status: next);
  }

  @override
  Widget build(BuildContext context) {
    final wordsAsync = ref.watch(wordListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Words'),
        leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/words/new'),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search words...',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ..._wordStatuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_wordStatusLabel(s)),
                    selected: _selectedStatus == s,
                    onSelected: (_) => _onStatusTap(s),
                    selectedColor: _wordStatusColor(s).withValues(alpha: 0.2),
                  ),
                )),
                ..._wordCategories.map((c) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(c),
                    selected: _selectedCategory == c,
                    onSelected: (_) => _onCategoryTap(c),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: wordsAsync.when(
              data: (words) => words.isEmpty
                  ? _EmptyState(onAdd: () => context.go('/words/new'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: words.length,
                      itemBuilder: (_, i) => _WordCard(word: words[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(child: Text('Erro ao carregar palavras.')),
            ),
          ),
        ],
      ),
    );
  }

}

class _WordCard extends StatelessWidget {
  final Word word;
  const _WordCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final color = _wordStatusColor(word.status);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          word.word,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          word.translation,
          style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            word.status[0].toUpperCase() + word.status.substring(1),
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        onTap: () => context.go('/words/${word.id}'),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'No words yet.',
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your first word!',
            style: GoogleFonts.nunito(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add Word'),
          ),
        ],
      ),
    );
  }
}
