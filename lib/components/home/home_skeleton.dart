import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shimmer/shimmer.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            Row(
              children: [
                _buildCircleSkeleton(40.r),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBoxSkeleton(width: 80.w, height: 10.h),
                    SizedBox(height: 6.h),
                    _buildBoxSkeleton(width: 150.w, height: 14.h),
                  ],
                )
              ],
            ),
            SizedBox(height: 24.h),
            _buildBoxSkeleton(
                width: double.infinity, height: 50.h, borderRadius: 50.r),
            SizedBox(height: 24.h),
            _buildBoxSkeleton(
                width: double.infinity, height: 180.h, borderRadius: 20.r),
            SizedBox(height: 32.h),
            _buildBoxSkeleton(width: 200.w, height: 20.h),
            SizedBox(height: 16.h),
            Row(
              children: [
                _buildProductCardSkeleton(),
                SizedBox(width: 16.w),
                _buildProductCardSkeleton(),
              ],
            ),
            SizedBox(height: 32.h),
            _buildBoxSkeleton(width: 180.w, height: 20.h),
            SizedBox(height: 16.h),
            Row(
              children: [
                _buildProductCardSkeleton(),
                SizedBox(width: 16.w),
                _buildProductCardSkeleton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoxSkeleton(
      {double? width, double? height, double borderRadius = 8}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  Widget _buildCircleSkeleton(double size) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildProductCardSkeleton() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBoxSkeleton(
              width: double.infinity, height: 120.h, borderRadius: 20.r),
          SizedBox(height: 12.h),
          _buildBoxSkeleton(width: 100.w, height: 14.h),
          SizedBox(height: 6.h),
          _buildBoxSkeleton(width: 60.w, height: 12.h),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBoxSkeleton(width: 50.w, height: 16.h),
              _buildCircleSkeleton(24.r),
            ],
          )
        ],
      ),
    );
  }
}
