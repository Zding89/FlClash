import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter/material.dart';

class SubscriptionInfoView extends StatelessWidget {
  final SubscriptionInfo? subscriptionInfo;
  final bool showUnknown;
  final DateTime? updatedAt;

  const SubscriptionInfoView({
    super.key,
    this.subscriptionInfo,
    this.showUnknown = false,
    this.updatedAt,
  });

  @override
  Widget build(BuildContext context) {
    final metadata = SubscriptionMetadata.fromInfo(
      subscriptionInfo,
      updatedAt: updatedAt,
    );
    if (!showUnknown && !metadata.trafficKnown && !metadata.expiryKnown) {
      return const SizedBox.shrink();
    }
    final strings = context.appLocalizations;
    final expireShow = metadata.unlimited
        ? strings.infiniteTime
        : metadata.expiryDate ?? strings.policyExpiryUnknown;
    final trafficShow = metadata.trafficKnown
        ? '${metadata.usedBytes!.traffic.show} / ${metadata.totalBytes!.traffic.show}'
        : strings.policyTrafficUnknown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.trafficKnown) ...[
          LinearProgressIndicator(
            minHeight: 6,
            value: (metadata.usedBytes! / metadata.totalBytes!).clamp(0, 1),
            backgroundColor: context.colorScheme.primary.opacity15,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          '$trafficShow · $expireShow',
          style: context.textTheme.labelMedium?.toLight,
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
