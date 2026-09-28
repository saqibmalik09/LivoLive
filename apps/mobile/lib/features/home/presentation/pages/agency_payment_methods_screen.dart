import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sk_live/core/theme/app_colors.dart';

class AgencyPaymentMethodsScreen extends ConsumerStatefulWidget {
  final String agencyId;
  final List<dynamic> currentDetails;
  const AgencyPaymentMethodsScreen({
    super.key,
    required this.agencyId,
    required this.currentDetails,
  });

  @override
  ConsumerState<AgencyPaymentMethodsScreen> createState() =>
      _AgencyPaymentMethodsScreenState();
}

class _AgencyPaymentMethodsScreenState
    extends ConsumerState<AgencyPaymentMethodsScreen> {
  List<String> _availableMethods = [];
  String? _selectedMethod;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _myMethods = [];

  @override
  void initState() {
    super.initState();
    _myMethods = List.from(widget.currentDetails);
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await Supabase.instance.client
          .from('system_settings')
          .select('value')
          .eq('key', 'payment_methods')
          .maybeSingle();

      if (res != null) {
        setState(() {
          _availableMethods = List<String>.from(jsonDecode(res['value']));
          if (_availableMethods.isNotEmpty)
            _selectedMethod = _availableMethods[0];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMethod() async {
    if (_selectedMethod == null ||
        _nameController.text.isEmpty ||
        _addressController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isSaving = true);

    final newMethod = {
      'method': _selectedMethod,
      'name': _nameController.text.trim(),
      'address': _addressController.text.trim(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    final updatedList = [..._myMethods, newMethod];

    try {
      await Supabase.instance.client
          .from('agencies')
          .update({'payment_details': updatedList})
          .eq('id', widget.agencyId);

      setState(() {
        _myMethods = updatedList;
        _nameController.clear();
        _addressController.clear();
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment method added!')));
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving payment method')),
        );
      }
    }
  }

  Future<void> _deleteMethod(String id) async {
    final updatedList = _myMethods.where((m) => m['id'] != id).toList();

    try {
      await Supabase.instance.client
          .from('agencies')
          .update({'payment_details': updatedList})
          .eq('id', widget.agencyId);

      setState(() => _myMethods = updatedList);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error deleting method')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Payment Methods',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Method',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _availableMethods.map((m) {
                        final isSelected = _selectedMethod == m;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedMethod = m),
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.white10,
                              ),
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildTextField(
                    'Account Name',
                    'e.g. John Doe',
                    _nameController,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Wallet Address / Account Number',
                    'Enter details here',
                    _addressController,
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveMethod,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Save Payment Method',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 48),
                  const Text(
                    'My Methods',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_myMethods.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          'No payment methods added yet.',
                          style: TextStyle(color: Colors.white24),
                        ),
                      ),
                    )
                  else
                    ..._myMethods
                        .map(
                          (m) => Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.02),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Iconsax.wallet_2,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m['method'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.tealAccent,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        m['name'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        m['address'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _deleteMethod(m['id']),
                                  icon: const Icon(
                                    Iconsax.trash,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white12),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }
}
