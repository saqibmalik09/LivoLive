import 'package:flutter/material.dart';
import 'package:sk_live/core/widgets/profile_titles_medals_row.dart';

class ProfileBadgesRow extends StatelessWidget {
  const ProfileBadgesRow({
    super.key,
    required this.userId,
    this.padHorizontal = true,
  });

  final String userId;
  final bool padHorizontal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padHorizontal ? 16 : 0),
      child: ProfileTitlesMedalsRow(userId: userId),
    );
  }
}
