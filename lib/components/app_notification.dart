import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum NotificationType { success, error, info }

void showAppNotification(
  BuildContext context, {
  String? title,
  required String message,
  NotificationType type = NotificationType.info,
  String? imageUrl,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder: (context) => _AppNotificationWidget(
      title: title,
      message: message,
      type: type,
      imageUrl: imageUrl,
      onDismissed: () {
        overlayEntry.remove();
      },
    ),
  );

  overlay.insert(overlayEntry);
}

class _AppNotificationWidget extends StatefulWidget {
  final String? title;
  final String message;
  final NotificationType type;
  final String? imageUrl;
  final VoidCallback onDismissed;

  const _AppNotificationWidget({
    required this.message,
    required this.type,
    this.title,
    this.imageUrl,
    required this.onDismissed,
  });

  @override
  State<_AppNotificationWidget> createState() => _AppNotificationWidgetState();
}

class _AppNotificationWidgetState extends State<_AppNotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      reverseDuration: const Duration(milliseconds: 600),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -2.5),
      end: const Offset(0, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        _controller.reverse().then((_) {
          widget.onDismissed();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _iconBackgroundColor {
    switch (widget.type) {
      case NotificationType.success:
        return const Color(0xFF4CAF50);
      case NotificationType.error:
        return const Color(0xFFE53935);
      case NotificationType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData get _iconData {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_rounded;
      case NotificationType.error:
        return Icons.close_rounded;
      case NotificationType.info:
        return Icons.info_outline_rounded;
    }
  }

  String get _defaultTitle {
    switch (widget.type) {
      case NotificationType.success:
        return 'Sucesso';
      case NotificationType.error:
        return 'Atenção';
      case NotificationType.info:
        return 'Informação';
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleToUse = widget.title ?? _defaultTitle;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 16.h,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5D201C).withValues(alpha: 0.1),
                    blurRadius: 20.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Left Icon or Image Thumbnail
                  if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFFF0EE),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6961).withValues(alpha: 0.2),
                            blurRadius: 8.r,
                            offset: Offset(0, 2.h),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Icon(
                            Icons.fastfood_rounded,
                            color: const Color(0xFFFF6961),
                            size: 20.r,
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.fastfood_rounded,
                            color: const Color(0xFFFF6961),
                            size: 20.r,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40.w,
                      height: 40.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _iconBackgroundColor.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Icon(
                          _iconData,
                          color: _iconBackgroundColor,
                          size: 24.r,
                        ),
                      ),
                    ),

                  SizedBox(width: 16.w),

                  // Notification Text
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titleToUse,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.message,
                          style: TextStyle(
                            color: const Color(0xFF5D201C),
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
