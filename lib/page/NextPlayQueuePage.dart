import 'package:flutter/material.dart';
import '../service/NextPlayQueueStore.dart';
import '../widgets/PageTopBar.dart';
import '../utils/CommonWidgetUtil.dart';
import '../utils/CoverUtil.dart';
import '../utils/AppTheme.dart';
import 'SongInfoPage.dart';

class NextPlayQueuePage extends StatefulWidget {
  const NextPlayQueuePage({super.key});
  @override
  State<NextPlayQueuePage> createState() => _NextPlayQueuePageState();
}

class _NextPlayQueuePageState extends State<NextPlayQueuePage> {
  final _store = NextPlayQueueStore.instance;

  @override
  void initState() {
    super.initState();
    _store.ensureLoaded();
    _store.addListener(_changed);
  }

  @override
  void dispose() {
    _store.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  @override
  Widget build(BuildContext context) {
    final entries = _store.entries;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Theme.of(context).colorScheme.surface),
          CommonWidgetUtil.buildCommonBgWidget(),
          CommonWidgetUtil.buildCommonChiffonBgWidget(context),
          Column(children: [
            PageTopBar(title: '下次想玩', actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(child: Text('${entries.length} 首')),
              ),
            ]),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('还没有加入歌曲\n在歌曲详情或随身听中点「加入下次想玩」吧'))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                      itemCount: entries.length,
                      buildDefaultDragHandles: false,
                      onReorder: _store.reorder,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return Card(
                          key: ValueKey(entry.occurrenceId),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SongInfoPage(songId: entry.songId),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(children: [
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CoverUtil.buildCoverWidget(
                                        entry.songId, 62)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Row(children: [
                                        if (entry.type != null &&
                                            entry.type!.isNotEmpty)
                                          _typeTag(context, entry.type!),
                                        const SizedBox(width: 6),
                                        Expanded(
                                            child: Text(entry.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15))),
                                      ]),
                                      const SizedBox(height: 5),
                                      Text(
                                          entry.artist.isEmpty
                                              ? '未知艺术家'
                                              : entry.artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant)),
                                      const SizedBox(height: 5),
                                      if (entry.difficultyIndices.isNotEmpty)
                                        Wrap(
                                          spacing: 5,
                                          runSpacing: 4,
                                          children: entry.difficultyIndices
                                              .map((index) => _difficultyTag(
                                                  context, index))
                                              .toList(),
                                        )
                                      else
                                        Text('未指定难度',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant)),
                                      if (entry.note.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text('备注：${entry.note}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary)),
                                      ],
                                    ])),
                                const SizedBox(width: 4),
                                Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                          tooltip: '移除这一次',
                                          icon: const Icon(
                                              Icons.remove_circle_outline),
                                          onPressed: () => _store
                                              .remove(entry.occurrenceId)),
                                      ReorderableDragStartListener(
                                          index: index,
                                          child: const Icon(Icons.drag_handle)),
                                    ]),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _typeTag(BuildContext context, String type) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(4)),
        child: Text(type,
            style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
      );

  Widget _difficultyTag(BuildContext context, int index) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.difficultyBackgroundByIndex(index,
        brightness: brightness);
    final foreground = AppColors.difficultyForegroundByIndex(index,
        brightness: brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: foreground.withOpacity(.65)),
      ),
      child: Text(
        _difficultyName(index),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }

  String _difficultyName(int index) => const [
        'BASIC',
        'ADVANCED',
        'EXPERT',
        'MASTER',
        'Re:MASTER',
        'UTAGE'
      ][index.clamp(0, 5)];
}
