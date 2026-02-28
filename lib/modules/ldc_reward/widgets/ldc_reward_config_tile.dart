import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../pages/webview_page.dart';
import '../../../services/toast_service.dart';
import '../providers/ldc_reward_provider.dart';

/// LDC 打赏凭证配置卡片（元宇宙页面用）
class LdcRewardConfigTile extends ConsumerWidget {
  const LdcRewardConfigTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credentialsAsync = ref.watch(ldcRewardCredentialsProvider);

    final isConfigured = credentialsAsync.value != null;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHigh,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _showConfigDialog(context, ref, isConfigured),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.volunteer_activism_rounded,
                  size: 32,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LDC 打赏',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isConfigured ? '已配置，可在帖子中打赏' : '配置凭证以启用打赏功能',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isConfigured ? Icons.check_circle : Icons.settings,
                color: isConfigured
                    ? Colors.green
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfigDialog(BuildContext context, WidgetRef ref, bool isConfigured) {
    final clientIdController = TextEditingController();
    final clientSecretController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('配置 LDC 打赏凭证'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '请输入在 credit.linux.do 申请的凭证',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => WebViewPage.open(
                  ctx,
                  'https://credit.linux.do/merchant',
                  title: '创建应用',
                ),
                child: Text(
                  '前往创建应用 →',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: clientIdController,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clientSecretController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isConfigured)
            TextButton(
              onPressed: () {
                ref.read(ldcRewardCredentialsProvider.notifier).clear();
                Navigator.pop(ctx);
                ToastService.showSuccess('凭证已清除');
              },
              child: Text(
                '清除凭证',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final clientId = clientIdController.text.trim();
              final clientSecret = clientSecretController.text.trim();
              if (clientId.isEmpty || clientSecret.isEmpty) {
                ToastService.showError('请填写完整的凭证信息');
                return;
              }
              ref
                  .read(ldcRewardCredentialsProvider.notifier)
                  .save(clientId, clientSecret);
              Navigator.pop(ctx);
              ToastService.showSuccess('凭证保存成功');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
