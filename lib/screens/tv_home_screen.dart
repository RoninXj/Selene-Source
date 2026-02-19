import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/douban_movie.dart';
import '../models/play_record.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../services/page_cache_service.dart';
import '../services/search_service.dart';
import '../services/user_data_service.dart';
import '../utils/font_utils.dart';
import 'player_screen.dart';

class TvHomeScreen extends StatefulWidget {
  const TvHomeScreen({super.key});

  @override
  State<TvHomeScreen> createState() => _TvHomeScreenState();
}

class _TvHomeScreenState extends State<TvHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Map<String, String> _typeLabels = const {
    'all': '全部',
    'movie': '电影',
    'tv': '剧集',
    'anime': '动漫',
    'show': '综艺',
  };

  List<SearchResult> _searchResults = [];
  List<PlayRecord> _playRecords = [];
  List<DoubanMovie> _hotMovies = [];
  List<DoubanMovie> _hotTvShows = [];

  bool _isSearching = false;
  bool _isLoadingHistory = true;
  bool _isLoadingRecommend = true;
  String _activeType = 'all';
  String _searchQuery = '';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadPlayRecords();
    _loadRecommendData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPlayRecords() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final recordsResult = await PageCacheService().getPlayRecords(context);
      if (!mounted) return;

      setState(() {
        _playRecords = recordsResult.success ? (recordsResult.data ?? []) : [];
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _playRecords = [];
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadRecommendData() async {
    setState(() {
      _isLoadingRecommend = true;
    });

    try {
      final movies = await PageCacheService().getHotMovies(context);
      final tvShows = await PageCacheService().getHotTvShows(context);
      if (!mounted) return;

      setState(() {
        _hotMovies = movies ?? [];
        _hotTvShows = tvShows ?? [];
        _isLoadingRecommend = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hotMovies = [];
        _hotTvShows = [];
        _isLoadingRecommend = false;
      });
    }
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
      _errorText = null;
      _activeType = 'all';
      _searchResults = [];
    });

    try {
      final isLocalMode = await UserDataService.getIsLocalMode();
      final isLocalSearch = await UserDataService.getLocalSearch();

      final List<SearchResult> results;
      if (isLocalMode || isLocalSearch) {
        results = await SearchService.searchSync(query);
      } else {
        results = await ApiService.fetchSourcesData(query);
      }

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _errorText = '没有找到与 "$query" 相关的内容';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorText = '搜索失败: $e';
      });
    }
  }

  List<SearchResult> get _filteredResults {
    if (_activeType == 'all') {
      return _searchResults;
    }

    return _searchResults.where((item) {
      final episodeCount = item.episodes.length;
      final text = '${item.typeName ?? ''} ${item.class_ ?? ''}'.toLowerCase();

      switch (_activeType) {
        case 'movie':
          return text.contains('movie') ||
              text.contains('film') ||
              text.contains('电影') ||
              episodeCount <= 1;
        case 'tv':
          return text.contains('剧') ||
              text.contains('tv') ||
              text.contains('series') ||
              episodeCount > 1;
        case 'anime':
          return text.contains('anime') ||
              text.contains('animation') ||
              text.contains('动漫') ||
              text.contains('番');
        case 'show':
          return text.contains('综艺') ||
              text.contains('variety') ||
              text.contains('show');
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _openPlayRecord(PlayRecord record) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          source: record.source,
          id: record.id,
          title: record.title,
          year: record.year,
          stitle: record.searchTitle,
        ),
      ),
    );

    if (mounted) {
      _loadPlayRecords();
    }
  }

  Future<void> _openSearchResult(SearchResult result) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          source: result.source,
          id: result.id,
          title: result.title,
          year: result.year,
          stitle: _searchQuery,
          stype: result.episodes.length > 1 ? 'tv' : 'movie',
        ),
      ),
    );

    if (mounted) {
      _loadPlayRecords();
    }
  }

  Future<void> _openRecommend(DoubanMovie item, String stype) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: item.title,
          year: item.year,
          stype: stype,
        ),
      ),
    );

    if (mounted) {
      _loadPlayRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colors = isDarkMode
        ? [const Color(0xFF000000), const Color(0xFF000000)]
        : [
            const Color(0xFFe6f3fb),
            const Color(0xFFeaf3f7),
            const Color(0xFFf7f7f3),
            const Color(0xFFe9ecef),
            const Color(0xFFdbe3ea),
            const Color(0xFFd3dde6),
          ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
            stops: isDarkMode ? null : const [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(isDarkMode),
                const SizedBox(height: 18),
                _buildSearchBar(isDarkMode),
                if (_isSearching) ...[
                  const SizedBox(height: 14),
                  const LinearProgressIndicator(
                    color: Color(0xFF27AE60),
                    minHeight: 3,
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _errorText!,
                    style: FontUtils.poppins(
                      fontSize: 14,
                      color: const Color(0xFFe74c3c),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _buildHistorySection(isDarkMode),
                const SizedBox(height: 16),
                _buildRecommendSection(isDarkMode),
                const SizedBox(height: 16),
                _buildTypeFilters(isDarkMode),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildResultSection(isDarkMode),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDarkMode) {
    return Row(
      children: [
        Text(
          'Selene TV',
          style: FontUtils.sourceCodePro(
            fontSize: 32,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF27AE60).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            'TV',
            style: FontUtils.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF27AE60),
              letterSpacing: 0.8,
            ),
          ),
        ),
        const Spacer(),
        _TvFocusableAction(
          onPressed: () {
            _loadPlayRecords();
            _loadRecommendData();
            if (_searchQuery.isNotEmpty) {
              _search();
            }
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDarkMode
                  ? const Color(0xFF1e1e1e)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '刷新',
              style: FontUtils.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            style: FontUtils.poppins(
              fontSize: 18,
              color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: '搜索电影、剧集、动漫、综艺',
              hintStyle: FontUtils.poppins(
                fontSize: 16,
                color: isDarkMode
                    ? const Color(0xFF666666)
                    : const Color(0xFF95a5a6),
              ),
              filled: true,
              fillColor: isDarkMode
                  ? const Color(0xFF1e1e1e)
                  : Colors.white.withValues(alpha: 0.95),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
        ),
        const SizedBox(width: 14),
        _TvFocusableAction(
          onPressed: _search,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2ecc71), Color(0xFF27ae60)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '搜索',
              style: FontUtils.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection(bool isDarkMode) {
    if (_isLoadingHistory) {
      return const SizedBox(
        height: 170,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF27AE60)),
        ),
      );
    }

    if (_playRecords.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF161616)
              : Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '暂无播放记录，先试试上方搜索',
          style: FontUtils.poppins(
            fontSize: 14,
            color: isDarkMode ? const Color(0xFFb0b0b0) : const Color(0xFF7f8c8d),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '继续观看',
          style: FontUtils.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _playRecords.length > 12 ? 12 : _playRecords.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final record = _playRecords[index];
              return SizedBox(
                width: 238,
                child: _TvFocusableAction(
                  onPressed: () => _openPlayRecord(record),
                  borderRadius: BorderRadius.circular(12),
                  child: _HistoryCard(record: record, isDarkMode: isDarkMode),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTypeFilters(bool isDarkMode) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _typeLabels.entries.map((entry) {
        final isActive = _activeType == entry.key;

        return _TvFocusableAction(
          onPressed: () {
            setState(() {
              _activeType = entry.key;
            });
          },
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFF27AE60)
                  : (isDarkMode
                      ? const Color(0xFF1e1e1e)
                      : Colors.white.withValues(alpha: 0.88)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              entry.value,
              style: FontUtils.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (isDarkMode ? const Color(0xFFd0d0d0) : const Color(0xFF34495e)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecommendSection(bool isDarkMode) {
    if (_isLoadingRecommend) {
      return const SizedBox(
        height: 116,
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Color(0xFF27AE60),
            ),
          ),
        ),
      );
    }

    final cards = <_RecommendCardData>[
      ..._hotMovies
          .take(6)
          .map((item) => _RecommendCardData(item: item, stype: 'movie')),
      ..._hotTvShows
          .take(6)
          .map((item) => _RecommendCardData(item: item, stype: 'tv')),
    ];

    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '热门推荐',
          style: FontUtils.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final card = cards[index];
              return SizedBox(
                width: 262,
                child: _TvFocusableAction(
                  onPressed: () => _openRecommend(card.item, card.stype),
                  borderRadius: BorderRadius.circular(12),
                  child: _RecommendCard(
                    item: card.item,
                    stype: card.stype,
                    isDarkMode: isDarkMode,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultSection(bool isDarkMode) {
    final filtered = _filteredResults;
    if (_searchQuery.isEmpty) {
      return Center(
        child: Text(
          '输入关键词开始搜索',
          style: FontUtils.poppins(
            fontSize: 15,
            color: isDarkMode ? const Color(0xFF888888) : const Color(0xFF95a5a6),
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '当前筛选下没有内容',
          style: FontUtils.poppins(
            fontSize: 15,
            color: isDarkMode ? const Color(0xFF888888) : const Color(0xFF95a5a6),
          ),
        ),
      );
    }

    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: GridView.builder(
        padding: const EdgeInsets.only(top: 2, bottom: 6),
        itemCount: filtered.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 5,
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 0.70,
        ),
        itemBuilder: (context, index) {
          final item = filtered[index];
          return _TvFocusableAction(
            onPressed: () => _openSearchResult(item),
            borderRadius: BorderRadius.circular(12),
            child: _SearchResultCard(
              item: item,
              isDarkMode: isDarkMode,
            ),
          );
        },
      ),
    );
  }
}

class _RecommendCardData {
  final DoubanMovie item;
  final String stype;

  const _RecommendCardData({
    required this.item,
    required this.stype,
  });
}

class _RecommendCard extends StatelessWidget {
  final DoubanMovie item;
  final String stype;
  final bool isDarkMode;

  const _RecommendCard({
    required this.item,
    required this.stype,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF171717)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: _PosterImage(
              imageUrl: item.poster,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FontUtils.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${stype == 'movie' ? '电影' : '剧集'} · ${item.year.isEmpty ? "未知年份" : item.year}',
                    style: FontUtils.poppins(
                      fontSize: 11,
                      color: isDarkMode
                          ? const Color(0xFF9f9f9f)
                          : const Color(0xFF7f8c8d),
                    ),
                  ),
                  if (item.rate != null && item.rate!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '豆瓣 ${item.rate}',
                      style: FontUtils.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF27AE60),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PlayRecord record;
  final bool isDarkMode;

  const _HistoryCard({
    required this.record,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final progress = record.progressPercentage;

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF161616)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PosterImage(
              imageUrl: record.cover,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtils.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: progress,
                    backgroundColor: isDarkMode
                        ? const Color(0xFF2d2d2d)
                        : const Color(0xFFe6ecf0),
                    color: const Color(0xFF27AE60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final SearchResult item;
  final bool isDarkMode;

  const _SearchResultCard({
    required this.item,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final typeTag = (item.typeName?.isNotEmpty ?? false)
        ? item.typeName!
        : (item.class_?.isNotEmpty ?? false)
            ? item.class_!
            : item.episodes.length > 1
                ? '剧集'
                : '电影';

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF171717)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _PosterImage(
                    imageUrl: item.poster,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      typeTag,
                      style: FontUtils.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtils.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : const Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.sourceName} · ${item.year.isEmpty ? "未知年份" : item.year}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtils.poppins(
                    fontSize: 11,
                    color: isDarkMode
                        ? const Color(0xFF9f9f9f)
                        : const Color(0xFF7f8c8d),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterImage extends StatelessWidget {
  final String imageUrl;
  final BorderRadius borderRadius;

  const _PosterImage({
    required this.imageUrl,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: imageUrl.isEmpty
          ? Container(
              color: const Color(0xFF2f3640),
              alignment: Alignment.center,
              child: const Icon(Icons.movie, color: Colors.white70, size: 36),
            )
          : CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF2f3640),
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image, color: Colors.white70, size: 34),
              ),
              placeholder: (_, __) => Container(
                color: const Color(0xFF2f3640),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
    );
  }
}

class _TvFocusableAction extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  const _TvFocusableAction({
    required this.child,
    required this.onPressed,
    required this.borderRadius,
  });

  @override
  State<_TvFocusableAction> createState() => _TvFocusableActionState();
}

class _TvFocusableActionState extends State<_TvFocusableAction> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        if (mounted) {
          setState(() {
            _focused = value;
          });
        }
      },
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 130),
        scale: _focused ? 1.03 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            border: Border.all(
              color: _focused
                  ? const Color(0xFF27AE60)
                  : Colors.transparent,
              width: 2.2,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0x4D27AE60),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: widget.borderRadius,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
