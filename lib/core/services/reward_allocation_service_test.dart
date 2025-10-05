// Test file for RewardAllocationService
// This is a simple test to verify the service works correctly

import 'package:giftardo/core/services/reward_allocation_service.dart';

class RewardAllocationServiceTest {
  static Future<void> testRewardAllocation() async {
    final service = RewardAllocationService();
    
    // Test data based on the provided structure
    final testData = {
      'activityId': 'test_activity_123',
      'userId': 'test_user_456',
      'sponsorId': 'VfrROcbOudcLkqrgLEnd',
      'rewardId': 'VoFlr9Q09VMaHGXS9d8P',
    };
    
    print('Testing reward allocation...');
    
    try {
      // Test getting activity reward info
      final rewardInfo = await service.getActivityRewardInfo(testData['activityId']!);
      print('Activity reward info: $rewardInfo');
      
      // Test checking if user completed activity
      final hasCompleted = await service.hasUserCompletedActivity(
        activityId: testData['activityId']!,
        userId: testData['userId']!,
      );
      print('User has completed activity: $hasCompleted');
      
      // Test getting user's earned rewards
      final userRewards = await service.getUserEarnedRewards(testData['userId']!);
      print('User earned rewards: ${userRewards.length} rewards');
      
      print('All tests completed successfully!');
    } catch (e) {
      print('Test failed with error: $e');
    }
  }
}

// Usage example:
// RewardAllocationServiceTest.testRewardAllocation();

