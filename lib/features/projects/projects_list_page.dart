import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'project_provider.dart';
import '../../models/project.dart';
import 'project_detail_page.dart';
import '../../providers/license_provider.dart';
import '../../models/license_model.dart';
import '../../screens/purchase_screen.dart';

class ProjectsListPage extends ConsumerStatefulWidget {
  const ProjectsListPage({super.key});

  @override
  ConsumerState<ProjectsListPage> createState() => _ProjectsListPageState();
}

class _ProjectsListPageState extends ConsumerState<ProjectsListPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  bool _isAlphabetVisible = true;

  final List<String> _alphabet = [
    'A',
    'B',
    'C',
    'Ç',
    'D',
    'E',
    'F',
    'G',
    'Ğ',
    'H',
    'I',
    'İ',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'Ö',
    'P',
    'Q',
    'R',
    'S',
    'Ş',
    'T',
    'U',
    'Ü',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  @override
  void initState() {
    super.initState();
    // 🚨 YENİ: Sayfa açılınca mutlaka yenile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(projectProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, List<Project>> _groupProjects(List<Project> projects) {
    final grouped = <String, List<Project>>{};

    for (var project in projects) {
      if (project.name.isEmpty) continue;

      if (_searchQuery.isNotEmpty) {
        final searchLower = _searchQuery.toLowerCase();
        final projectNameLower = project.name.toLowerCase();
        if (!projectNameLower.contains(searchLower)) continue;
      }

      String firstLetter = project.name[0].toUpperCase();
      if (firstLetter == 'I') firstLetter = 'İ';

      if (!_alphabet.contains(firstLetter)) {
        if (firstLetter == 'Ç') {
          firstLetter = 'C';
        } else if (firstLetter == 'Ğ')
          firstLetter = 'G';
        else if (firstLetter == 'İ')
          firstLetter = 'I';
        else if (firstLetter == 'Ö')
          firstLetter = 'O';
        else if (firstLetter == 'Ş')
          firstLetter = 'S';
        else if (firstLetter == 'Ü')
          firstLetter = 'U';
        else
          firstLetter = '#';
      }

      grouped.putIfAbsent(firstLetter, () => []);
      grouped[firstLetter]!.add(project);
    }

    grouped.forEach((key, value) {
      value.sort((a, b) => a.name.compareTo(b.name));
    });

    return grouped;
  }

  void _scrollToSection(
    String letter,
    Map<String, List<Project>> groupedProjects,
  ) {
    final letterIndex = _alphabet.indexOf(letter);
    if (letterIndex == -1) return;

    int itemCount = 0;
    for (int i = 0; i < letterIndex; i++) {
      final currentLetter = _alphabet[i];
      if (groupedProjects.containsKey(currentLetter)) {
        itemCount += 1 + groupedProjects[currentLetter]!.length;
      }
    }

    final searchOffset = _searchQuery.isNotEmpty ? 1 : 0;
    itemCount += searchOffset;

    final estimatedPosition = (itemCount * 60.0) + 40.0;

    _scrollController.animateTo(
      estimatedPosition,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 DEĞİŞTİ: AsyncValue olarak dinle
    final projectsAsync = ref.watch(projectProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projelerim'),
        centerTitle: true,
        actions: [
          // 🚨 YENİ: Manuel yenileme butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(projectProvider.notifier).refresh();
            },
            tooltip: 'Yenile',
          ),
          IconButton(
            icon: Icon(
              _isAlphabetVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _isAlphabetVisible = !_isAlphabetVisible;
              });
            },
            tooltip: 'Alfabetik Sıralama',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Proje ara...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
      ),
      // 🚨 DEĞİŞTİ: AsyncValue ile handle et
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Hata: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(projectProvider.notifier).refresh(),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
        data: (projects) {
          final groupedProjects = _groupProjects(projects);
          return Column(
            children: [
              // 🔔 Deneme banner'ı
              _buildTrialBanner(),
              Expanded(child: _buildContent(groupedProjects)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrialBanner() {
    final licenseAsync = ref.watch(licenseProvider);
    return licenseAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (lic) {
        // Lisanslıysa banner gösterme
        if (lic.isLicensed) return const SizedBox.shrink();

        final daysLeft = lic.trialDaysLeft ?? 0;
        final Color bgColor;
        final String text;

        if (daysLeft > 5) {
          bgColor = Colors.blue.shade600;
          text = 'Deneme süresi: $daysLeft gün kaldı';
        } else if (daysLeft > 0) {
          bgColor = Colors.orange.shade700;
          text = 'Deneme süresi: $daysLeft gün kaldı!';
        } else {
          bgColor = Colors.red.shade700;
          text = 'Deneme süreniz doldu';
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: bgColor,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const PurchaseScreen()),
                  );
                  if (result == true) ref.invalidate(licenseProvider);
                },
                child: const Text(
                  'Lisans Al',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Henüz Proje Yok',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Text(
            'Yeni proje oluşturmak için ana sayfaya dönün',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Ana Sayfaya Dön'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(Map<String, List<Project>> groupedProjects) {
    final hasSearchResults = groupedProjects.isNotEmpty;
    final hasNoSearchResults = _searchQuery.isNotEmpty && !hasSearchResults;

    if (hasNoSearchResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('"$_searchQuery" için sonuç bulunamadı'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        _buildProjectList(groupedProjects),
        if (_isAlphabetVisible) _buildAlphabetSidebar(groupedProjects),
      ],
    );
  }

  Widget _buildProjectList(Map<String, List<Project>> groupedProjects) {
    return ListView(
      controller: _scrollController,
      children: [
        if (_searchQuery.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Row(
              children: [
                Icon(Icons.search, size: 20, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '"$_searchQuery" için ${_countTotalProjects(groupedProjects)} sonuç',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        for (var letter in _alphabet)
          if (groupedProjects.containsKey(letter)) ...[
            _buildSectionHeader(letter, groupedProjects[letter]!.length),
            ...groupedProjects[letter]!.map(
              (project) => _buildProjectItem(project),
            ),
          ],
      ],
    );
  }

  int _countTotalProjects(Map<String, List<Project>> groupedProjects) {
    return groupedProjects.values.fold(0, (sum, list) => sum + list.length);
  }

  Widget _buildSectionHeader(String letter, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Row(
        children: [
          Text(
            letter,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 100, 100, 100),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectItem(Project project) {
    final date = DateTime.tryParse(project.createdAt) ?? DateTime.now();
    final formattedDate = '${date.day}/${date.month}/${date.year}';

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber, size: 28),
        title: Text(
          project.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          formattedDate,
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProjectDetailPage(project: project),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildAlphabetSidebar(Map<String, List<Project>> groupedProjects) {
    return Positioned(
      right: 8,
      top: 80,
      bottom: 8 + MediaQuery.of(context).padding.bottom,
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 8, spreadRadius: 1),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: _alphabet.map((letter) {
                    final hasProjects = groupedProjects.containsKey(letter);
                    return InkWell(
                      onTap: hasProjects
                          ? () => _scrollToSection(letter, groupedProjects)
                          : null,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        child: Text(
                          letter,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: hasProjects
                                ? Colors.blue.shade800
                                : Colors.grey.shade300,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
