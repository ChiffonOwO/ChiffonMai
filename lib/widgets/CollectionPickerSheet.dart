import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../entity/LuoXue/Collection.dart';
import '../utils/AppTheme.dart';

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

  void _switchTab(int tab) {
    setState(() {
      _activeTab = tab;
      widget.searchController.clear();
    });
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
          // 标题栏 + 关闭按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text('选择收藏品',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText(brightness))),
                const Spacer(),
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
          // 搜索结果数量
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
                      // 头像保持 3 列正方形网格
                      crossAxisCount: _activeTab == 0 ? 3 : 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: _activeTab == 0 ? 1 : 6,
                    ),
                    itemCount: filteredItems.length,
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];
                      final isSelected = item.id == currentSelectedId;
                      final imageUrl = _activeTab == 0
                          ? 'https://assets2.lxns.net/maimai/icon/${item.id}.png'
                          : 'https://assets2.lxns.net/maimai/plate/${item.id}.png';
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
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              placeholder: (ctx, url) => const Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                              errorWidget: (ctx, url, err) =>
                                  const Icon(Icons.error, size: 20),
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
