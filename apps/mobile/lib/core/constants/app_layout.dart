import 'package:flutter/material.dart';

const double kAppBottomNavBarHeight = 48;

const double kBottomNavTopFadeHeight = 36;

const double kBottomNavIconFloat = 12;

double bottomNavTotalHeight(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom +
    kAppBottomNavBarHeight +
    kBottomNavIconFloat;

const double kHomeTabScrollBottomGap = 8;

const double kHomeTabScrollBottomPadding =
    kAppBottomNavBarHeight + kBottomNavIconFloat + kHomeTabScrollBottomGap;

double homeTabScrollBottomPadding(BuildContext context) =>
    bottomNavTotalHeight(context) + kHomeTabScrollBottomGap;

const double kBottomNavIconSize = 30;
const double kBottomNavActiveIconSize = 34;
const double kBottomNavIconSlotHeight = 44;

const String kBottomNavFocusAsset = 'assets/nav/nav_focus.webp';
const double kBottomNavFocusSize = 52;
