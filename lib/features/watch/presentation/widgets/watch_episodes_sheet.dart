import 'package:flutter/material.dart';
import 'package:dramereel_mobile/app/i18n.dart';

class WatchEpisodesSheet extends StatefulWidget {
  const WatchEpisodesSheet({
    super.key,
    required this.seriesTitle,
    required this.totalEpisodes,
    required this.episodesPerPage,
    required this.episodesPages,
    required this.currentEpisodeNumber,
    required this.episodesByNumber,
    required this.onNeedPage,
    required this.onSelectEpisode,
    this.autoUnlockEnabled = false,
    this.onSetAutoUnlock,
  });

  final String seriesTitle;
  final int totalEpisodes;
  final int episodesPerPage;
  final int episodesPages;
  final int currentEpisodeNumber;
  final Map<int, dynamic> episodesByNumber;
  final bool autoUnlockEnabled;
  final ValueChanged<bool>? onSetAutoUnlock;
  final Future<void> Function(int page) onNeedPage;
  final void Function(int episodeNumber) onSelectEpisode;

  @override
  State<WatchEpisodesSheet> createState() => _WatchEpisodesSheetState();
}

class _WatchEpisodesSheetState extends State<WatchEpisodesSheet> {
  late final PageController _controller;
  late int _page;
  late bool _autoUnlock;

  @override
  void initState() {
    super.initState();
    _autoUnlock = widget.autoUnlockEnabled;
    _page = widget.episodesPerPage > 0 ? ((widget.currentEpisodeNumber - 1) ~/ widget.episodesPerPage) + 1 : 1;
    if (_page < 1) _page = 1;
    if (widget.episodesPages > 0 && _page > widget.episodesPages) _page = widget.episodesPages;
    _controller = PageController(initialPage: _page - 1);
    Future.microtask(() => widget.onNeedPage(_page));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppI18n.of(context);
    final perPage = widget.episodesPerPage > 0 ? widget.episodesPerPage : 30;
    final pages = widget.episodesPages > 0
        ? widget.episodesPages
        : (widget.totalEpisodes > 0 ? ((widget.totalEpisodes - 1) ~/ perPage) + 1 : 1);

    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.62,
          decoration: BoxDecoration(
            color: const Color(0xff0e0e14),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Drag Handle
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),

              // Sheet Top Header Bar: Close & Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.totalEpisodes > 0
                          ? '${t.t('Episodes')} (${widget.totalEpisodes})'
                          : t.t('Episodes'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // RANGE TABS (1-30, 31-60, 61-90...) - Full Width
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(pages, (i) {
                      final pageNum = i + 1;
                      final start = (i * perPage) + 1;
                      final end = ((i + 1) * perPage).clamp(
                        1,
                        widget.totalEpisodes > 0 ? widget.totalEpisodes : ((i + 1) * perPage),
                      );
                      final isCurrent = _page == pageNum;

                      return InkWell(
                        onTap: () {
                          setState(() => _page = pageNum);
                          if (_controller.hasClients) {
                            _controller.jumpToPage(i);
                          }
                          widget.onNeedPage(pageNum);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                start == end ? '$start' : '$start-$end',
                                style: TextStyle(
                                  color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.45),
                                  fontSize: 13,
                                  fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 2.5,
                                width: 24,
                                decoration: BoxDecoration(
                                  color: isCurrent ? const Color(0xffef233c) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),


              // 6-COLUMN EPISODE GRID (Page by Page)
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) async {
                    setState(() => _page = i + 1);
                    await widget.onNeedPage(_page);
                  },
                  itemCount: pages,
                  itemBuilder: (context, i) {
                    final page = i + 1;
                    final start = ((page - 1) * perPage) + 1;
                    final count = widget.totalEpisodes <= 0
                        ? 0
                        : (() {
                            final end = (start + perPage - 1).clamp(1, widget.totalEpisodes);
                            return end >= start ? (end - start + 1) : 0;
                          })();

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.15,
                      ),
                      itemCount: count,
                      itemBuilder: (context, j) {
                        final epNum = start + j;
                        final ep = widget.episodesByNumber[epNum];
                        final selected = epNum == widget.currentEpisodeNumber;
                        final unlocked = ep?.isUnlocked ?? false;

                        return InkWell(
                          onTap: () => widget.onSelectEpisode(epNum),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xff251522)
                                  : (unlocked ? const Color(0xff1a1a24) : const Color(0xff161620)),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xffef233c)
                                    : Colors.white.withValues(alpha: unlocked ? 0.06 : 0.035),
                                width: selected ? 1.6 : 1.0,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xffef233c).withValues(alpha: 0.30),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    epNum.toString(),
                                    style: TextStyle(
                                      color: selected
                                          ? Colors.white
                                          : (unlocked
                                              ? const Color(0xfff1f1f5)
                                              : const Color(0xff8b8b9e)),
                                      fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                                      fontSize: 14.5,
                                    ),
                                  ),
                                ),
                                if (!unlocked && !selected)
                                  PositionedDirectional(
                                    top: 4,
                                    end: 5,
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 10.5,
                                      color: const Color(0xff8b8b9e).withValues(alpha: 0.75),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Auto Unlock Bottom Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xff121218),
                  border: Border(
                    top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: _autoUnlock
                            ? const Color(0xffef233c)
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.bolt_rounded,
                        color: _autoUnlock ? Colors.white : Colors.white.withValues(alpha: 0.50),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            t.t('auto_unlock'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            t.t('auto_unlock_note'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.50),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Transform.scale(
                      scale: 0.82,
                      child: Switch(
                        value: _autoUnlock,
                        onChanged: (val) {
                          setState(() => _autoUnlock = val);
                          widget.onSetAutoUnlock?.call(val);
                        },
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xffef233c),
                        inactiveThumbColor: Colors.white.withValues(alpha: 0.6),
                        inactiveTrackColor: const Color(0xff272734),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
