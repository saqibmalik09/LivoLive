import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:sk_live/core/widgets/app_network_image.dart';

abstract final class PartyRefLayout {
  static const double designWidth = 750;

  static double scaleOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width / designWidth;

  static const double side = 24;

  static const double cardToChips = 24;
  static const double chipsToFeed = 36;
}

class PartyRefMyRoomCard extends StatelessWidget {
  const PartyRefMyRoomCard({
    super.key,
    required this.name,
    required this.roomTitle,
    required this.avatarUrl,
    required this.tagLabel,
    required this.onTap,
    this.countryCode,
  });

  final String name;
  final String roomTitle;
  final String? avatarUrl;
  final String tagLabel;
  final VoidCallback onTap;

  final String? countryCode;

  static String? flagFor(String? code) {
    final c = code?.trim().toUpperCase() ?? '';
    if (c.length != 2) return null;
    try {
      return Country.parse(c).flagEmoji;
    } catch (_) {
      return null;
    }
  }

  static const String banner = 'assets/design/party/my_room_banner.webp';
  static const double width = 750;
  static const double height = 205;
  static const Color tagGold = Color(0xFFE5C057);
  static const Color tagText = Color(0xFFF6D57A);
  static const Color nameColor = Colors.white;
  static const Color roomColor = Color(0xD9FFFFFF);
  static const Color chevron = Color(0xFFF6D57A);
  static const Color photoFallback = Color(0xFF1E6B5E);

  @override
  Widget build(BuildContext context) {
    final s = PartyRefLayout.scaleOf(context);
    final url = avatarUrl ?? '';
    final flag = flagFor(countryCode);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width * s,
        height: height * s,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(banner, fit: BoxFit.fill, gaplessPlayback: true),
            Padding(
              padding: EdgeInsetsDirectional.only(start: 61 * s, end: 58 * s),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16 * s),
                    child: SizedBox.square(
                      dimension: 132 * s,
                      child: url.isNotEmpty
                          ? AppNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              transformWidth: 264,
                              transformHeight: 264,
                            )
                          : ColoredBox(
                              color: photoFallback,
                              child: Icon(
                                Iconsax.user,
                                color: Colors.white70,
                                size: 60 * s,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 18 * s),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 34 * s,
                          child: Row(
                            children: [
                              if (flag != null) ...[
                                Text(
                                  flag,
                                  style: TextStyle(fontSize: 32 * s, height: 1),
                                ),
                                SizedBox(width: 12 * s),
                              ],
                              Container(
                                height: 34 * s,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10 * s,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(17 * s),
                                  border: Border.all(
                                    color: tagGold,
                                    width: 2 * s,
                                  ),
                                ),
                                child: Text(
                                  tagLabel,
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: tagText,
                                    fontSize: 20 * s,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              SizedBox(width: 14 * s),
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: nameColor,
                                    fontSize: 30 * s,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12 * s),
                        Text(
                          roomTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: roomColor,
                            fontSize: 24 * s,
                            fontWeight: FontWeight.w400,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12 * s),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: chevron,
                    size: 44 * s,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PartyRefFilterChips<T> extends StatelessWidget {
  const PartyRefFilterChips({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelect;

  static const double chipHeight = 51;
  static const double gap = 25;
  static const double textSize = 24;
  static const Color goldTop = Color(0xFFF1FCD8);
  static const Color goldMid = Color(0xFFF8DA8D);
  static const Color goldBottom = Color(0xFFF5C56C);
  static const Color goldBorder = Color(0xFFE5C057);
  static const Color beige = Color(0xFFF1ECE8);
  static const Color textSelected = Color(0xFF5A3A0A);
  static const Color textUnselected = Color(0xFF7E6951);

  @override
  Widget build(BuildContext context) {
    final s = PartyRefLayout.scaleOf(context);
    final h = chipHeight * s;
    return SizedBox(
      height: h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: PartyRefLayout.side * s),
        itemCount: values.length,
        separatorBuilder: (_, _) => SizedBox(width: gap * s),
        itemBuilder: (context, i) {
          final v = values[i];
          final on = v == selected;
          return GestureDetector(
            onTap: () => onSelect(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: h,
              padding: EdgeInsets.symmetric(horizontal: 26 * s),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                color: on ? null : beige,
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [goldTop, goldMid, goldBottom],
                      )
                    : null,
                border: Border.all(
                  color: on ? goldBorder : Colors.transparent,
                  width: 2 * s,
                ),
              ),
              child: Text(
                labelOf(v),
                maxLines: 1,
                style: TextStyle(
                  color: on ? textSelected : textUnselected,
                  fontSize: textSize * s,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
