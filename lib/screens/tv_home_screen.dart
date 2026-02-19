import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/douban_movie.dart';
import '../models/favorite_item.dart';
import '../models/play_record.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../services/page_cache_service.dart';
import '../services/search_service.dart';
import '../services/theme_service.dart';
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

  int _topTab = 0;
  int _bottomTab = 0;
  bool _loading = true;
  bool _showSearch = false;
  bool _searching = false;
  String? _error;

  List<PlayRecord> _records = [];
  List<FavoriteItem> _favorites = [];
  List<DoubanMovie> _movies = [];
  List<DoubanMovie> _tvs = [];
  List<DoubanMovie> _shows = [];
  List<SearchResult> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cache = PageCacheService();
      final list = await Future.wait([
        cache.getPlayRecords(context),
        cache.getFavorites(context),
        cache.getHotMovies(context),
        cache.getHotTvShows(context),
        cache.getHotShows(context),
      ]);

      if (!mounted) return;
      final playRes = list[0] as dynamic;
      final favRes = list[1] as dynamic;

      setState(() {
        _records = playRes.success ? (playRes.data ?? []) : [];
        _favorites = favRes.success ? (favRes.data ?? []) : [];
        _movies = (list[2] as List<DoubanMovie>?) ?? [];
        _tvs = (list[3] as List<DoubanMovie>?) ?? [];
        _shows = (list[4] as List<DoubanMovie>?) ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '加载失败: $e';
      });
    }
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;

    setState(() {
      _searching = true;
      _error = null;
    });

    try {
      final localMode = await UserDataService.getIsLocalMode();
      final localSearch = await UserDataService.getLocalSearch();
      final results = localMode || localSearch
          ? await SearchService.searchSync(q)
          : await ApiService.fetchSourcesData(q);

      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _topTab = 0;
        _searching = false;
        if (results.isEmpty) _error = '没有找到“$q”';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = '搜索失败: $e';
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _error = null;
      _showSearch = false;
    });
  }

  Future<void> _openRecord(PlayRecord item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: item.source,
          id: item.id,
          title: item.title,
          year: item.year,
          stitle: item.searchTitle,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Future<void> _openFavorite(FavoriteItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: item.source,
          id: item.id,
          title: item.title,
          year: item.year,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Future<void> _openSearch(SearchResult item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          source: item.source,
          id: item.id,
          title: item.title,
          year: item.year,
          stitle: _searchController.text.trim(),
          stype: item.episodes.length > 1 ? 'tv' : 'movie',
        ),
      ),
    );
    if (mounted) _loadData();
  }

  Future<void> _openRecommend(DoubanMovie item, String stype) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          title: item.title,
          year: item.year,
          stype: stype,
        ),
      ),
    );
    if (mounted) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeService>();

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: theme.isDarkMode ? const Color(0xFF000000) : null,
          gradient: theme.isDarkMode
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFe6f3fb),
                    Color(0xFFeaf3f7),
                    Color(0xFFf7f7f3),
                    Color(0xFFe9ecef),
                    Color(0xFFdbe3ea),
                    Color(0xFFd3dde6),
                  ],
                  stops: [0.0, 0.18, 0.38, 0.60, 0.80, 1.0],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(theme),
              if (_showSearch) _buildSearchBar(theme),
              _buildTopTabs(theme),
              if (_searching)
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF27AE60),
                ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF27AE60),
                        ),
                      )
                    : _buildContent(theme),
              ),
              _buildBottomNav(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeService theme) {
    final fg = theme.isDarkMode ? const Color(0xFFffffff) : const Color(0xFF2c3e50);

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: theme.isDarkMode
          ? const Color(0xFF1e1e1e).withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.82),
      child: Row(
        children: [
          _FocusBtn(
            onPressed: () {
              setState(() => _showSearch = !_showSearch);
              if (_showSearch) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _searchFocusNode.requestFocus();
                });
              }
            },
            child: Icon(Icons.search, color: fg, size: 24),
          ),
          const Spacer(),
          Text(
            'Selene',
            style: FontUtils.sourceCodePro(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.2,
              color: fg,
            ),
          ),
          const Spacer(),
          _FocusBtn(
            onPressed: () => theme.toggleTheme(context),
            child: Icon(theme.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: fg, size: 22),
          ),
          const SizedBox(width: 8),
          _FocusBtn(
            onPressed: () {},
            child: Icon(Icons.person_outline, color: fg, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeService theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              style: FontUtils.poppins(
                fontSize: 16,
                color: theme.isDarkMode ? const Color(0xFFffffff) : const Color(0xFF2c3e50),
              ),
              decoration: InputDecoration(
                hintText: '搜索电影、剧集、动漫、综艺',
                hintStyle: FontUtils.poppins(
                  fontSize: 14,
                  color: theme.isDarkMode ? const Color(0xFF888888) : const Color(0xFF95a5a6),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: theme.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _FocusBtn(
            onPressed: _search,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '搜索',
                style: FontUtils.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _FocusBtn(
            onPressed: _clearSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: theme.isDarkMode ? const Color(0xFF2a2a2a) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '关闭',
                style: FontUtils.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.isDarkMode ? const Color(0xFFd0d0d0) : const Color(0xFF7f8c8d),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildTopTabs(ThemeService theme) {
    const tabs = ['首页', '播放历史', '收藏夹'];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: theme.isDarkMode ? const Color(0xFF2a2a2a) : const Color(0xFFE8ECEF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(tabs.length, (i) {
            final active = _topTab == i;
            return _FocusBtn(
              onPressed: () => setState(() => _topTab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? (theme.isDarkMode ? const Color(0xFF1e1e1e) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tabs[i],
                  style: FontUtils.poppins(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: theme.isDarkMode ? const Color(0xFFd8d8d8) : const Color(0xFF7f8c8d),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeService theme) {
    if (_topTab == 1) return _buildRecordGrid(theme);
    if (_topTab == 2) return _buildFavoriteGrid(theme);

    final sections = <Widget>[];
    if (_error != null && _searchResults.isEmpty) {
      sections.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            _error!,
            style: FontUtils.poppins(fontSize: 14, color: const Color(0xFFe74c3c)),
          ),
        ),
      );
    }

    if (_searchResults.isNotEmpty) {
      sections.add(_buildSection(
        theme,
        '搜索结果',
        _searchResults.take(16).map((e) {
          return _PosterItem(
            title: e.title,
            subtitle: e.sourceName,
            poster: e.poster,
            badge: e.episodes.length > 1 ? '${e.episodes.length}集' : null,
            onTap: () => _openSearch(e),
          );
        }).toList(),
      ));
    }

    if (_bottomTab == 0) {
      sections.add(_buildSection(
        theme,
        '继续观看',
        _records.take(16).map((e) {
          return _PosterItem(
            title: e.title,
            subtitle: e.sourceName,
            poster: e.cover,
            badge: '${e.index}/${e.totalEpisodes}',
            onTap: () => _openRecord(e),
          );
        }).toList(),
      ));
    }

    if (_bottomTab == 0 || _bottomTab == 1) {
      sections.add(_buildSection(
        theme,
        '热门电影',
        _movies.take(16).map((e) {
          return _PosterItem(
            title: e.title,
            subtitle: e.year,
            poster: e.poster,
            badge: e.rate,
            onTap: () => _openRecommend(e, 'movie'),
          );
        }).toList(),
      ));
    }

    if (_bottomTab == 0 || _bottomTab == 2 || _bottomTab == 3) {
      sections.add(_buildSection(
        theme,
        _bottomTab == 3 ? '动漫推荐' : '热门剧集',
        _tvs.take(16).map((e) {
          return _PosterItem(
            title: e.title,
            subtitle: e.year,
            poster: e.poster,
            badge: e.rate,
            onTap: () => _openRecommend(e, 'tv'),
          );
        }).toList(),
      ));
    }

    if (_bottomTab == 0 || _bottomTab == 4) {
      sections.add(_buildSection(
        theme,
        '热门综艺',
        _shows.take(16).map((e) {
          return _PosterItem(
            title: e.title,
            subtitle: e.year,
            poster: e.poster,
            badge: e.rate,
            onTap: () => _openRecommend(e, 'show'),
          );
        }).toList(),
      ));
    }

    if (_bottomTab == 5) {
      sections.add(
        Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.isDarkMode ? const Color(0xFF161616) : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '直播入口将在 TV 版下一迭代接入。',
              style: FontUtils.poppins(
                fontSize: 14,
                color: theme.isDarkMode ? const Color(0xFFd0d0d0) : const Color(0xFF7f8c8d),
              ),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 8),
      children: sections,
    );
  }

  Widget _buildSection(ThemeService theme, String title, List<_PosterItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          child: Row(
            children: [
              Text(
                title,
                style: FontUtils.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: theme.isDarkMode ? const Color(0xFFffffff) : const Color(0xFF2c3e50),
                ),
              ),
              const Spacer(),
              Text(
                '查看更多 >',
                style: FontUtils.poppins(
                  fontSize: 13,
                  color: theme.isDarkMode ? const Color(0xFF888888) : const Color(0xFF95a5a6),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 302,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              return SizedBox(
                width: 172,
                child: _FocusBtn(
                  onPressed: item.onTap,
                  child: _PosterCard(item: item, dark: theme.isDarkMode),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecordGrid(ThemeService theme) {
    if (_records.isEmpty) {
      return Center(
        child: Text(
          '暂无播放记录',
          style: FontUtils.poppins(
            fontSize: 14,
            color: theme.isDarkMode ? const Color(0xFFb0b0b0) : const Color(0xFF7f8c8d),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      itemCount: _records.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (_, i) {
        final e = _records[i];
        return _FocusBtn(
          onPressed: () => _openRecord(e),
          child: _PosterCard(
            dark: theme.isDarkMode,
            item: _PosterItem(
              title: e.title,
              subtitle: e.sourceName,
              poster: e.cover,
              badge: '${e.index}/${e.totalEpisodes}',
              onTap: () => _openRecord(e),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteGrid(ThemeService theme) {
    if (_favorites.isEmpty) {
      return Center(
        child: Text(
          '暂无收藏',
          style: FontUtils.poppins(
            fontSize: 14,
            color: theme.isDarkMode ? const Color(0xFFb0b0b0) : const Color(0xFF7f8c8d),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      itemCount: _favorites.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (_, i) {
        final e = _favorites[i];
        return _FocusBtn(
          onPressed: () => _openFavorite(e),
          child: _PosterCard(
            dark: theme.isDarkMode,
            item: _PosterItem(
              title: e.title,
              subtitle: e.sourceName,
              poster: e.cover,
              badge: e.totalEpisodes > 0 ? '${e.totalEpisodes}集' : null,
              onTap: () => _openFavorite(e),
            ),
          ),
        );
      },
    );
  }
  Widget _buildBottomNav(ThemeService theme) {
    const items = [
      (Icons.home_outlined, '首页'),
      (Icons.movie_creation_outlined, '电影'),
      (Icons.tv_outlined, '剧集'),
      (Icons.auto_awesome_outlined, '动漫'),
      (Icons.local_activity_outlined, '综艺'),
      (Icons.live_tv_outlined, '直播'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      decoration: BoxDecoration(
        color: theme.isDarkMode
            ? const Color(0xFF1e1e1e).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(items.length, (i) {
          final active = _bottomTab == i;
          final color = active
              ? const Color(0xFF27AE60)
              : (theme.isDarkMode ? const Color(0xFFb0b0b0) : const Color(0xFF7f8c8d));

          return _FocusBtn(
            onPressed: () => setState(() {
              _bottomTab = i;
              _topTab = 0;
            }),
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[i].$1, size: 24, color: color),
                  const SizedBox(height: 3),
                  Text(
                    items[i].$2,
                    style: FontUtils.poppins(
                      fontSize: 12,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PosterItem {
  final String title;
  final String subtitle;
  final String poster;
  final String? badge;
  final VoidCallback onTap;

  const _PosterItem({
    required this.title,
    required this.subtitle,
    required this.poster,
    this.badge,
    required this.onTap,
  });
}

class _PosterCard extends StatelessWidget {
  final _PosterItem item;
  final bool dark;

  const _PosterCard({required this.item, required this.dark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF161616) : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                    child: item.poster.isEmpty
                        ? Container(
                            color: const Color(0xFF2f3640),
                            alignment: Alignment.center,
                            child: const Icon(Icons.movie, color: Colors.white70, size: 34),
                          )
                        : CachedNetworkImage(
                            imageUrl: item.poster,
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
                                  strokeWidth: 2.0,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
                if (item.badge != null && item.badge!.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.badge!,
                        style: FontUtils.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
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
                    color: dark ? Colors.white : const Color(0xFF2c3e50),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FontUtils.poppins(
                    fontSize: 11,
                    color: dark ? const Color(0xFF9f9f9f) : const Color(0xFF7f8c8d),
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

class _FocusBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _FocusBtn({required this.child, required this.onPressed});

  @override
  State<_FocusBtn> createState() => _FocusBtnState();
}

class _FocusBtnState extends State<_FocusBtn> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) {
        if (!mounted) return;
        setState(() => _focused = value);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _focused ? 1.03 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _focused ? const Color(0xFF27AE60) : Colors.transparent,
              width: 2.2,
            ),
            boxShadow: _focused
                ? const [
                    BoxShadow(
                      color: Color(0x4D27AE60),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(10),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
