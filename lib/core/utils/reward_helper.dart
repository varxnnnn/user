// Helper utility for extracting reward data from Firestore documents
class RewardHelper {
  /// Extracts reward data from a reward document
  /// Handles both old format (direct fields) and new format (metadata structure)
  static Map<String, dynamic> extractRewardData(Map<String, dynamic> rewardDoc) {
    final rewardType = (rewardDoc['type'] ?? 'points').toString().toLowerCase();
    final metadata = rewardDoc['metadata'] as Map<String, dynamic>? ?? {};
    
    Map<String, dynamic> rewardData = {};
    
    if (rewardType == 'voucher') {
      // Try metadata first, then fallback to direct field
      final voucher = metadata['voucher'] as Map<String, dynamic>? ?? 
                     rewardDoc['voucher'] as Map<String, dynamic>? ?? {};
      rewardData = voucher;
    } else if (rewardType == 'coins') {
      // Try metadata first, then fallback to direct field
      final coins = metadata['coins'] as Map<String, dynamic>? ?? 
                   rewardDoc['coins'] as Map<String, dynamic>? ?? {};
      rewardData = coins;
    } else if (rewardType == 'product' || rewardType == 'products') {
      // Try metadata first, then fallback to direct field
      final product = metadata['product'] as Map<String, dynamic>? ?? 
                     rewardDoc['product'] as Map<String, dynamic>? ?? {};
      rewardData = product;
    } else {
      // For points or unknown types, use metadata or empty
      rewardData = metadata;
    }
    
    return rewardData;
  }
  
  /// Gets the reward value (amount/points) from reward data
  static int getRewardValue(Map<String, dynamic> rewardDoc, Map<String, dynamic> rewardData, String rewardType) {
    if (rewardType == 'coins') {
      return rewardData['amount'] as int? ?? 
             rewardDoc['value'] as int? ?? 
             0;
    } else if (rewardType == 'voucher') {
      return rewardData['value'] as int? ?? 
             rewardData['amount'] as int? ?? 
             rewardDoc['value'] as int? ?? 
             0;
    } else if (rewardType == 'points') {
      return rewardDoc['value'] as int? ?? 
             rewardData['amount'] as int? ?? 
             0;
    }
    return 0;
  }
  
  /// Formats reward display text based on type
  static String formatRewardDisplay(String rewardType, Map<String, dynamic> rewardData, int fallbackValue) {
    switch (rewardType.toLowerCase()) {
      case 'coins':
        final amount = rewardData['amount'] as int? ?? fallbackValue;
        return '$amount Coins';
      case 'voucher':
        final value = rewardData['value'] as int? ?? fallbackValue;
        final currency = rewardData['currency'] as String? ?? 'INR';
        return '₹$value $currency Voucher';
      case 'product':
      case 'products':
        return rewardData['name'] as String? ?? 'Product Reward';
      case 'points':
        return '$fallbackValue Points';
      default:
        return '$fallbackValue Points';
    }
  }
}

