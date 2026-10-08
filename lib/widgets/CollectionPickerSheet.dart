import 'package:flutter/material.dart';
import '../entity/LuoXue/Collection.dart';
import '../utils/AppTheme.dart';
import 'LxnsAssetImage.dart';

/// 收藏品选择器底部弹窗：在头像 / 姓名框两个 Tab 间切换并支持搜索。
/// 从 HomePage 中提取出来，方便在「我的」等其他页面复用。
class CollectionPickerSheet extends StatefulWidget {
  final TextEditingController searchController;
  final List<Collection> avatarIcons;
  final List<Collection> avatarPlates;
  final int? selectedAvatarId;
  final int? selectedPlateId;
  final ValueChanged<int> onAvatarPicked;
  final ValueChanged<int> onPlatePicked;

  const CollectionPickerSheet({
    super.key,
    required this.searchController,
    required this.avatarIcons,
    required this.avatarPlates,
    required this.selectedAvatarId,
    required this.selectedPlateId,
    required this.onAvatarPicked,
    required this.onPlatePicked,
  });

  @override
  State<CollectionPickerSheet> createState() => _CollectionPickerSheetState();
}

class _CollectionPickerSheetState extends State<CollectionPickerSheet> {
  // 状态放到 State 字段里，跟 sheet 实例生命周期绑定
  int _activeTab = 0; // 0=头像, 1=姓名框

  /// 头像网格每行几列：默认 4 列，可用下方步进器在 3~10 之间调。
  ///
  /// 为什么有上下限：少于 3 列一屏看不了几个头像（默认 4 列已经比原来的 3 列密），
  /// 多于 10 列时单个头像比网格间隙还小，只剩一片糊在一起的小图。
  /// 姓名框 tab 不受它影响 —— 那是 6:1 的长条 banner，必须一行一个。
  static const int _kDefaultAvatarColumns = 4;
  static const int _kMinAvatarColumns = 3;
  static const int _kMaxAvatarColumns = 10;
  int _avatarColumns = _kDefaultAvatarColumns;

  void _setAvatarColumns(int value) {
    final next = value.clamp(_kMinAvatarColumns, _kMaxAvatarColumns);
    if (next == _avatarColumns) return;
    setState(() => _avatarColumns = next);
  }

  void _switchTab(int tab) {
    setState(() {
      _activeTab = tab;
      widget.searchController.clear();
    });
  }

  /// 列数多时把网格间隙收窄：10 列时 8dp 间隙要吃掉 72dp（约两个半格子），
  /// 头像会缩得比间隙还小，看着像一堆孤立的点。
  double get _avatarGridGap => _avatarColumns >= 7 ? 4 : 8;

