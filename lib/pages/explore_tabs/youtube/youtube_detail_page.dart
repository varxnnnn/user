import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:giftardo/core/services/reward_allocation_service.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/youtube_provider.dart';

class YoutubeDetailPage extends StatefulWidget {
  final String activityId;
  final String title;
  final String description;
  final String sponsorName;
  final String sponsorLogo;
  final String rewardType;
  final dynamic rewardedItem;
  final String youtubeLink;
  final int timerDuration;
  final String userId;
  final String? rewardTitle;
  final String? rewardDescription;

  const YoutubeDetailPage({
    Key? key,
    required this.activityId,
    required this.title,
    required this.description,
    required this.sponsorName,
    required this.sponsorLogo,
    required this.rewardType,
    required this.rewardedItem,
    required this.youtubeLink,
    required this.timerDuration,
    required this.userId,
    this.rewardTitle,
    this.rewardDescription,
  }) : super(key: key);

  @override
  State<YoutubeDetailPage> createState() => _YoutubeDetailPageState();
}

class _YoutubeDetailPageState extends State<YoutubeDetailPage> {
  late YoutubePlayerController _controller;
  bool _isPlaying = false;
  bool _timerCompleted = false;
  bool _isSubmitting = false;
  int _remainingTime = 0;
  Timer? _timer;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayer.convertUrlToId(widget.youtubeLink);
    _remainingTime = widget.timerDuration;
    
