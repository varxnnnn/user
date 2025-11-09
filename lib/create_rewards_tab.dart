import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class CreateRewardsTab extends StatefulWidget {
  const CreateRewardsTab({super.key});

  @override
  _CreateRewardsTabState createState() => _CreateRewardsTabState();
}

class _CreateRewardsTabState extends State<CreateRewardsTab> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController totalQuantityController = TextEditingController();
  final TextEditingController customTypeController = TextEditingController();
  
  // Metadata controllers
  final TextEditingController coinsAmountController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController productBrandController = TextEditingController();
  final TextEditingController productModelController = TextEditingController();
  final TextEditingController productPriceController = TextEditingController();
  final TextEditingController productCategoryController = TextEditingController();
  final TextEditingController productTypeController = TextEditingController();
  final TextEditingController productDescriptionController = TextEditingController();

  bool loading = false;
  String? sponsorId;

  String selectedType = "coins";
  final List<String> rewardTypes = ["coins", "product"];

  @override
  void initState() {
    super.initState();
    loadSponsorId();
  }

  Future<void> loadSponsorId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      sponsorId = prefs.getString('sponsorId');
    });
  }

  String _generateRandomCode(String type) {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final randomSuffix = random.nextInt(9999).toString().padLeft(4, '0');

    switch (type) {
      case "coins":
        return "COIN-${timestamp}${randomSuffix}";
      case "product":
        final brandPrefix = productBrandController.text.isNotEmpty
            ? productBrandController.text.substring(0, min(3, productBrandController.text.length)).toUpperCase()
            : "PRD";
        final namePrefix = productNameController.text.isNotEmpty
            ? productNameController.text.substring(0, min(3, productNameController.text.length)).toUpperCase()
            : "ITEM";
        return "${brandPrefix}${namePrefix}-${timestamp}${randomSuffix}";
      default:
        return "RWD-${timestamp}${randomSuffix}";
    }
  }

  Map<String, dynamic> _buildMetadata() {
    switch (selectedType) {
      case "coins":
        return {
          "coins": {
            "amount": int.tryParse(coinsAmountController.text) ?? 0
          }
        };
      case "product":
        return {
          "product": {
            "name": productNameController.text,
            "brand": productBrandController.text,
            "model": productModelController.text,
            "description": productDescriptionController.text,
            "price": double.tryParse(productPriceController.text) ?? 0.0,
            "category": productCategoryController.text.isNotEmpty 
                ? productCategoryController.text 
                : "general",
            "type": productTypeController.text.isNotEmpty 
                ? productTypeController.text 
                : "physical_product"
          }
        };
      default:
        return {};
    }
  }

  int _getItemValue() {
    switch (selectedType) {
      case "coins":
        return int.tryParse(coinsAmountController.text) ?? 0;
      case "product":
        return 1; // For products, value represents quantity/unit
      default:
        return 0;
    }
  }

  Map<String, dynamic> _buildItemMetadata() {
    switch (selectedType) {
      case "coins":
        return {
          "coins": {
            "amount": int.tryParse(coinsAmountController.text) ?? 0,
            "currency": "COINS" // Internal currency for coins
          }
        };
      case "product":
        return {
          "product": {
            "name": productNameController.text,
            "brand": productBrandController.text,
            "model": productModelController.text,
            "description": productDescriptionController.text,
            "price": double.tryParse(productPriceController.text) ?? 0.0,
            "category": productCategoryController.text.isNotEmpty 
                ? productCategoryController.text 
                : "general",
            "type": productTypeController.text.isNotEmpty 
                ? productTypeController.text 
                : "physical_product"
          }
        };
      default:
        return {};
    }
  }

  Future<void> _createRewardItems(String rewardId, int totalQuantity) async {
    final batch = FirebaseFirestore.instance.batch();
    final itemsCollection = FirebaseFirestore.instance
        .collection('sponsor_rewards')
        .doc(rewardId)
        .collection('items');

    for (int i = 0; i < totalQuantity; i++) {
      final itemDocRef = itemsCollection.doc();
      final code = _generateRandomCode(selectedType);
      
      final itemData = {
        "code": code,
        "value": _getItemValue(),
        "status": "available",
        "assigned_to": null,
        "activity_id": null,
        "created_at": FieldValue.serverTimestamp(),
        "metadata": _buildItemMetadata(),
      };

      batch.set(itemDocRef, itemData);
    }

    await batch.commit();
  }

  Future<void> createReward() async {
    if (sponsorId == null) {
      _showErrorSnackBar("Sponsor ID not found");
      return;
    }

    if (titleController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        totalQuantityController.text.trim().isEmpty) {
      _showErrorSnackBar("Please fill all required fields");
      return;
    }

    // Validate metadata fields based on type
    bool metadataValid = true;
    String? errorMessage;
    switch (selectedType) {
      case "coins":
        metadataValid = coinsAmountController.text.trim().isNotEmpty;
        errorMessage = "Please enter coins amount";
        break;
      case "product":
        metadataValid = productNameController.text.trim().isNotEmpty && 
                       productBrandController.text.trim().isNotEmpty;
        errorMessage = "Please enter product name and brand";
        break;
    }

    if (!metadataValid) {
      _showErrorSnackBar(errorMessage ?? "Please fill all metadata fields for the selected type");
      return;
    }

    setState(() => loading = true);

    try {
      final totalQuantity = int.tryParse(totalQuantityController.text) ?? 0;
      final rewardDocRef = FirebaseFirestore.instance.collection('sponsor_rewards').doc();
      final rewardId = rewardDocRef.id;

      final rewardData = {
        "sponsor_id": sponsorId,
        "title": titleController.text.trim(),
        "description": descriptionController.text.trim(),
        "type": selectedType,
        "total_quantity": totalQuantity,
        "available_quantity": totalQuantity,
        "created_at": FieldValue.serverTimestamp(),
        "status": "active",
        "metadata": _buildMetadata(),
      };

      // Create the main reward document
      await rewardDocRef.set(rewardData);

      // Add reward reference to sponsor's collection
      await FirebaseFirestore.instance
          .collection('sponsors')
          .doc(sponsorId)
          .collection('rewards')
          .doc(rewardId)
          .set({
        ...rewardData,
        "reward_id": rewardId,
      });

      // Create individual reward items in subcollection
      await _createRewardItems(rewardId, totalQuantity);

      _showSuccessSnackBar("Reward created successfully with $totalQuantity items");
      _clearAllFields();
    } catch (e) {
      _showErrorSnackBar("Error creating reward: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _clearAllFields() {
    titleController.clear();
    descriptionController.clear();
    totalQuantityController.clear();
    coinsAmountController.clear();
    productNameController.clear();
    productBrandController.clear();
    productModelController.clear();
    productPriceController.clear();
    productCategoryController.clear();
    productTypeController.clear();
    productDescriptionController.clear();
    setState(() {
      selectedType = "coins";
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Info Section
          const Text("Basic Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
                labelText: "Title", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(
                labelText: "Description", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: totalQuantityController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: "Total Quantity", border: OutlineInputBorder()),
          ),
          const SizedBox(height: 20),

          // Reward Type Section
          const Text("Reward Type", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          
          DropdownButtonFormField<String>(
            value: selectedType,
            items: rewardTypes
                .map((type) => DropdownMenuItem(
              value: type,
              child: Text(type[0].toUpperCase() + type.substring(1)),
            ))
                .toList(),
            onChanged: (val) {
              setState(() {
                selectedType = val!;
              });
            },
            decoration: const InputDecoration(
                labelText: "Reward Type", border: OutlineInputBorder()),
          ),

          const SizedBox(height: 20),

          // Metadata Section
          const Text("Metadata", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          if (selectedType == "coins") ...[
            TextField(
              controller: coinsAmountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Coins Amount", border: OutlineInputBorder()),
            ),
          ],

          if (selectedType == "product") ...[
            TextField(
              controller: productNameController,
              decoration: const InputDecoration(
                  labelText: "Product Name *", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productBrandController,
              decoration: const InputDecoration(
                  labelText: "Brand *", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productModelController,
              decoration: const InputDecoration(
                  labelText: "Model", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productPriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Price (INR)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productCategoryController,
              decoration: const InputDecoration(
                  labelText: "Category (e.g., Electronics, Clothing, Books)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productTypeController,
              decoration: const InputDecoration(
                  labelText: "Product Type (e.g., physical_product, digital, gift_card)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: productDescriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: "Product Description", border: OutlineInputBorder()),
            ),
          ],

          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: loading ? null : createReward,
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Create Reward"),
            ),
          ),
        ],
      ),
    );
  }
}