  /// 「每行 N 列」的 +/− 步进器（头像 tab 专用）。
  ///
  /// 用 IconButton 而不是自绘按钮：`onPressed: null` 时它**自己**会变灰且点不动，
  /// 触达区域、水波纹、tooltip 语义（无障碍）也都是现成的。
  Widget _buildColumnStepper(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '每行',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStepperButton(
                icon: Icons.remove,
                tooltip: '减少每行头像数',
                // 到下限就禁用（click 不会再进 _setAvatarColumns）
                onPressed: _avatarColumns > _kMinAvatarColumns
                    ? () => _setAvatarColumns(_avatarColumns - 1)
                    : null,
              ),
              // 数字框至少 26dp 宽：个位数变两位数时两边按钮不会跟着抖。
              // 用 minWidth 而不是死宽度 —— 系统字号放大到 2 倍时「10」需要更宽，
              // 死宽度会把字切掉。
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 26),
                child: Center(
                  child: Text(
                    '$_avatarColumns',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              _buildStepperButton(
                icon: Icons.add,
                tooltip: '增加每行头像数',
                onPressed: _avatarColumns < _kMaxAvatarColumns
                    ? () => _setAvatarColumns(_avatarColumns + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 34, height: 32),
    );
  }

  Widget _buildTabButton({
    required BuildContext ctx,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final brightness = Theme.of(ctx).brightness;
    final scheme = Theme.of(ctx).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? scheme.primary.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? scheme.primary
                  : AppColors.tableBorder(brightness),
              width: isActive ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              color: isActive
                  ? scheme.primary
                  : AppColors.primaryText(brightness),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final screenSize = MediaQuery.of(context).size;

    final List<Collection> currentList =
        _activeTab == 0 ? widget.avatarIcons : widget.avatarPlates;
    final int? currentSelectedId =
        _activeTab == 0 ? widget.selectedAvatarId : widget.selectedPlateId;
    final String searchHint =
        _activeTab == 0 ? '输入头像名称或描述搜索...' : '输入姓名框名称或描述搜索...';
    final String emptyText = _activeTab == 0 ? '未找到匹配的头像' : '未找到匹配的姓名框';

    // 根据关键词过滤
    final keyword = widget.searchController.text.trim().toLowerCase();
    final filteredItems = keyword.isEmpty
        ? List<Collection>.from(currentList)
        : currentList.where((c) {
            final matchName = c.name.toLowerCase().contains(keyword);
            final matchDesc =
                c.description?.toLowerCase().contains(keyword) ?? false;
            return matchName || matchDesc;
          }).toList();
    // 将当前选中项移到最前面
    final selectedIndex =
        filteredItems.indexWhere((c) => c.id == currentSelectedId);
    if (selectedIndex > 0) {
      final selected = filteredItems.removeAt(selectedIndex);
      filteredItems.insert(0, selected);
    }

    return Container(
      height: screenSize.height * 0.65,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏 + 头像列数步进器 + 关闭按钮
          //
          // 步进器放标题这一行（而不是网格上方单独一行）：弹窗高度只有屏幕的 65%，
          // 少一行就多给头像区域 ~40dp —— 那一行刚好能多显示半排头像。
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                // ⚠️ 必须是 Expanded（不是 Flexible + Spacer）：
                // 两者都带 flex，自由宽度会被**对半分**，标题只拿到一半
                // （360dp 屏上约 27dp），于是「选择收藏品」被压成「选择…」——
                // 明明右边还有空。Expanded 是唯一的 flex 子项，能吃掉**全部**剩余
                // 宽度把按钮顶到最右；同时 maxLines/ellipsis 仍然兜住极窄屏 / 大字号的
                // 溢出（那时才该省略）。
                Expanded(
                  child: Text('选择收藏品',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText(brightness))),
                ),
                // 姓名框是 6:1 的长条 banner，固定一行一个，不显示列数步进器
                if (_activeTab == 0) ...[
                  _buildColumnStepper(context),
                  const SizedBox(width: 4),
                ],
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // tab 切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildTabButton(
                  ctx: context,
                  label: '头像',
                  isActive: _activeTab == 0,
                  onTap: () => _switchTab(0),
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  ctx: context,
                  label: '姓名框',
                  isActive: _activeTab == 1,
                  onTap: () => _switchTab(1),
                ),
              ],
            ),
          ),
          // 搜索栏
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: widget.searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: searchHint,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: widget.searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          widget.searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.tableBorder(brightness)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: AppColors.tableBorder(brightness)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ),
          ),
          // 搜索结果数量（只在搜索时出现，平时不占高度 —— 列数步进器已经挪到标题那行了）
          if (keyword.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '找到 ${filteredItems.length} 个${_activeTab == 0 ? "头像" : "姓名框"}',
                  style: TextStyle(
                      fontSize: 13,
                      color: AppColors.greyHint(brightness, shade: 600)),
                ),
              ),
            ),
          const Divider(height: 1),
          // 网格
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off,
                            size: 48,
                            color: AppColors.greyHint(brightness, shade: 400)),
                        const SizedBox(height: 8),
                        Text(emptyText,
                            style: TextStyle(
                                color: AppColors.greyHint(brightness,
                                    shade: 500))),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      // 姓名框是长条形 banner 图片，使用 1 列 + 宽高比 6:1 避免被裁切/拉伸
                      // 头像列数由上方「每行」步进器决定（默认 4，可在 3~10 之间调）
                      crossAxisCount: _activeTab == 0 ? _avatarColumns : 1,
                      crossAxisSpacing: _activeTab == 0 ? _avatarGridGap : 8,
                      mainAxisSpacing: _activeTab == 0 ? _avatarGridGap : 8,
                      childAspectRatio: _activeTab == 0 ? 1 : 6,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];
                      final isSelected = item.id == currentSelectedId;
                      final imageUrl = _activeTab == 0
                          ? lxnsIconUrl(item.id)
                          : lxnsPlateUrl(item.id);
                      final scheme = Theme.of(context).colorScheme;
                      return GestureDetector(
                        onTap: () {
                          if (_activeTab == 0) {
                            widget.onAvatarPicked(item.id);
                          } else {
                            widget.onPlatePicked(item.id);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                  : AppColors.tableBorder(brightness),
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            // 用 LxnsAssetImage 而不是裸 CachedNetworkImage：
                            //   1. 磁盘缓存单开（2000 个名额），不再和排行榜头像 /
                            //      曲绘挤 DefaultCacheManager 的 200 个名额；
                            //   2. 零淡入 + 静态占位 —— 这个 sheet 每次拉起都重建
                            //      Widget 树，磁盘读是异步的，用转圈占位会让
                            //      「本地已命中」看起来像「正在联网」；
                            //   3. 自动按格子宽度限制解码尺寸，姓名框（720×116）
                            //      不再按原尺寸解码去挤 ImageCache。
                            child: LxnsAssetImage(
                              url: imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
