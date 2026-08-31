import 'package:flutter/material.dart';

import '../core/constants.dart';

enum IbulPageStateKind { empty, error, loading }

/// Shared empty / error / loading primitive. Defaults match existing
/// marketplace copy and sizes — callers pass the same icon/title they had.
class IbulPageState extends StatelessWidget {
  const IbulPageState.empty({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.iconSize = 64,
    this.iconColor,
    this.titleSize = 16,
    this.titleWeight = FontWeight.w400,
    this.titleColor,
    this.messageSize = 14,
    this.messageColor,
    this.padding = const EdgeInsets.all(24),
    this.outlinedAction = false,
    this.actionPadding,
    this.actionRadius,
    this.gapAfterIcon,
    this.gapBeforeAction,
    this.useTextAction = false,
  }) : kind = IbulPageStateKind.empty,
       loadingMessage = null;

  const IbulPageState.error({
    super.key,
    required this.title,
    this.icon = Icons.cloud_off_outlined,
    this.message,
    this.actionLabel = 'Tekrar Dene',
    this.onAction,
    this.iconSize = 52,
    this.iconColor,
    this.titleSize = 18,
    this.titleWeight = FontWeight.w700,
    this.titleColor,
    this.messageSize = 14,
    this.messageColor,
    this.padding = const EdgeInsets.all(32),
    this.outlinedAction = true,
    this.actionPadding,
    this.actionRadius,
    this.gapAfterIcon,
    this.gapBeforeAction,
    this.useTextAction = false,
  }) : kind = IbulPageStateKind.error,
       loadingMessage = null;

  const IbulPageState.loading({
    super.key,
    this.loadingMessage,
    this.padding = const EdgeInsets.all(24),
  }) : kind = IbulPageStateKind.loading,
       icon = Icons.hourglass_empty,
       title = '',
       message = null,
       actionLabel = null,
       onAction = null,
       iconSize = 24,
       iconColor = null,
       titleSize = 14,
       titleWeight = FontWeight.w400,
       titleColor = null,
       messageSize = 14,
       messageColor = null,
       outlinedAction = false,
       actionPadding = null,
       actionRadius = null,
       gapAfterIcon = null,
       gapBeforeAction = null,
       useTextAction = false;

  final IbulPageStateKind kind;
  final IconData icon;
  final String title;
  final String? message;
  final String? loadingMessage;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;
  final Color? iconColor;
  final double titleSize;
  final FontWeight titleWeight;
  final Color? titleColor;
  final double messageSize;
  final Color? messageColor;
  final EdgeInsetsGeometry padding;
  final bool outlinedAction;
  final EdgeInsetsGeometry? actionPadding;
  final double? actionRadius;
  final double? gapAfterIcon;
  final double? gapBeforeAction;
  final bool useTextAction;

  @override
  Widget build(BuildContext context) {
    if (kind == IbulPageStateKind.loading) {
      return Semantics(
        label: loadingMessage ?? 'Yükleniyor',
        child: Center(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                if (loadingMessage != null) ...[
                  const SizedBox(height: 16),
                  ExcludeSemantics(
                    child: Text(
                      loadingMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: messageSize,
                        color: messageColor ?? AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final resolvedIconColor = iconColor ?? AppColors.iconMuted;
    final resolvedTitleColor = titleColor ??
        (kind == IbulPageStateKind.error
            ? AppColors.onSurface
            : AppColors.onSurfaceMuted);
    final resolvedMessageColor = messageColor ?? AppColors.onSurfaceMuted;

    return Semantics(
      container: true,
      liveRegion: kind == IbulPageStateKind.error,
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            ExcludeSemantics(
              child: Icon(icon, size: iconSize, color: resolvedIconColor),
            ),
            SizedBox(height: gapAfterIcon ?? (iconSize >= 56 ? 16 : 10)),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: titleWeight,
                color: resolvedTitleColor,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: messageSize,
                  color: resolvedMessageColor,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: gapBeforeAction ?? (message != null ? 20 : 16)),
              _buildAction(),
            ],
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildAction() {
    if (useTextAction) {
      return TextButton(
        onPressed: onAction,
        child: Text(actionLabel!),
      );
    }
    final padding = actionPadding ??
        const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
    if (outlinedAction) {
      return OutlinedButton(
        onPressed: onAction,
        child: Text(actionLabel!),
      );
    }
    return ElevatedButton(
      onPressed: onAction,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        padding: padding,
        shape: actionRadius == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(actionRadius!),
              ),
      ),
      child: Text(
        actionLabel!,
        style: actionRadius == null
            ? null
            : const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
