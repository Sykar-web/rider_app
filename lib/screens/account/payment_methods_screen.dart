import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../app/board_widgets.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key, this.selecting = false});
  final bool selecting;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Payment Method'), centerTitle: true),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'How would you like to pay?',
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a payment option for your journey.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        BoardCard(
          child: Column(
            children: [
              _method(
                context,
                Icons.payments_outlined,
                'Cash',
                'Pay your driver after the trip',
                true,
              ),
              const Divider(height: 28),
              _method(
                context,
                Icons.phone_android_rounded,
                'Mobile Money',
                'MTN and Airtel · Not enabled yet',
                false,
              ),
              const Divider(height: 28),
              _method(
                context,
                Icons.credit_card_rounded,
                'Card',
                'Not enabled yet',
                false,
              ),
              const Divider(height: 28),
              _method(
                context,
                Icons.account_balance_wallet_outlined,
                'Wallet Balance',
                'Payments not enabled yet',
                false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const BoardCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.blueDeep),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Cash is the current payment method. Confirm the fare with your driver before travelling. FastRide will never ask for your Mobile Money PIN.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'cash'),
          child: Text(selecting ? 'Use Cash' : 'Done'),
        ),
      ],
    ),
  );

  Widget _method(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool available,
  ) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: available
        ? () {
            if (selecting) Navigator.pop(context, 'cash');
          }
        : () => boardInfo(
            context,
            '$title is not enabled',
            'You can book with cash. This payment option will become available after FastRide connects a payment provider.',
          ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: available ? AppColors.blueTint : AppColors.field,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: available ? AppColors.blueDeep : AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            available ? Icons.radio_button_checked : Icons.lock_outline,
            color: available ? AppColors.blueDeep : AppColors.textMuted,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
