import 'package:flutter/material.dart';

class CampaignActionMenu extends StatelessWidget {
  const CampaignActionMenu({
    this.onDetail,
    this.onEdit,
    this.onPause,
    this.onResume,
    this.onDelete,
    this.onApprove,
    this.onReject,
    this.onStop,
    this.onReviewAgain,
    this.onHistory,
    this.onOpenSeller,
    this.isPaused = false,
    this.isAdmin = false,
    super.key,
  });

  final VoidCallback? onDetail;
  final VoidCallback? onEdit;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDelete;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onStop;
  final VoidCallback? onReviewAgain;
  final VoidCallback? onHistory;
  final VoidCallback? onOpenSeller;
  final bool isPaused;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Aksiyonlar',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'detail', child: Text('Detay')),
        if (!isAdmin) ...[
          const PopupMenuItem(value: 'edit', child: Text('Duzenle')),
          PopupMenuItem(
            value: isPaused ? 'resume' : 'pause',
            child: Text(isPaused ? 'Devam ettir' : 'Duraklat'),
          ),
          const PopupMenuItem(value: 'delete', child: Text('Sil')),
        ] else ...[
          const PopupMenuItem(value: 'approve', child: Text('Onayla')),
          const PopupMenuItem(value: 'reject', child: Text('Reddet')),
          const PopupMenuItem(value: 'stop', child: Text('Durdur')),
          const PopupMenuItem(
            value: 'review_again',
            child: Text('Tekrar incelemeye al'),
          ),
          const PopupMenuItem(value: 'seller', child: Text('Saticiyi ac')),
          const PopupMenuItem(value: 'history', child: Text('Gecmisi gor')),
        ],
      ],
      onSelected: (value) {
        switch (value) {
          case 'detail':
            onDetail?.call();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'pause':
            onPause?.call();
            break;
          case 'resume':
            onResume?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          case 'approve':
            onApprove?.call();
            break;
          case 'reject':
            onReject?.call();
            break;
          case 'stop':
            onStop?.call();
            break;
          case 'review_again':
            onReviewAgain?.call();
            break;
          case 'seller':
            onOpenSeller?.call();
            break;
          case 'history':
            onHistory?.call();
            break;
        }
      },
      child: const Icon(Icons.more_vert_rounded),
    );
  }
}
