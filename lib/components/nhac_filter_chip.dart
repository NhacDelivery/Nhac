import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Mantém o estilo dos filtros e identifica opções ainda indisponíveis.
class NhacFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final String? unavailableReason;

  const NhacFilterChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final unavailable = unavailableReason != null;
    final chip = ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: unavailable ? null : (_) => onSelected?.call(),
      showCheckmark: false,
      avatar: unavailable
          ? Icon(Icons.lock_outline_rounded, size: 14.r, color: Colors.grey)
          : null,
      labelStyle: TextStyle(
        fontSize: 12.sp,
        fontWeight: FontWeight.w600,
        color: unavailable
            ? Colors.grey.shade600
            : selected
                ? Colors.white
                : const Color(0xFF5D201C),
      ),
      backgroundColor: Colors.white,
      disabledColor: const Color(0xFFF5F1F0),
      selectedColor: const Color(0xFFFF6961),
      side: BorderSide(
        color: selected ? Colors.transparent : const Color(0xFFFFE7E5),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    return unavailable
        ? Semantics(
            label: '$label. $unavailableReason',
            child: Tooltip(message: unavailableReason!, child: chip),
          )
        : chip;
  }
}
