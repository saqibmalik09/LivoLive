import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

IconData vipFeatureIcon(String key) {
  switch (key) {
    case 'has_vip_title':
      return Iconsax.user_tick;
    case 'has_exclusive_frame':
      return Iconsax.frame;
    case 'has_chat_bubble':
      return Iconsax.message_text;
    case 'has_entrance_show':
      return Iconsax.login;
    case 'has_special_gift':
      return Iconsax.presention_chart;
    case 'has_distinguished_card':
      return Iconsax.card;
    case 'has_room_priority':
      return Iconsax.house;
    case 'has_privilege_gift':
      return Iconsax.gift;
    case 'has_mic_emojis':
      return Iconsax.emoji_happy;
    case 'has_free_family':
      return Iconsax.people;
    case 'has_discount':
      return Iconsax.percentage_square;
    case 'has_anti_blocking':
      return Iconsax.shield_search;
    case 'has_kicking_defence':
      return Iconsax.security_user;
    case 'has_refuse_strangers':
      return Iconsax.message_remove;
    case 'has_invisibility':
      return Iconsax.ghost;
    case 'has_rare_vehicle':
      return Iconsax.car;
    default:
      return Iconsax.star;
  }
}
