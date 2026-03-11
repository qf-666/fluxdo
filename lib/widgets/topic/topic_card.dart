import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/topic.dart';
import '../../models/category.dart';
import '../../providers/discourse_providers.dart';
import '../../constants.dart';
import '../../utils/font_awesome_helper.dart';
import '../common/topic_badges.dart';
import '../common/smart_avatar.dart';
import '../../services/discourse_cache_manager.dart';
import '../common/relative_time_text.dart';
import '../../utils/number_utils.dart';
import '../common/emoji_text.dart';

/// 话题卡片组件 — 极限压缩单行布局版
class TopicCard extends ConsumerWidget {
  final Topic topic;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final Color? highlightColor;
  final Widget? bottomWidget;

  const TopicCard({
    super.key,
    required this.topic,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.highlightColor,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = topic.unseen || topic.unread > 0;
    // 全部读完：进入过话题且没有未读帖子
    final isFullyRead = !topic.unseen && topic.unread == 0 && topic.lastReadPostNumber != null;

    // 获取分类信息
    final categoryMap = ref.watch(categoryMapProvider).value;
    final categoryId = int.tryParse(topic.categoryId);
    final category = categoryMap?[categoryId];

    // 图标逻辑优先级
    IconData? faIcon = FontAwesomeHelper.getIcon(category?.icon);
    String? logoUrl = category?.uploadedLogo;

    if (faIcon == null && (logoUrl == null || logoUrl.isEmpty) && category?.parentCategoryId != null) {
      final parent = categoryMap?[category!.parentCategoryId];
      faIcon = FontAwesomeHelper.getIcon(parent?.icon);
      logoUrl = parent?.uploadedLogo;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 1), // 极限外部间距
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : highlightColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), // 减小圆角
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5))
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: isFullyRead ? 0.5 : 1.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6), // 极限内部间距
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 左侧：楼主头像
                    _buildOriginalPosterAvatar(context),
                    const SizedBox(width: 8),
                    // 右侧：两行内容
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 第1行：标题 + 回复数/未读数
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      height: 1.2,
                                      color: isUnread
                                          ? theme.colorScheme.onSurface
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    children: [
                                      if (topic.closed)
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Icon(Icons.lock_outline, size: 14, color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                                          ),
                                        ),
                                      if (topic.hasAcceptedAnswer)
                                        const WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(Icons.check_box, size: 14, color: Colors.green),
                                          ),
                                        )
                                      else if (topic.canHaveAnswer)
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding: const EdgeInsets.only(right: 4),
                                            child: Icon(Icons.check_box_outline_blank, size: 14, color: theme.colorScheme.outline),
                                          ),
                                        ),
                                      ...EmojiText.buildEmojiSpans(context, topic.title, theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        height: 1.2,
                                        color: isUnread
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.onSurfaceVariant,
                                      )),
                                      if (topic.unseen)
                                        WidgetSpan(
                                          alignment: PlaceholderAlignment.middle,
                                          child: Container(
                                            margin: const EdgeInsets.only(left: 4),
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  maxLines: 1, // 强制单行
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              // 右上角：回复数或未读数
                              _buildReplyOrUnread(context),
                            ],
                          ),

                          const SizedBox(height: 3), // 极限行间距

                          // 第2行：分类+标签（左） + 点赞+时间（右）
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // 左侧：分类和标签
                              Expanded(
                                child: Wrap(
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: [
                                    if (category != null)
                                      CategoryBadge(
                                        category: category,
                                        faIcon: faIcon,
                                        logoUrl: logoUrl,
                                      ),
                                    ...topic.tags.map(
                                      (tag) => TagBadge(name: tag.name),
                                    ),
                                  ],
                                ),
                              ),
                              // 右侧：点赞 + 时间
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (topic.likeCount > 0) ...[
                                    _buildStat(context, Icons.favorite_border_rounded, topic.likeCount),
                                    const SizedBox(width: 4),
                                    Text(
                                      '·',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  RelativeTimeText(
                                    dateTime: topic.lastPostedAt,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 底部附属区域
            if (bottomWidget != null)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.fromLTRB(40, 4, 8, 4), // 适配缩小后的头像占位
                child: bottomWidget!,
              ),
          ],
        ),
      ),
    );
  }

  /// 构建楼主头像
  Widget _buildOriginalPosterAvatar(BuildContext context) {
    final theme = Theme.of(context);
    const double avatarRadius = 12.0; // 头像缩小到 24x24

    if (topic.posters.isNotEmpty) {
      final op = topic.posters.first;
      if (op.user != null) {
        final avatarUrl = op.user!.avatarTemplate.startsWith('http')
            ? op.user!.getAvatarUrl(size: 48)
            : '${AppConstants.baseUrl}${op.user!.getAvatarUrl(size: 48)}';
        return SmartAvatar(
          imageUrl: avatarUrl,
          radius: avatarRadius,
          fallbackText: op.user!.username,
        );
      }
    }
    // fallback
    if (topic.lastPosterUsername != null) {
      return CircleAvatar(
        radius: avatarRadius,
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          topic.lastPosterUsername![0].toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      );
    }
    return const SizedBox(width: avatarRadius * 2, height: avatarRadius * 2);
  }

  /// 回复数/未读数切换
  Widget _buildReplyOrUnread(BuildContext context) {
    final theme = Theme.of(context);
    if (topic.unread > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${topic.unread}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
        ),
      );
    } else {
      final replies = (topic.postsCount - 1).clamp(0, 999999);
      if (replies <= 0) return const SizedBox.shrink();
      final heatColor = _replyHeatColor(topic, theme);
      return _buildStat(
        context,
        Icons.chat_bubble_outline_rounded,
        replies,
        color: heatColor,
        bold: heatColor != null,
      );
    }
  }

  /// 计算 likes/posts 比率
  double _heatRatio(Topic topic) {
    if (topic.postsCount < 10) return 0;
    return topic.likeCount / topic.postsCount;
  }

  /// 回复数热度颜色
  Color? _replyHeatColor(Topic topic, ThemeData theme) {
    final ratio = _heatRatio(topic);
    if (ratio > 2.0) return const Color(0xFFFE7A15);
    if (ratio > 1.0) return const Color(0xFFCF7721);
    if (ratio > 0.5) return const Color(0xFF9B764F);
    return null;
  }

  Widget _buildStat(BuildContext context, IconData icon, int count, {Color? color, bool bold = false}) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: effectiveColor),
        const SizedBox(width: 2),
        Text(
          NumberUtils.formatCount(count),
          style: theme.textTheme.labelSmall?.copyWith(
            color: effectiveColor,
            fontSize: 11,
            fontWeight: bold ? FontWeight.w700 : null,
          ),
        ),
      ],
    );
  }
}

