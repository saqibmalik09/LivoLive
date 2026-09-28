import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/l10n/l10n_ext.dart';
import 'package:sk_live/features/wallet/providers/withdraw_provider.dart';
import 'package:sk_live/core/util/silent_connection_error.dart';

class UserPaymentMethodsScreen extends ConsumerStatefulWidget {
  const UserPaymentMethodsScreen({super.key, this.selectMode = false});

  final bool selectMode;

  @override
  ConsumerState<UserPaymentMethodsScreen> createState() =>
      _UserPaymentMethodsScreenState();
}

class _UserPaymentMethodsScreenState
    extends ConsumerState<UserPaymentMethodsScreen> {
  static const _purple = Color(0xFF7E69FF);

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedOption;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final options =
        ref.read(systemPaymentMethodOptionsProvider).valueOrNull ?? [];
    final method =
        _selectedOption ?? (options.isNotEmpty ? options.first : null);
    if (method == null ||
        _nameController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _saving = true);
    try {
      final pm = await ref
          .read(withdrawActionsProvider)
          .addPaymentMethod(
            method: method,
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
          );
      _nameController.clear();
      _addressController.clear();
      if (!mounted) return;
      if (widget.selectMode && pm != null) {
        Navigator.pop(context, pm);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment method added')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(userPaymentMethodsProvider);
    final optionsAsync = ref.watch(systemPaymentMethodOptionsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.l10n.wallet_selectPaymentMethod,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          methodsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _purple),
              ),
            ),
            error: (e, _) => asyncErrorWidget(e),
            data: (methods) {
              if (methods.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No payment methods yet. Add one below.',
                    style: TextStyle(color: Colors.black45),
                  ),
                );
              }
              return Column(
                children: methods.map((m) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: const Color(0xFFF7F7F9),
                      borderRadius: BorderRadius.circular(14),
                      child: ListTile(
                        onTap: widget.selectMode
                            ? () => Navigator.pop(context, m)
                            : null,
                        title: Text(
                          m.method,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('${m.name}\n${m.address}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () async {
                            await ref
                                .read(withdrawActionsProvider)
                                .deletePaymentMethod(m.id);
                          },
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Add payment method',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 12),
          optionsAsync.when(
            loading: () => const LinearProgressIndicator(color: _purple),
            error: (_, _) => const SizedBox.shrink(),
            data: (options) {
              _selectedOption ??= options.isNotEmpty ? options.first : null;
              return DropdownButtonFormField<String>(
                initialValue: _selectedOption,
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedOption = v),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFF7F7F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: _inputDeco('Account name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressController,
            decoration: _inputDeco('Account number / address'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saving ? null : _add,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7F7F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }
}
