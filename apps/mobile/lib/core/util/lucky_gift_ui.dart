import 'package:flutter/material.dart';

void showLuckyGiftBonusFeedback(
  BuildContext context, {
  required int bonusCoins,
  required int giftValue,
  String? receiverName,
}) {
  if (!context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF2A1035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.celebration, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text(
            'Lucky Bonus!',
            style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Text(
        receiverName != null
            ? 'You won $bonusCoins coins!\n(Lucky bonus for gifting $receiverName — higher than the $giftValue coin gift.)'
            : 'You won $bonusCoins coins!\n(Bonus is higher than the $giftValue coin gift.)',
        style: const TextStyle(color: Colors.white70, height: 1.4),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK', style: TextStyle(color: Colors.amber)),
        ),
      ],
    ),
  );
}

void showLuckyGiftSnackBar(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.amber.shade800,
      duration: const Duration(seconds: 4),
    ),
  );
}
