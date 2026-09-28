import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NhacMenuTile extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final Future<void> Function() onTap;

  const NhacMenuTile({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.onTap,
  });

  @override
  State<NhacMenuTile> createState() => _NhacMenuTileState();
}

class _NhacMenuTileState extends State<NhacMenuTile> {
  bool _isTapped = false;

  void _handleTap() async {
    if (_isTapped) return;
    setState(() => _isTapped = true);
    await widget.onTap();
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isTapped = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _handleTap,
      child: Container(
        color: Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 18.h),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.titulo,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: const Color(0xFF5D201C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.subtitulo != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    widget.subtitulo!,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16.r,
              color: const Color(0xFF5D201C),
            ),
          ],
        ),
      ),
    );
  }
}