    _controller = YoutubePlayerController(
      initialVideoId: _videoId ?? '',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
      ),
    );

    _controller.addListener(_videoListener);
  }

  void _videoListener() {
    if (_controller.value.isPlaying) {
      if (!_isPlaying) {
        setState(() {
          _isPlaying = true;
        });
        _startTimer();
      }
    } else {
      if (_isPlaying) {
        setState(() {
          _isPlaying = false;
        });
        _pauseTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          _timerCompleted = true;
          _controller.pause();
          timer.cancel();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
  }

  Future<void> _claimReward() async {
    if (_isSubmitting) return;
    
    setState(() {
      _isSubmitting = true;
    });

    try {
      // Get activity details
      final activityDoc = await FirebaseFirestore.instance
          .collection('sponsor_activities')
          .doc(widget.activityId)
          .get();

      if (!activityDoc.exists) {
        throw Exception('Activity not found');
      }

      final activityData = activityDoc.data()!;
      final rewardAllocation = activityData['reward_allocation'] as Map<String, dynamic>?;
      final rewardDistributionType = activityData['reward_distribution_type'] as String? ?? 'first_come_first_serve';

      if (rewardAllocation == null) {
        throw Exception('No reward allocation found for this activity');
      }

      final rewardId = rewardAllocation['reward_id'] as String;
      final sponsorId = activityData['sponsor_id'] as String;

      Map<String, dynamic>? rewardResult;
      String? rewardCode = '';
      String actualRewardType = widget.rewardType;
      String? actualRewardTitle = widget.rewardTitle;
      String? actualRewardDescription = widget.rewardDescription;
      dynamic actualRewardedItem = widget.rewardedItem;

      // For lucky draw activities, show a different message
      if (rewardDistributionType == 'lucky_draw') {
        // For lucky draw, we don't immediately allocate rewards
        // Just mark the user as participated
        rewardCode = 'LUCKY_DRAW_PENDING';
        actualRewardType = 'lucky_draw';
        actualRewardTitle = 'Lucky Draw Participation';
        actualRewardDescription = 'Results will be announced soon. Winners will be notified.';
        actualRewardedItem = 0;
      } else {
        // For first come first serve, allocate rewards immediately
        // Allocate reward to user
        final rewardService = RewardAllocationService();
        rewardResult = await rewardService.allocateRewardToUser(
          activityId: widget.activityId,
          userId: widget.userId,
          sponsorId: sponsorId,
          rewardId: rewardId,
        );

        if (rewardResult != null) {
          rewardCode = rewardResult['reward_code'];
          actualRewardType = rewardResult['reward_type'] as String? ?? widget.rewardType;
          actualRewardTitle = rewardResult['reward_title'] as String? ?? widget.rewardTitle;
          actualRewardDescription = rewardResult['reward_description'] as String? ?? widget.rewardDescription;
          actualRewardedItem = rewardResult['reward_value'] as int? ?? widget.rewardedItem;
        }
      }

      // Record completion
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('youtube_attempts')
          .doc(widget.activityId)
          .set({
        'activityId': widget.activityId,
        'activityTitle': widget.title,
        'description': widget.description,
        'sponsorName': widget.sponsorName,
        'rewardType': actualRewardType,
        'rewardedItem': actualRewardedItem,
        'rewardCode': rewardCode,
        'rewardTitle': actualRewardTitle,
        'rewardDescription': actualRewardDescription,
        'timestamp': FieldValue.serverTimestamp(),
        'rewarded': true,
        'userId': widget.userId,
        'completedAt': FieldValue.serverTimestamp(),
      });

      // Add to activity_participants collection for easy admin access
      await FirebaseFirestore.instance
          .collection('activity_participants')
          .doc('${widget.activityId}_${widget.userId}')
          .set({
        'activityId': widget.activityId,
        'userId': widget.userId,
        'activityType': 'youtube',
        'completedAt': FieldValue.serverTimestamp(),
        'isRewarded': rewardDistributionType != 'lucky_draw',
        if (rewardDistributionType != 'lucky_draw' && rewardCode != null) 'rewardCode': rewardCode,
        if (rewardDistributionType == 'lucky_draw') 'rewardStatus': 'pending',
      });

      // Mark as completed in the provider
      if (mounted) {
        Provider.of<YoutubeProvider>(context, listen: false).markCompleted(widget.activityId);
        
        if (rewardDistributionType == 'lucky_draw') {
          _showLuckyDrawDialog();
        } else if (rewardResult != null) {
          _showRewardDialog(rewardResult);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Failed to allocate reward")),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error claiming reward: $e")),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showRewardDialog(Map<String, dynamic> rewardResult) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Reward Claimed!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("You have successfully completed the Advertise Video activity."),
              const SizedBox(height: 10),
              Text("Reward: ${widget.rewardTitle ?? 'Reward'}"),
              if (rewardResult['reward_code'] != null)
                Text("Code: ${rewardResult['reward_code']}"),
              const SizedBox(height: 10),
              const Text("The reward has been added to your account."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to the previous screen
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  void _showLuckyDrawDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Lucky Draw Participation"),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Thank you for participating in the lucky draw!"),
              SizedBox(height: 8),
              Text(
                "Results will be announced soon.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text("The sponsor will review all participants and select winners. You will be notified if you win."),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to the previous screen
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // YouTube Player
            YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              progressIndicatorColor: Colors.orange,
              onReady: () {
                // Player is ready
              },
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timer display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _timerCompleted ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Timer:",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_remainingTime ~/ 60}:${(_remainingTime % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Activity title and sponsor
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.orange,
                        backgroundImage: widget.sponsorLogo.isNotEmpty
                            ? NetworkImage(widget.sponsorLogo)
                            : null,
                        child: widget.sponsorLogo.isEmpty
                            ? Text(
                                widget.sponsorName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.sponsorName,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  const Text(
                    "Description",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    widget.description,
                    style: const TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Reward information
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.card_giftcard, color: Colors.orange),
                            SizedBox(width: 12),
                            Text(
                              'Reward',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.rewardTitle ?? 'Reward',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.rewardDescription ?? '',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Claim reward button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _timerCompleted && !_isSubmitting
                          ? _claimReward
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _timerCompleted ? Colors.green : Colors.grey,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _timerCompleted ? "Claim Reward" : "Watch Video to Claim Reward",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Instructions
                  const Text(
                    "Instructions:",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "1. Play the YouTube video above\n"
                    "2. Watch for the full duration (${widget.timerDuration} seconds)\n"
                    "3. The timer will count down while the video is playing\n"
                    "4. Once the timer completes, you can claim your reward",
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}