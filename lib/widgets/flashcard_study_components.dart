import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class StudyHeader extends StatelessWidget {
  const StudyHeader({
    super.key,
    required this.reviewed,
    required this.total,
    required this.rememberedCount,
  });

  final int reviewed;
  final int total;
  final int rememberedCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Row(
      children: <Widget>[
        HeaderChip(
          icon: Icons.local_fire_department_rounded,
          label: '$reviewed/$total',
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        HeaderChip(
          icon: Icons.check_circle_rounded,
          label: '$rememberedCount nhớ',
          color: Colors.green,
        ),
        const Spacer(),
        Icon(Icons.swipe_rounded, color: secondaryText),
      ],
    );
  }
}

class HeaderChip extends StatelessWidget {
  const HeaderChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkCard
            : Colors.white.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppColors.lavender,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class ActionRow extends StatelessWidget {
  const ActionRow({
    super.key,
    required this.compactHeight,
    required this.onDelete,
    required this.onForget,
    required this.onRemember,
    required this.onEdit,
  });

  final bool compactHeight;
  final VoidCallback onDelete;
  final VoidCallback onForget;
  final VoidCallback onRemember;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        MiniActionButton(
          compactHeight: compactHeight,
          onTap: onDelete,
          icon: Icons.delete_rounded,
          backgroundColor: Colors.white,
          borderColor: Colors.redAccent,
          iconColor: Colors.redAccent,
        ),
        DecisionButton(
          compactHeight: compactHeight,
          onTap: onForget,
          icon: Icons.close_rounded,
          borderColor: Colors.deepOrangeAccent,
          iconColor: Colors.deepOrangeAccent,
          label: 'Quên',
        ),
        DecisionButton(
          compactHeight: compactHeight,
          onTap: onRemember,
          icon: Icons.check_rounded,
          borderColor: AppColors.deepPurple,
          iconColor: AppColors.deepPurple,
          label: 'Nhớ',
        ),
        MiniActionButton(
          compactHeight: compactHeight,
          onTap: onEdit,
          icon: Icons.edit_rounded,
          backgroundColor: Colors.white,
          borderColor: AppColors.periwinkle,
          iconColor: AppColors.deepPurple,
        ),
      ],
    );
  }
}

class MiniActionButton extends StatelessWidget {
  const MiniActionButton({
    super.key,
    required this.compactHeight,
    required this.onTap,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
  });

  final bool compactHeight;
  final VoidCallback onTap;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkCard : backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: compactHeight ? 44 : 52,
          height: compactHeight ? 44 : 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Icon(icon, color: iconColor),
        ),
      ),
    );
  }
}

class DecisionButton extends StatelessWidget {
  const DecisionButton({
    super.key,
    required this.compactHeight,
    required this.onTap,
    required this.icon,
    required this.borderColor,
    required this.iconColor,
    required this.label,
  });

  final bool compactHeight;
  final VoidCallback onTap;
  final IconData icon;
  final Color borderColor;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Material(
          color: isDark ? AppColors.darkCard : Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: compactHeight ? 58 : 70,
              height: compactHeight ? 58 : 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 2.2),
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
          ),
        ),
        if (!compactHeight) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: borderColor,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class EmptyStudyState extends StatelessWidget {
  const EmptyStudyState({super.key, required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? AppColors.darkCard : Colors.white;
    final Color primaryText = isDark
        ? AppColors.darkText
        : AppColors.deepPurple;
    final Color secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.credit_card_rounded,
                color: AppColors.deepPurple,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Chưa có flashcard nào trong bộ này',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bấm dấu cộng để thêm thẻ thủ công và bắt đầu ôn tập.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, height: 1.45),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm flashcard'),
            ),
          ],
        ),
      ),
    );
  }
}

class CompletedStudyState extends StatelessWidget {
  const CompletedStudyState({
    super.key,
    required this.reviewed,
    required this.total,
    required this.remembered,
    required this.forgotten,
    required this.onRestart,
    required this.onAdd,
  });

  final int reviewed;
  final int total;
  final int remembered;
  final int forgotten;
  final VoidCallback onRestart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? AppColors.darkCard : Colors.white;
    final Color primaryText = isDark
        ? AppColors.darkText
        : AppColors.deepPurple;
    final Color secondaryText = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(30),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.deepPurple,
                size: 42,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bạn đã học hết bộ flashcard này',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã hoàn thành $reviewed/$total thẻ. Bấm restart để học lại từ đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryText, height: 1.45),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                SummaryChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Nhớ $remembered',
                  color: Colors.green,
                ),
                SummaryChip(
                  icon: Icons.close_rounded,
                  label: 'Quên $forgotten',
                  color: Colors.deepOrangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRestart,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Restart bộ thẻ'),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm flashcard mới'),
            ),
          ],
        ),
      ),
    );
  }
}

class SummaryChip extends StatelessWidget {
  const SummaryChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
