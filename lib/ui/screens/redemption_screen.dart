// lib/screens/redemption_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:giftardo/providers/wallet_provider.dart';
import 'zigzag_clipper.dart';

class RedemptionScreen extends StatefulWidget {
  const RedemptionScreen({Key? key}) : super(key: key);

  @override
  State<RedemptionScreen> createState() => _RedemptionScreenState();
}

class _RedemptionScreenState extends State<RedemptionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _coins = 1000.0;
  bool _isCustom = false;
  TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _customController.dispose();
    super.dispose();
  }

  void _selectAmount(double amount) {
    setState(() {
      _coins = amount;
      _isCustom = false;
      _customController.text = '';
    });
    _controller.forward();
  }

  void _handleCustomInput(String value) {
    if (value.isEmpty) {
      setState(() {
        _isCustom = false;
        _coins = 1000;
      });
      return;
    }

    try {
      final num = double.parse(value);
      setState(() {
        _coins = num;
        _isCustom = true;
      });
      _controller.forward();
    } catch (_) {
      setState(() {
        _isCustom = false;
        _coins = 1000;
      });
    }
  }

  void _requestRedemption() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Redemption request for ₹${(_coins / 10).toStringAsFixed(2)} sent!"),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final walletProvider = Provider.of<WalletProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Redeem Coins",
          style: TextStyle(
            fontSize: screenWidth * 0.055,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: screenHeight * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Available coins card
            Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.red],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    "Available Balance",
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stars, color: Colors.white, size: 28),
                      SizedBox(width: screenWidth * 0.02),
                      Text(
                        "${walletProvider.walletAmount}",
                        style: TextStyle(
                          fontSize: screenWidth * 0.08,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    "10 Coins = ₹1.00",
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.04),

            // Quick selection
            Text(
              "Quick Selection",
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAmountOption(1000, screenWidth, screenHeight, walletProvider),
                _buildAmountOption(2000, screenWidth, screenHeight, walletProvider),
                _buildAmountOption(5000, screenWidth, screenHeight, walletProvider),
              ],
            ),
            SizedBox(height: screenHeight * 0.03),

            // Custom input
            Text(
              "Custom Amount",
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            SizedBox(height: screenHeight * 0.015),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.015,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.orange.shade200),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: "Enter coins (min 1000)",
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  suffixIcon: _isCustom
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.orange),
                          onPressed: () {
                            setState(() {
                              _isCustom = false;
                              _coins = 1000;
                              _customController.text = '';
                            });
                          },
                        )
                      : null,
                ),
                onChanged: _handleCustomInput,
              ),
            ),
            SizedBox(height: screenHeight * 0.04),

            // Calculation card
            ScaleTransition(
              scale: _controller,
              child: FadeTransition(
                opacity: _controller,
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.04),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "You Will Get",
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.green.shade700,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Text(
                        "₹${(_coins / 10).toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: screenWidth * 0.09,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.01),
                      Text(
                        "(${_coins.toInt()} coins at 10:1 ratio)",
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: Colors.green.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.05),

            // Request button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_coins >= 1000 && _coins <= walletProvider.walletAmount) {
                    _requestRedemption();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _coins < 1000 
                              ? "Minimum redemption is 1000 coins" 
                              : "Insufficient coins balance",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.02),
                ),
                child: Text(
                  "Request Redemption",
                  style: TextStyle(
                    fontSize: screenWidth * 0.05,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: screenHeight * 0.03),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountOption(
    double amount,
    double screenWidth,
    double screenHeight,
    WalletProvider walletProvider,
  ) {
    final isSelected = _coins == amount && !_isCustom;
    final isDisabled = amount > walletProvider.walletAmount;

    return GestureDetector(
      onTap: isDisabled
          ? null
          : () => _selectAmount(amount),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: screenWidth * 0.25,
        height: screenHeight * 0.12,
        decoration: BoxDecoration(
          color: isDisabled
              ? Colors.grey.shade200
              : isSelected
                  ? Colors.green
                  : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDisabled
                ? Colors.grey
                : isSelected
                    ? Colors.green
                    : Colors.orange,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.green.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "${amount.toInt()}",
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.bold,
                color: isDisabled
                    ? Colors.grey
                    : isSelected
                        ? Colors.white
                        : Colors.orange,
              ),
            ),
            SizedBox(height: screenHeight * 0.005),
            Text(
              "coins",
              style: TextStyle(
                fontSize: screenWidth * 0.03,
                color: isDisabled
                    ? Colors.grey
                    : isSelected
                        ? Colors.white70
                        : Colors.orange,
              ),
            ),
            if (isDisabled)
              Padding(
                padding: EdgeInsets.only(top: screenHeight * 0.005),
                child: Text(
                  "Insufficient",
                  style: TextStyle(
                    fontSize: screenWidth * 0.025,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}