/// 紧凑型话题卡片 - 用于置顶话题 (同步极限瘦身)
class CompactTopicCard extends ConsumerWidget {
  final Topic topic;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool isSelected;
  final Color? highlightColor;

  const CompactTopicCard({
    super.key,
    required this.topic,
    this.onTap,
    this.onLongPress,
    this.isSelected = false,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isUnread = topic.unseen || topic.unread > 0;

    // 获取分类信息
    final categoryMap = ref.watch(categoryMapProvider).value;
    final categoryId = int.tryParse(topic.categoryId);
    final category = categoryMap?[categoryId];

    // 图标逻辑
    IconData? faIcon = FontAwesomeHelper.getIcon(category?.icon);
    String? logoUrl = category?.uploadedLogo;

    if (faIcon == null && (logoUrl == null || logoUrl.isEmpty) && category?.parentCategoryId != null) {
      final parent = categoryMap?[category!.parentCategoryId];
      faIcon = FontAwesomeHelper.getIcon(parent?.icon);
      logoUrl = parent?.uploadedLogo;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 1), // 极限外部间距
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
          : highlightColor ?? theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6), // 减小圆角
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5))
            : BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), // 极限内部间距
          child: Row(
            children: [
              // 1. 置顶图标
              Icon(Icons.push_pin_rounded, size: 12, color: theme.colorScheme.primary),
              const SizedBox(width: 6),

              // 2. 分类图标/Dot
              if (category != null) ...[
                if (faIcon != null)
                  FaIcon(faIcon, size: 10, color: _parseColor(category.color))
                else if (logoUrl != null && logoUrl.isNotEmpty)
                  Image(
                    image: discourseImageProvider(
                      logoUrl.startsWith('http') ? logoUrl : '${AppConstants.baseUrl}$logoUrl',
                    ),
                    width: 10,
                    height: 10,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _buildCategoryDot(category),
                  )
                else
                  _buildCategoryDot(category),
                const SizedBox(width: 6),
              ],

              // 3. 标题
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                      color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      if (topic.closed)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Icon(Icons.lock_outline, size: 10, color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      if (topic.hasAcceptedAnswer)
                        const WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: EdgeInsets.only(right: 3),
                            child: Icon(Icons.check_box, size: 10, color: Colors.green),
                          ),
                        )
                      else if (topic.canHaveAnswer)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: Icon(Icons.check_box_outline_blank, size: 10, color: theme.colorScheme.outline),
                          ),
                        ),
                      ...EmojiText.buildEmojiSpans(context, topic.title, theme.textTheme.labelMedium?.copyWith(
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                        color: isUnread ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                      )),
                    ],
                  ),
                  maxLines: 1, // 置顶帖也保持绝对单行
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(width: 6),

              // 4. 未读数或简单状态
              if (topic.unread > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${topic.unread}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                      fontSize: 8,
                    ),
                  ),
                )
              else if (topic.postsCount > 1)
                 Row(
                   children: [
                     Icon(Icons.chat_bubble_outline_rounded, size: 10, color: theme.colorScheme.outline.withValues(alpha: 0.7)),
                     const SizedBox(width: 2),
                     Text(
                        '${topic.postsCount - 1}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.outline.withValues(alpha: 0.7),
                          fontSize: 9,
                        ),
                     ),
                   ],
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryDot(Category category) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: _parseColor(category.color),
        shape: BoxShape.circle,
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('0xFF$hex'));
    }
    return Colors.grey;
  }
}
