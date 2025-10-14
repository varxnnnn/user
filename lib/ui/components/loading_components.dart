import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Reusable loading components for consistent shimmer animations across the app
class LoadingComponents {
  
  /// Generic shimmer container
  static Widget shimmerContainer({
    required double width,
    required double height,
    double borderRadius = 12.0,
    Color? baseColor,
    Color? highlightColor,
  }) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? Colors.grey[300]!,
      highlightColor: highlightColor ?? Colors.grey[100]!,
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

  /// Home screen loading skeleton
  static Widget homeScreenLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  shimmerContainer(width: 50, height: 50, borderRadius: 25),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      shimmerContainer(width: 80, height: 16),
                      const SizedBox(height: 4),
                      shimmerContainer(width: 40, height: 14),
                    ],
                  ),
                ],
              ),
              shimmerContainer(width: 100, height: 40, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 20),

          // Categories
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      shimmerContainer(width: 60, height: 60, borderRadius: 30),
                      const SizedBox(height: 5),
                      shimmerContainer(width: 60, height: 12),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Reward Cards
          SizedBox(
            height: 140,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: shimmerContainer(
                    width: screenWidth * 0.8,
                    height: 140,
                    borderRadius: 16,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Vouchers Section
          shimmerContainer(width: 120, height: 16),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      shimmerContainer(width: 120, height: 160, borderRadius: 12),
                      const SizedBox(height: 8),
                      shimmerContainer(width: 100, height: 30, borderRadius: 8),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Tasks Section
          shimmerContainer(width: 120, height: 16),
          const SizedBox(height: 10),
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: shimmerContainer(
                width: double.infinity,
                height: 60,
                borderRadius: 45,
              ),
            );
          }),
          const SizedBox(height: 20),

          // Explore Section
          shimmerContainer(
            width: double.infinity,
            height: 100,
            borderRadius: 16,
          ),
          const SizedBox(height: 20),

          // Top Winners
          shimmerContainer(width: 150, height: 16),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: shimmerContainer(width: 50, height: 50, borderRadius: 25),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// List screen loading skeleton (for polls, quizzes, surveys)
  static Widget listScreenLoading(double screenWidth, double screenHeight) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: shimmerContainer(
            width: double.infinity,
            height: 80,
            borderRadius: 12,
          ),
        );
      },
    );
  }

  /// Card list loading skeleton
  static Widget cardListLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Featured Banner
          shimmerContainer(
            width: double.infinity,
            height: screenHeight * 0.15,
            borderRadius: 12,
          ),
          SizedBox(height: screenHeight * 0.03),

          // Section Title
          shimmerContainer(width: 100, height: 18),
          SizedBox(height: screenHeight * 0.02),

          // Cards
          ...List.generate(3, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: shimmerContainer(
                width: double.infinity,
                height: 90,
                borderRadius: 12,
              ),
            );
          }),
          SizedBox(height: screenHeight * 0.03),

          // Featured Section
          shimmerContainer(
            width: double.infinity,
            height: screenHeight * 0.3,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }

  /// Profile screen loading skeleton
  static Widget profileScreenLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.03),
          
          // Header
          shimmerContainer(width: 150, height: 30),
          SizedBox(height: screenHeight * 0.03),

          // User Info Card
          shimmerContainer(
            width: double.infinity,
            height: 100,
            borderRadius: 12,
          ),
          SizedBox(height: screenHeight * 0.03),

          // Stats Cards
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shimmerContainer(
                width: screenWidth * 0.45,
                height: 80,
                borderRadius: 12,
              ),
              shimmerContainer(
                width: screenWidth * 0.45,
                height: 80,
                borderRadius: 12,
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.02),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              shimmerContainer(
                width: screenWidth * 0.45,
                height: 80,
                borderRadius: 12,
              ),
              shimmerContainer(
                width: screenWidth * 0.45,
                height: 80,
                borderRadius: 12,
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.03),

          // Invite Section
          shimmerContainer(
            width: double.infinity,
            height: 120,
            borderRadius: 12,
          ),
          SizedBox(height: screenHeight * 0.03),

          // Settings Section
          shimmerContainer(
            width: double.infinity,
            height: 150,
            borderRadius: 12,
          ),
        ],
      ),
    );
  }

  /// Wallet screen loading skeleton
  static Widget walletScreenLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: screenHeight * 0.03),
          
          // Header
          shimmerContainer(width: 120, height: 30),
          SizedBox(height: screenHeight * 0.02),

          // Profile & Wallet Card
          Row(
            children: [
              shimmerContainer(width: screenWidth * 0.2, height: screenWidth * 0.2, borderRadius: screenWidth * 0.1),
              SizedBox(width: screenWidth * 0.03),
              Expanded(
                child: shimmerContainer(
                  width: double.infinity,
                  height: 100,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.03),

          // Badges Section
          shimmerContainer(width: 120, height: 18),
          SizedBox(height: screenHeight * 0.01),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: screenWidth * 0.02,
              runSpacing: screenWidth * 0.02,
              children: List.generate(4, (index) {
                return shimmerContainer(
                  width: screenWidth * 0.15,
                  height: screenWidth * 0.15,
                  borderRadius: screenWidth * 0.075,
                );
              }),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),

          // Rewards Section
          shimmerContainer(width: 100, height: 18),
          SizedBox(height: screenHeight * 0.01),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: screenWidth * 0.02,
              mainAxisSpacing: screenWidth * 0.02,
              childAspectRatio: 1.0,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              return shimmerContainer(
                width: double.infinity,
                height: 80,
                borderRadius: 12,
              );
            },
          ),
          SizedBox(height: screenHeight * 0.03),

          // Top Winners Section
          shimmerContainer(width: 150, height: 18),
          SizedBox(height: screenHeight * 0.01),
          shimmerContainer(width: 200, height: 14),
        ],
      ),
    );
  }

  /// Leaderboard screen loading skeleton
  static Widget leaderboardScreenLoading(double screenWidth, double screenHeight) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top 3
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                shimmerContainer(width: 90, height: 140, borderRadius: 12),
                const SizedBox(width: 12),
                shimmerContainer(width: 90, height: 160, borderRadius: 12),
                const SizedBox(width: 12),
                shimmerContainer(width: 90, height: 120, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Rest of the list
          ...List.generate(5, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: shimmerContainer(
                width: double.infinity,
                height: 60,
                borderRadius: 12,
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Grid loading skeleton
  static Widget gridLoading({
    required double screenWidth,
    required double screenHeight,
    int crossAxisCount = 2,
    int itemCount = 4,
  }) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: screenWidth * 0.02,
        mainAxisSpacing: screenWidth * 0.02,
        childAspectRatio: 1.0,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return shimmerContainer(
          width: double.infinity,
          height: 100,
          borderRadius: 12,
        );
      },
    );
  }

  /// Simple list item loading
  static Widget listItemLoading({
    required double screenWidth,
    double height = 60,
    double borderRadius = 12,
  }) {
    return shimmerContainer(
      width: double.infinity,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Custom loading with specific dimensions
  static Widget customLoading({
    required double width,
    required double height,
    double borderRadius = 12,
    EdgeInsets? margin,
  }) {
    Widget container = shimmerContainer(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );

    if (margin != null) {
      return Padding(padding: margin, child: container);
    }

    return container;
  }
}
