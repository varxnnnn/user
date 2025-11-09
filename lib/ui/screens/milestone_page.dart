import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/milestone_provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'leaderboard_screen.dart';

class MilestonePage extends StatefulWidget {
  const MilestonePage({super.key});

  @override
  State<MilestonePage> createState() => _MilestonePageState();
}

class _MilestonePageState extends State<MilestonePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MilestoneProvider>(context, listen: false).loadMilestones();
      Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Giftardo",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer<WalletProvider>(
                      builder: (context, walletProvider, child) {
                        return Row(
                          children: [
                            const Icon(Icons.monetization_on, color: Colors.orange),
                            const SizedBox(width: 4),
                            Text(
                              "${walletProvider.walletAmount}",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const TabBar(
                  labelColor: Colors.orange,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.orange,
                  tabs: [
                    Tab(text: "My Milestones"),
                    Tab(text: "Leaderboard"),
                  ],
                ),
              ),

              // Tab Content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildMilestonesTab(),
                    const LeaderboardPage(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMilestonesTab() {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        if (milestoneProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            await milestoneProvider.refreshMilestones();
            await Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current Month Milestone
                if (milestoneProvider.currentMilestone != null) ...[
                  _buildCurrentMilestoneCard(milestoneProvider),
                  _buildLevelsList(milestoneProvider),
                ] else
                  _buildNoMilestoneCard(),
                
                const SizedBox(height: 24),
                
                // Previous Milestones
                if (milestoneProvider.previousMilestones.isNotEmpty) ...[
                  const Text(
                    "Previous Milestones",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...milestoneProvider.previousMilestones.map((milestone) {
                    return _buildPreviousMilestoneCard(milestone);
                  }).toList(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentMilestoneCard(MilestoneProvider provider) {
    final title = provider.milestoneTitle;
    final month = provider.monthName;
    final levels = provider.levels;
    final completedLevels = provider.completedLevelsCount;
    final totalTasks = provider.completedTasksCount;
    final totalLevels = levels.length;
    final progressPercentage = totalLevels > 0 ? (completedLevels / totalLevels) * 100 : 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade400, Colors.orange.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        month,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Level $completedLevels/$totalLevels',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              '$totalTasks tasks completed this month',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressPercentage / 100,
                minHeight: 12,
                backgroundColor: Colors.white.withOpacity(0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${progressPercentage.toStringAsFixed(0)}% Complete',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsList(MilestoneProvider provider) {
    final levels = provider.levels;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Milestone Levels',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...levels.asMap().entries.map((entry) {
          final index = entry.key;
          final level = entry.value;
          return _buildLevelCard(level, index, provider);
        }).toList(),
      ],
    );
  }

  Widget _buildLevelCard(Map<String, dynamic> level, int index, MilestoneProvider provider) {
    final levelNumber = level['level_number'] ?? 0;
    final description = level['description'] ?? '';
    final taskCount = level['task_count'] ?? 0;
    final reward = level['reward'] ?? 10;
    final isCompleted = level['completed'] == true;
    final canClaim = level['can_claim'] == true;
    final totalTasks = provider.completedTasksCount;
    final progress = totalTasks >= taskCount ? 1.0 : (totalTasks / taskCount);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted 
                ? Colors.green 
                : (canClaim ? Colors.orange : Colors.grey.shade300),
            width: isCompleted || canClaim ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Level Number Badge
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: isCompleted 
                          ? Colors.green 
                          : (canClaim ? Colors.orange : Colors.grey),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCompleted
                          ? const Icon(Icons.check, color: Colors.white, size: 24)
                          : Text(
                              '$levelNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Level Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          description,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isCompleted ? Colors.green : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.task_alt,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalTasks / $taskCount tasks',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        if (totalTasks >= taskCount && !isCompleted) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Ready to claim!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  // Reward Badge / Claim Button
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '+$reward',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (!isCompleted && canClaim) ...[
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => _claimLevel(level['id'], reward, provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Claim',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Progress bar for incomplete levels
            if (!isCompleted) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      canClaim ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _claimLevel(String levelId, int reward, MilestoneProvider provider) async {
    final success = await provider.claimLevelReward(levelId, reward);
    
    if (success && mounted) {
      // Show success animation/dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Level Completed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You earned $reward coins!',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on, color: Colors.orange, size: 24),
                  const SizedBox(width: 4),
                  Text(
                    '+$reward',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
      
      // Refresh wallet
      await Provider.of<WalletProvider>(context, listen: false).fetchWalletAmount();
      // Refresh milestones
      await provider.refreshMilestones();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Unable to claim reward. Please ensure you have completed enough tasks.',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildNoMilestoneCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.flag_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              "🎯 Coming Soon!",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "New milestone will appear here next month.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviousMilestoneCard(Map<String, dynamic> milestone) {
    final title = milestone['title'] ?? 'Milestone';
    final month = milestone['month'] ?? 'Unknown Month';
    final completedLevels = milestone['completed_levels'] ?? 0;
    final totalLevels = milestone['total_levels'] ?? 0;
    final totalEarned = milestone['total_earned'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: completedLevels == totalLevels ? Colors.green : Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Icon(
            completedLevels == totalLevels ? Icons.check : Icons.flag,
            color: Colors.white,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(month),
            const SizedBox(height: 4),
            Text('Levels: $completedLevels / $totalLevels'),
            if (totalEarned > 0) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.monetization_on, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Earned $totalEarned coins',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: completedLevels == totalLevels ? Colors.green : Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            completedLevels == totalLevels ? 'COMPLETED' : 'IN PROGRESS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
