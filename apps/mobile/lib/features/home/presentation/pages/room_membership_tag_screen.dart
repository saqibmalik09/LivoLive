import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sk_live/core/providers/room_info_provider.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class RoomMembershipTagScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> room;

  const RoomMembershipTagScreen({super.key, required this.room});

  @override
  ConsumerState<RoomMembershipTagScreen> createState() =>
      _RoomMembershipTagScreenState();
}

class _RoomMembershipTagScreenState
    extends ConsumerState<RoomMembershipTagScreen> {
  late TextEditingController _nameController;
  late String _selectedColor;
  bool _isSaving = false;

  final List<String> _colors = [
    '#FF4081',
    '#7C4DFF',
    '#00B0FF',
    '#00E676',
    '#FFD600',
    '#FF6E40',
    '#455A64',
    '#E91E63',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.room['membership_tag_name'] ?? 'Member Group',
    );
    _selectedColor = widget.room['membership_tag_color'] ?? '#FF4081';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a tag name')));
      return;
    }

    setState(() => _isSaving = true);
    final success = await ref
        .read(roomInfoProvider(widget.room['id'].toString()).notifier)
        .updateRoom(widget.room['id'], {
          'membership_tag_name': name,
          'membership_tag_color': _selectedColor,
        });
    setState(() => _isSaving = false);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Membership tag',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Colors.pinkAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            Row(
              children: [
                const Text(
                  'Current tag style:',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(width: 10),
                _buildTagPreview(),
              ],
            ),

            const SizedBox(height: 25),

            Row(
              children: [
                const Text(
                  'Current tag name:',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    maxLength: 15,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      counterText: "",
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const Icon(
                  Iconsax.edit_2_copy,
                  size: 18,
                  color: Colors.blueAccent,
                ),
              ],
            ),

            const SizedBox(height: 25),

            const Text(
              'Remaining modifiable times: 1',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 30),

            const Text(
              'Choose tag color:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _parseColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tag name modification rules:',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRule(
                    '1. The tag name should be related to the theme of the room itself, members, family, etc.',
                  ),
                  _buildRule(
                    '2. The tag name can only contain 15 characters in length',
                  ),
                  _buildRule(
                    '3. The name should not contain words that violate community rules, such as pornography and violence',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagPreview() {
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 2, right: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _parseColor(_selectedColor),
            _parseColor(_selectedColor).withOpacity(0.8),
            _parseColor(_selectedColor).withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.orangeAccent, Colors.redAccent],
              ),
            ),
            child: const Text(
              '30',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _nameController.text.isEmpty
                ? 'Member Group'
                : _nameController.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRule(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}
