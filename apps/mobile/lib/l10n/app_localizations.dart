import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_id.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_th.dart';
import 'app_localizations_tr.dart';
import 'app_localizations_ur.dart';
import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('hi'),
    Locale('id'),
    Locale('pt'),
    Locale('th'),
    Locale('tr'),
    Locale('ur'),
    Locale('vi'),
  ];

  /// No description provided for @lang_title.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get lang_title;

  /// No description provided for @lang_english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get lang_english;

  /// No description provided for @lang_arabic.
  ///
  /// In en, this message translates to:
  /// **'العربية'**
  String get lang_arabic;

  /// No description provided for @lang_indonesian.
  ///
  /// In en, this message translates to:
  /// **'Bahasa Indonesia'**
  String get lang_indonesian;

  /// No description provided for @lang_turkish.
  ///
  /// In en, this message translates to:
  /// **'Türkçe'**
  String get lang_turkish;

  /// No description provided for @lang_urdu.
  ///
  /// In en, this message translates to:
  /// **'اردو'**
  String get lang_urdu;

  /// No description provided for @lang_hindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get lang_hindi;

  /// No description provided for @lang_portuguese.
  ///
  /// In en, this message translates to:
  /// **'Português'**
  String get lang_portuguese;

  /// No description provided for @lang_thai.
  ///
  /// In en, this message translates to:
  /// **'ไทย'**
  String get lang_thai;

  /// No description provided for @lang_vietnamese.
  ///
  /// In en, this message translates to:
  /// **'Tiếng Việt'**
  String get lang_vietnamese;

  /// No description provided for @lang_subtitle_en.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get lang_subtitle_en;

  /// No description provided for @lang_subtitle_ar.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get lang_subtitle_ar;

  /// No description provided for @lang_subtitle_id.
  ///
  /// In en, this message translates to:
  /// **'Indonesian'**
  String get lang_subtitle_id;

  /// No description provided for @lang_subtitle_tr.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get lang_subtitle_tr;

  /// No description provided for @lang_subtitle_ur.
  ///
  /// In en, this message translates to:
  /// **'Urdu'**
  String get lang_subtitle_ur;

  /// No description provided for @lang_subtitle_hi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get lang_subtitle_hi;

  /// No description provided for @lang_subtitle_pt.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get lang_subtitle_pt;

  /// No description provided for @lang_subtitle_th.
  ///
  /// In en, this message translates to:
  /// **'Thai'**
  String get lang_subtitle_th;

  /// No description provided for @lang_subtitle_vi.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get lang_subtitle_vi;

  /// No description provided for @lang_changed.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get lang_changed;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get common_ok;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @common_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_search;

  /// No description provided for @common_more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get common_more;

  /// No description provided for @common_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// No description provided for @common_create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get common_create;

  /// No description provided for @common_user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get common_user;

  /// No description provided for @common_room.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get common_room;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get common_done;

  /// No description provided for @common_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get common_failed;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get common_submit;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get common_leave;

  /// No description provided for @common_claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get common_claim;

  /// No description provided for @common_claimed.
  ///
  /// In en, this message translates to:
  /// **'Claimed'**
  String get common_claimed;

  /// No description provided for @nav_home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get nav_home;

  /// No description provided for @nav_party.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get nav_party;

  /// No description provided for @nav_game.
  ///
  /// In en, this message translates to:
  /// **'Game'**
  String get nav_game;

  /// No description provided for @nav_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get nav_message;

  /// No description provided for @nav_my.
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get nav_my;

  /// No description provided for @nav_tabFallback.
  ///
  /// In en, this message translates to:
  /// **'Tab'**
  String get nav_tabFallback;

  /// No description provided for @nav_roomOffline.
  ///
  /// In en, this message translates to:
  /// **'Room is offline right now'**
  String get nav_roomOffline;

  /// No description provided for @profile_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get profile_language;

  /// No description provided for @profile_followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profile_followers;

  /// No description provided for @profile_following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profile_following;

  /// No description provided for @profile_friends.
  ///
  /// In en, this message translates to:
  /// **'Friends'**
  String get profile_friends;

  /// No description provided for @profile_visits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get profile_visits;

  /// No description provided for @profile_store.
  ///
  /// In en, this message translates to:
  /// **'Store'**
  String get profile_store;

  /// No description provided for @profile_level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get profile_level;

  /// No description provided for @profile_vip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get profile_vip;

  /// No description provided for @profile_decoration.
  ///
  /// In en, this message translates to:
  /// **'Decoration'**
  String get profile_decoration;

  /// No description provided for @profile_events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get profile_events;

  /// No description provided for @profile_wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get profile_wallet;

  /// No description provided for @profile_hostCenter.
  ///
  /// In en, this message translates to:
  /// **'Host Center'**
  String get profile_hostCenter;

  /// No description provided for @profile_roomReward.
  ///
  /// In en, this message translates to:
  /// **'Room Reward'**
  String get profile_roomReward;

  /// No description provided for @profile_micReward.
  ///
  /// In en, this message translates to:
  /// **'Mic Reward'**
  String get profile_micReward;

  /// No description provided for @profile_agency.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get profile_agency;

  /// No description provided for @profile_invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get profile_invite;

  /// No description provided for @profile_getVip.
  ///
  /// In en, this message translates to:
  /// **'Get VIP'**
  String get profile_getVip;

  /// No description provided for @profile_upgrade.
  ///
  /// In en, this message translates to:
  /// **'Upgrade'**
  String get profile_upgrade;

  /// No description provided for @profile_vipLevel.
  ///
  /// In en, this message translates to:
  /// **'VIP {level}'**
  String profile_vipLevel(int level);

  /// No description provided for @profile_wealthCharmLevels.
  ///
  /// In en, this message translates to:
  /// **'Wealth & Charm Levels'**
  String get profile_wealthCharmLevels;

  /// No description provided for @profile_agencyLevel.
  ///
  /// In en, this message translates to:
  /// **'Agency Level'**
  String get profile_agencyLevel;

  /// No description provided for @profile_roomLevel.
  ///
  /// In en, this message translates to:
  /// **'Room Level'**
  String get profile_roomLevel;

  /// No description provided for @profile_task.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get profile_task;

  /// No description provided for @profile_feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get profile_feedback;

  /// No description provided for @profile_realNameVerify.
  ///
  /// In en, this message translates to:
  /// **'Real Name Verify'**
  String get profile_realNameVerify;

  /// No description provided for @profile_cpNest.
  ///
  /// In en, this message translates to:
  /// **'CP Nest'**
  String get profile_cpNest;

  /// No description provided for @profile_buddies.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get profile_buddies;

  /// No description provided for @profile_resellerPanel.
  ///
  /// In en, this message translates to:
  /// **'Reseller Panel'**
  String get profile_resellerPanel;

  /// No description provided for @profile_accountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get profile_accountManagement;

  /// No description provided for @profile_staffCenter.
  ///
  /// In en, this message translates to:
  /// **'{role} Center'**
  String profile_staffCenter(String role);

  /// No description provided for @profile_roleSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get profile_roleSuperAdmin;

  /// No description provided for @profile_roleCountyAdmin.
  ///
  /// In en, this message translates to:
  /// **'County Admin'**
  String get profile_roleCountyAdmin;

  /// No description provided for @profile_roleAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get profile_roleAssistant;

  /// No description provided for @profile_roleCustomerService.
  ///
  /// In en, this message translates to:
  /// **'Customer Service'**
  String get profile_roleCustomerService;

  /// No description provided for @profile_roleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get profile_roleStaff;

  /// No description provided for @profile_fallbackUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get profile_fallbackUser;

  /// No description provided for @profile_idCopied.
  ///
  /// In en, this message translates to:
  /// **'ID copied'**
  String get profile_idCopied;

  /// No description provided for @auth_continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get auth_continueWithGoogle;

  /// No description provided for @auth_agreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By using our app, you agree with our '**
  String get auth_agreePrefix;

  /// No description provided for @auth_termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get auth_termsOfService;

  /// No description provided for @auth_and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get auth_and;

  /// No description provided for @auth_privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get auth_privacyPolicy;

  /// No description provided for @auth_acceptTermsSnack.
  ///
  /// In en, this message translates to:
  /// **'Please accept Terms of Service and Privacy Policy.'**
  String get auth_acceptTermsSnack;

  /// No description provided for @auth_verifyPhoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get auth_verifyPhoneTitle;

  /// No description provided for @auth_codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Code has been sent to'**
  String get auth_codeSentTo;

  /// No description provided for @auth_verifyAndProceed.
  ///
  /// In en, this message translates to:
  /// **'VERIFY & PROCEED'**
  String get auth_verifyAndProceed;

  /// No description provided for @auth_resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get auth_resendCode;

  /// No description provided for @auth_verificationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Verification Successful!'**
  String get auth_verificationSuccessful;

  /// No description provided for @auth_completeProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your profile'**
  String get auth_completeProfileTitle;

  /// No description provided for @auth_nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get auth_nickname;

  /// No description provided for @auth_hintEnter.
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get auth_hintEnter;

  /// No description provided for @auth_basicInformation.
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get auth_basicInformation;

  /// No description provided for @auth_dateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get auth_dateOfBirth;

  /// No description provided for @auth_countryRegion.
  ///
  /// In en, this message translates to:
  /// **'Country/Region'**
  String get auth_countryRegion;

  /// No description provided for @auth_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get auth_select;

  /// No description provided for @auth_invitationCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'Invitation code (optional)'**
  String get auth_invitationCodeOptional;

  /// No description provided for @auth_friendShortIdHint.
  ///
  /// In en, this message translates to:
  /// **'Friend short ID'**
  String get auth_friendShortIdHint;

  /// No description provided for @auth_go.
  ///
  /// In en, this message translates to:
  /// **'GO'**
  String get auth_go;

  /// No description provided for @auth_searchCountryHint.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get auth_searchCountryHint;

  /// No description provided for @auth_fillRequiredFields.
  ///
  /// In en, this message translates to:
  /// **'Please fill all required fields'**
  String get auth_fillRequiredFields;

  /// No description provided for @auth_chooseAvailableNickname.
  ///
  /// In en, this message translates to:
  /// **'Please choose an available nickname'**
  String get auth_chooseAvailableNickname;

  /// No description provided for @auth_invitationBonusApplied.
  ///
  /// In en, this message translates to:
  /// **'Invitation bonus applied!'**
  String get auth_invitationBonusApplied;

  /// No description provided for @auth_failedUpdateProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to update profile'**
  String get auth_failedUpdateProfile;

  /// No description provided for @auth_accountManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get auth_accountManagementTitle;

  /// No description provided for @auth_sectionAccountBinding.
  ///
  /// In en, this message translates to:
  /// **'Account Binding'**
  String get auth_sectionAccountBinding;

  /// No description provided for @auth_sectionAccountManagement.
  ///
  /// In en, this message translates to:
  /// **'Account Management'**
  String get auth_sectionAccountManagement;

  /// No description provided for @auth_sectionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get auth_sectionOther;

  /// No description provided for @auth_google.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get auth_google;

  /// No description provided for @auth_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email;

  /// No description provided for @auth_notBound.
  ///
  /// In en, this message translates to:
  /// **'Not bound'**
  String get auth_notBound;

  /// No description provided for @auth_setPassword.
  ///
  /// In en, this message translates to:
  /// **'Set Password'**
  String get auth_setPassword;

  /// No description provided for @auth_accountCancellation.
  ///
  /// In en, this message translates to:
  /// **'Account Cancellation'**
  String get auth_accountCancellation;

  /// No description provided for @auth_aboutSkLive.
  ///
  /// In en, this message translates to:
  /// **'About LIVO'**
  String get auth_aboutSkLive;

  /// No description provided for @auth_aboutBlurb.
  ///
  /// In en, this message translates to:
  /// **'Premium social audio community with voice rooms, gifting, and more.'**
  String get auth_aboutBlurb;

  /// No description provided for @auth_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get auth_logout;

  /// No description provided for @auth_logoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get auth_logoutConfirm;

  /// No description provided for @auth_requestCancellation.
  ///
  /// In en, this message translates to:
  /// **'Request cancellation'**
  String get auth_requestCancellation;

  /// No description provided for @auth_cancellationBody.
  ///
  /// In en, this message translates to:
  /// **'This will submit a cancellation request. Your account access will end after review. This cannot be undone easily.\n\nContinue?'**
  String get auth_cancellationBody;

  /// No description provided for @auth_cancellationSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Cancellation request submitted. Signing out…'**
  String get auth_cancellationSubmitted;

  /// No description provided for @auth_bindEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'No email on this account. Bind email first.'**
  String get auth_bindEmailFirst;

  /// No description provided for @auth_passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get auth_passwordUpdated;

  /// No description provided for @auth_newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get auth_newPassword;

  /// No description provided for @auth_confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get auth_confirmPassword;

  /// No description provided for @auth_passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get auth_passwordMinLength;

  /// No description provided for @auth_passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get auth_passwordsDoNotMatch;

  /// No description provided for @auth_savePassword.
  ///
  /// In en, this message translates to:
  /// **'Save Password'**
  String get auth_savePassword;

  /// No description provided for @auth_sendResetLinkInstead.
  ///
  /// In en, this message translates to:
  /// **'Send reset link instead'**
  String get auth_sendResetLinkInstead;

  /// No description provided for @auth_passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to your email'**
  String get auth_passwordResetSent;

  /// No description provided for @auth_versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String auth_versionLabel(String version);

  /// No description provided for @wallet_title.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet_title;

  /// No description provided for @wallet_recordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Wallet Record'**
  String get wallet_recordTooltip;

  /// No description provided for @wallet_tabGoldCoins.
  ///
  /// In en, this message translates to:
  /// **'Gold Coins'**
  String get wallet_tabGoldCoins;

  /// No description provided for @wallet_tabDiamonds.
  ///
  /// In en, this message translates to:
  /// **'Diamonds'**
  String get wallet_tabDiamonds;

  /// No description provided for @wallet_tabBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get wallet_tabBalance;

  /// No description provided for @wallet_coinBalance.
  ///
  /// In en, this message translates to:
  /// **'Coin Balance'**
  String get wallet_coinBalance;

  /// No description provided for @wallet_paymentUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Payment system is not available on this device.'**
  String get wallet_paymentUnavailable;

  /// No description provided for @wallet_rechargeIssuesPrefix.
  ///
  /// In en, this message translates to:
  /// **'Having issues with recharging? '**
  String get wallet_rechargeIssuesPrefix;

  /// No description provided for @wallet_contactUs.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get wallet_contactUs;

  /// No description provided for @wallet_goldCoinReseller.
  ///
  /// In en, this message translates to:
  /// **'Gold Coin Reseller'**
  String get wallet_goldCoinReseller;

  /// No description provided for @wallet_openResellerCenter.
  ///
  /// In en, this message translates to:
  /// **'Open Reseller Center · stock & policy'**
  String get wallet_openResellerCenter;

  /// No description provided for @wallet_exchangeGoldCoins.
  ///
  /// In en, this message translates to:
  /// **'Exchange Gold Coins'**
  String get wallet_exchangeGoldCoins;

  /// No description provided for @wallet_exchangeToSalary.
  ///
  /// In en, this message translates to:
  /// **'Exchange to Salary Wallet'**
  String get wallet_exchangeToSalary;

  /// No description provided for @wallet_enterExchangeAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter the exchange amount'**
  String get wallet_enterExchangeAmount;

  /// No description provided for @wallet_maximum.
  ///
  /// In en, this message translates to:
  /// **'Maximum'**
  String get wallet_maximum;

  /// No description provided for @wallet_redeemablePrefix.
  ///
  /// In en, this message translates to:
  /// **'Redeemable: '**
  String get wallet_redeemablePrefix;

  /// No description provided for @wallet_earnByParticipation.
  ///
  /// In en, this message translates to:
  /// **'Earn by participation or gift ride'**
  String get wallet_earnByParticipation;

  /// No description provided for @wallet_diamond.
  ///
  /// In en, this message translates to:
  /// **'Diamond'**
  String get wallet_diamond;

  /// No description provided for @wallet_afterSalaryExchangePrefix.
  ///
  /// In en, this message translates to:
  /// **'After exchanging your salary, you can '**
  String get wallet_afterSalaryExchangePrefix;

  /// No description provided for @wallet_exchangeForGoldCoins.
  ///
  /// In en, this message translates to:
  /// **'exchange for gold coins'**
  String get wallet_exchangeForGoldCoins;

  /// No description provided for @wallet_inWalletAnytime.
  ///
  /// In en, this message translates to:
  /// **' in the wallet at any time!'**
  String get wallet_inWalletAnytime;

  /// No description provided for @wallet_exchangeSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Exchange successful!'**
  String get wallet_exchangeSuccessful;

  /// No description provided for @wallet_exchangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Exchange failed'**
  String get wallet_exchangeFailed;

  /// No description provided for @wallet_exchangeToOneself.
  ///
  /// In en, this message translates to:
  /// **'Exchange to oneself'**
  String get wallet_exchangeToOneself;

  /// No description provided for @wallet_exchangeToOther.
  ///
  /// In en, this message translates to:
  /// **'Exchange to other'**
  String get wallet_exchangeToOther;

  /// No description provided for @wallet_goldCoinsExchange.
  ///
  /// In en, this message translates to:
  /// **'Gold coins exchange'**
  String get wallet_goldCoinsExchange;

  /// No description provided for @wallet_enterCoinsRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Enter the number of coins redeemed'**
  String get wallet_enterCoinsRedeemed;

  /// No description provided for @wallet_exchange.
  ///
  /// In en, this message translates to:
  /// **'Exchange'**
  String get wallet_exchange;

  /// No description provided for @wallet_withdraw.
  ///
  /// In en, this message translates to:
  /// **'Withdraw'**
  String get wallet_withdraw;

  /// No description provided for @wallet_cashWallet.
  ///
  /// In en, this message translates to:
  /// **'Cash wallet'**
  String get wallet_cashWallet;

  /// No description provided for @wallet_coinMerchants.
  ///
  /// In en, this message translates to:
  /// **'Coin Merchants'**
  String get wallet_coinMerchants;

  /// No description provided for @wallet_buyFromResellers.
  ///
  /// In en, this message translates to:
  /// **'Buy coins from trusted resellers'**
  String get wallet_buyFromResellers;

  /// No description provided for @wallet_enterIdHint.
  ///
  /// In en, this message translates to:
  /// **'Please enter the ID'**
  String get wallet_enterIdHint;

  /// No description provided for @wallet_noUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found'**
  String get wallet_noUserFound;

  /// No description provided for @wallet_enterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount'**
  String get wallet_enterValidAmount;

  /// No description provided for @wallet_insufficientCash.
  ///
  /// In en, this message translates to:
  /// **'Insufficient cash balance'**
  String get wallet_insufficientCash;

  /// No description provided for @wallet_selectRecipient.
  ///
  /// In en, this message translates to:
  /// **'Select a recipient'**
  String get wallet_selectRecipient;

  /// No description provided for @wallet_rechargeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully recharged {coins} Coins!'**
  String wallet_rechargeSuccess(String coins);

  /// No description provided for @messages_tabMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messages_tabMessage;

  /// No description provided for @messages_tabContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get messages_tabContacts;

  /// No description provided for @messages_searchFriendsHint.
  ///
  /// In en, this message translates to:
  /// **'Search friends...'**
  String get messages_searchFriendsHint;

  /// No description provided for @messages_pleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get messages_pleaseSignIn;

  /// No description provided for @messages_noContent.
  ///
  /// In en, this message translates to:
  /// **'No content'**
  String get messages_noContent;

  /// No description provided for @messages_noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get messages_noMessagesYet;

  /// No description provided for @messages_noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found for \"{query}\"'**
  String messages_noUsersFound(String query);

  /// No description provided for @messages_inRoom.
  ///
  /// In en, this message translates to:
  /// **'In room: {title}'**
  String messages_inRoom(String title);

  /// No description provided for @messages_friendCount.
  ///
  /// In en, this message translates to:
  /// **'Friend {count}'**
  String messages_friendCount(int count);

  /// No description provided for @messages_followingCount.
  ///
  /// In en, this message translates to:
  /// **'Following {count}'**
  String messages_followingCount(int count);

  /// No description provided for @messages_fansCount.
  ///
  /// In en, this message translates to:
  /// **'Fans {count}'**
  String messages_fansCount(int count);

  /// No description provided for @feedback_title.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback_title;

  /// No description provided for @feedback_contactDetails.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get feedback_contactDetails;

  /// No description provided for @feedback_contactHint.
  ///
  /// In en, this message translates to:
  /// **'Phone, email, or WhatsApp'**
  String get feedback_contactHint;

  /// No description provided for @feedback_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get feedback_message;

  /// No description provided for @feedback_required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get feedback_required;

  /// No description provided for @feedback_submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get feedback_submit;

  /// No description provided for @feedback_sentThanks.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent. Thank you!'**
  String get feedback_sentThanks;

  /// No description provided for @party_mineTitle.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get party_mineTitle;

  /// No description provided for @party_tabHot.
  ///
  /// In en, this message translates to:
  /// **'Hot'**
  String get party_tabHot;

  /// No description provided for @party_tabRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get party_tabRoom;

  /// No description provided for @party_tooltipRanking.
  ///
  /// In en, this message translates to:
  /// **'Ranking'**
  String get party_tooltipRanking;

  /// No description provided for @party_tooltipSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get party_tooltipSearch;

  /// No description provided for @party_tooltipMyRoom.
  ///
  /// In en, this message translates to:
  /// **'My Room'**
  String get party_tooltipMyRoom;

  /// No description provided for @party_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Room name, Room ID, or username…'**
  String get party_searchHint;

  /// No description provided for @party_typeRoomNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Type room name or Room ID'**
  String get party_typeRoomNameOrId;

  /// No description provided for @party_typeUsernameOrUid.
  ///
  /// In en, this message translates to:
  /// **'Type username or UID'**
  String get party_typeUsernameOrUid;

  /// No description provided for @party_noRoomFound.
  ///
  /// In en, this message translates to:
  /// **'No room found for \"{query}\"'**
  String party_noRoomFound(String query);

  /// No description provided for @party_noUserFound.
  ///
  /// In en, this message translates to:
  /// **'No user found for \"{query}\"'**
  String party_noUserFound(String query);

  /// No description provided for @party_myRoom.
  ///
  /// In en, this message translates to:
  /// **'My room'**
  String get party_myRoom;

  /// No description provided for @party_roomLevelBadges.
  ///
  /// In en, this message translates to:
  /// **'Room Level & Badges'**
  String get party_roomLevelBadges;

  /// No description provided for @party_recents.
  ///
  /// In en, this message translates to:
  /// **'Recents'**
  String get party_recents;

  /// No description provided for @party_myFollowings.
  ///
  /// In en, this message translates to:
  /// **'My followings'**
  String get party_myFollowings;

  /// No description provided for @party_managedRooms.
  ///
  /// In en, this message translates to:
  /// **'Managed Rooms'**
  String get party_managedRooms;

  /// No description provided for @party_emptyRecents.
  ///
  /// In en, this message translates to:
  /// **'No recently visited rooms'**
  String get party_emptyRecents;

  /// No description provided for @party_emptyFollowings.
  ///
  /// In en, this message translates to:
  /// **'No following rooms yet'**
  String get party_emptyFollowings;

  /// No description provided for @party_noRoomsFromCountry.
  ///
  /// In en, this message translates to:
  /// **'No rooms found from this country'**
  String get party_noRoomsFromCountry;

  /// No description provided for @party_countriesRegion.
  ///
  /// In en, this message translates to:
  /// **'Countries/Region'**
  String get party_countriesRegion;

  /// No description provided for @party_pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Pull to refresh.'**
  String get party_pullToRefresh;

  /// No description provided for @party_couldNotOpenRoom.
  ///
  /// In en, this message translates to:
  /// **'Could not open your room'**
  String get party_couldNotOpenRoom;

  /// No description provided for @party_alreadyHaveRoom.
  ///
  /// In en, this message translates to:
  /// **'You already have a room.'**
  String get party_alreadyHaveRoom;

  /// No description provided for @party_roomNotFoundOffline.
  ///
  /// In en, this message translates to:
  /// **'Room not found or offline'**
  String get party_roomNotFoundOffline;

  /// No description provided for @party_unknownHost.
  ///
  /// In en, this message translates to:
  /// **'Unknown Host'**
  String get party_unknownHost;

  /// No description provided for @party_defaultBio.
  ///
  /// In en, this message translates to:
  /// **'I hope you have a happy day.'**
  String get party_defaultBio;

  /// No description provided for @party_searchCountry.
  ///
  /// In en, this message translates to:
  /// **'Search country...'**
  String get party_searchCountry;

  /// No description provided for @shop_title.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop_title;

  /// No description provided for @shop_mine.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get shop_mine;

  /// No description provided for @shop_noItems.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get shop_noItems;

  /// No description provided for @shop_purchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get shop_purchase;

  /// No description provided for @shop_send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get shop_send;

  /// No description provided for @shop_sendGiftTo.
  ///
  /// In en, this message translates to:
  /// **'Send Gift To'**
  String get shop_sendGiftTo;

  /// No description provided for @shop_noUsers.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get shop_noUsers;

  /// No description provided for @shop_notForSale.
  ///
  /// In en, this message translates to:
  /// **'NOT FOR SALE'**
  String get shop_notForSale;

  /// No description provided for @shop_medal.
  ///
  /// In en, this message translates to:
  /// **'MEDAL'**
  String get shop_medal;

  /// No description provided for @shop_medalOnly.
  ///
  /// In en, this message translates to:
  /// **'Medal Only'**
  String get shop_medalOnly;

  /// No description provided for @shop_locked.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get shop_locked;

  /// No description provided for @shop_vipLevelBadge.
  ///
  /// In en, this message translates to:
  /// **'VIP Lv.{level}'**
  String shop_vipLevelBadge(int level);

  /// No description provided for @shop_insufficientCoins.
  ///
  /// In en, this message translates to:
  /// **'Insufficient coins!'**
  String get shop_insufficientCoins;

  /// No description provided for @shop_purchasedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Purchased successfully!'**
  String get shop_purchasedSuccessfully;

  /// No description provided for @shop_purchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed!'**
  String get shop_purchaseFailed;

  /// No description provided for @shop_preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get shop_preview;

  /// No description provided for @vip_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'VIP Center'**
  String get vip_centerTitle;

  /// No description provided for @vip_unlocked.
  ///
  /// In en, this message translates to:
  /// **'UNLOCKED'**
  String get vip_unlocked;

  /// No description provided for @vip_locked.
  ///
  /// In en, this message translates to:
  /// **'LOCKED'**
  String get vip_locked;

  /// No description provided for @vip_gotIt.
  ///
  /// In en, this message translates to:
  /// **'GOT IT'**
  String get vip_gotIt;

  /// No description provided for @vip_includedInLevel.
  ///
  /// In en, this message translates to:
  /// **'Included in this VIP level'**
  String get vip_includedInLevel;

  /// No description provided for @vip_lockedForLevel.
  ///
  /// In en, this message translates to:
  /// **'Locked for this level'**
  String get vip_lockedForLevel;

  /// No description provided for @vip_noPlans.
  ///
  /// In en, this message translates to:
  /// **'No VIP plans available'**
  String get vip_noPlans;

  /// No description provided for @task_newbieTasks.
  ///
  /// In en, this message translates to:
  /// **'Newbie Tasks'**
  String get task_newbieTasks;

  /// No description provided for @task_dailyTasks.
  ///
  /// In en, this message translates to:
  /// **'Daily Tasks'**
  String get task_dailyTasks;

  /// No description provided for @task_noDrawsLeft.
  ///
  /// In en, this message translates to:
  /// **'No draws left. Check in or claim a task.'**
  String get task_noDrawsLeft;

  /// No description provided for @task_checkinBonus.
  ///
  /// In en, this message translates to:
  /// **'Check-in Bonus'**
  String get task_checkinBonus;

  /// No description provided for @task_checkIn.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get task_checkIn;

  /// No description provided for @task_checkedIn.
  ///
  /// In en, this message translates to:
  /// **'Checked in'**
  String get task_checkedIn;

  /// No description provided for @task_go.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get task_go;

  /// No description provided for @task_got.
  ///
  /// In en, this message translates to:
  /// **'Got'**
  String get task_got;

  /// No description provided for @task_claimFailed.
  ///
  /// In en, this message translates to:
  /// **'Claim failed'**
  String get task_claimFailed;

  /// No description provided for @task_checkinFailed.
  ///
  /// In en, this message translates to:
  /// **'Check-in failed'**
  String get task_checkinFailed;

  /// No description provided for @task_luckyWheel.
  ///
  /// In en, this message translates to:
  /// **'Lucky Wheel'**
  String get task_luckyWheel;

  /// No description provided for @task_spinRecord.
  ///
  /// In en, this message translates to:
  /// **'Spin Record'**
  String get task_spinRecord;

  /// No description provided for @task_record.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get task_record;

  /// No description provided for @reward_micTitle.
  ///
  /// In en, this message translates to:
  /// **'Mic Reward'**
  String get reward_micTitle;

  /// No description provided for @reward_roomTitle.
  ///
  /// In en, this message translates to:
  /// **'Room Reward'**
  String get reward_roomTitle;

  /// No description provided for @reward_rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get reward_rules;

  /// No description provided for @reward_levels.
  ///
  /// In en, this message translates to:
  /// **'Levels'**
  String get reward_levels;

  /// No description provided for @reward_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get reward_today;

  /// No description provided for @reward_thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get reward_thisWeek;

  /// No description provided for @reward_stayUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Stay unmuted on a mic to earn'**
  String get reward_stayUnmuted;

  /// No description provided for @reward_roomOwnerRewards.
  ///
  /// In en, this message translates to:
  /// **'Room owner rewards'**
  String get reward_roomOwnerRewards;

  /// No description provided for @reward_yourRoomWeekly.
  ///
  /// In en, this message translates to:
  /// **'Your room · weekly targets'**
  String get reward_yourRoomWeekly;

  /// No description provided for @reward_claimedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Claimed successfully'**
  String get reward_claimedSuccessfully;

  /// No description provided for @reward_claimFailed.
  ///
  /// In en, this message translates to:
  /// **'Claim failed'**
  String get reward_claimFailed;

  /// No description provided for @reward_noLevels.
  ///
  /// In en, this message translates to:
  /// **'No levels configured'**
  String get reward_noLevels;

  /// No description provided for @reward_allTiersUnlocked.
  ///
  /// In en, this message translates to:
  /// **'All tiers unlocked today'**
  String get reward_allTiersUnlocked;

  /// No description provided for @reward_lastWeekClaimed.
  ///
  /// In en, this message translates to:
  /// **'Last week already claimed'**
  String get reward_lastWeekClaimed;

  /// No description provided for @reward_assetReward.
  ///
  /// In en, this message translates to:
  /// **'Asset reward'**
  String get reward_assetReward;

  /// No description provided for @reward_noMicLevelsAdmin.
  ///
  /// In en, this message translates to:
  /// **'No reward levels yet. Ask admin to configure Mic Daily Rewards.'**
  String get reward_noMicLevelsAdmin;

  /// No description provided for @reward_noRoomLevelsAdmin.
  ///
  /// In en, this message translates to:
  /// **'No reward levels yet. Ask admin to configure Room Reward.'**
  String get reward_noRoomLevelsAdmin;

  /// No description provided for @host_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'Host Center'**
  String get host_centerTitle;

  /// No description provided for @host_salaryHistory.
  ///
  /// In en, this message translates to:
  /// **'Salary History'**
  String get host_salaryHistory;

  /// No description provided for @host_noSalaryPayouts.
  ///
  /// In en, this message translates to:
  /// **'No salary payouts yet.'**
  String get host_noSalaryPayouts;

  /// No description provided for @host_leaveAgency.
  ///
  /// In en, this message translates to:
  /// **'Leave Agency'**
  String get host_leaveAgency;

  /// No description provided for @host_leaveAgencyConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave Agency?'**
  String get host_leaveAgencyConfirmTitle;

  /// No description provided for @host_leaveAgencyConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'You will stop earning gift diamonds until you join again.'**
  String get host_leaveAgencyConfirmBody;

  /// No description provided for @host_periodCharm.
  ///
  /// In en, this message translates to:
  /// **'Period Charm'**
  String get host_periodCharm;

  /// No description provided for @host_onMicHours.
  ///
  /// In en, this message translates to:
  /// **'On-mic Hours'**
  String get host_onMicHours;

  /// No description provided for @host_validDays.
  ///
  /// In en, this message translates to:
  /// **'Valid Days'**
  String get host_validDays;

  /// No description provided for @agency_title.
  ///
  /// In en, this message translates to:
  /// **'Agency'**
  String get agency_title;

  /// No description provided for @agency_recommended.
  ///
  /// In en, this message translates to:
  /// **'Recommended Agency'**
  String get agency_recommended;

  /// No description provided for @agency_searchHint.
  ///
  /// In en, this message translates to:
  /// **'ID or Name'**
  String get agency_searchHint;

  /// No description provided for @agency_noAgencies.
  ///
  /// In en, this message translates to:
  /// **'No agencies found'**
  String get agency_noAgencies;

  /// No description provided for @agency_noMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching agencies'**
  String get agency_noMatching;

  /// No description provided for @agency_welcomeJoin.
  ///
  /// In en, this message translates to:
  /// **'Welcome to join us'**
  String get agency_welcomeJoin;

  /// No description provided for @agency_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'Agency Center'**
  String get agency_centerTitle;

  /// No description provided for @contact_title.
  ///
  /// In en, this message translates to:
  /// **'Contact Us'**
  String get contact_title;

  /// No description provided for @contact_previousTickets.
  ///
  /// In en, this message translates to:
  /// **'Your Previous Tickets'**
  String get contact_previousTickets;

  /// No description provided for @contact_subject.
  ///
  /// In en, this message translates to:
  /// **'Subject'**
  String get contact_subject;

  /// No description provided for @contact_message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contact_message;

  /// No description provided for @contact_enterSubject.
  ///
  /// In en, this message translates to:
  /// **'Enter subject'**
  String get contact_enterSubject;

  /// No description provided for @contact_enterMessage.
  ///
  /// In en, this message translates to:
  /// **'Enter message'**
  String get contact_enterMessage;

  /// No description provided for @contact_sendMessage.
  ///
  /// In en, this message translates to:
  /// **'Send Message'**
  String get contact_sendMessage;

  /// No description provided for @contact_attachmentOptional.
  ///
  /// In en, this message translates to:
  /// **'Attachment (Optional)'**
  String get contact_attachmentOptional;

  /// No description provided for @contact_tapUploadScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload screenshot'**
  String get contact_tapUploadScreenshot;

  /// No description provided for @contact_noHistory.
  ///
  /// In en, this message translates to:
  /// **'No message history.'**
  String get contact_noHistory;

  /// No description provided for @contact_replied.
  ///
  /// In en, this message translates to:
  /// **'Replied'**
  String get contact_replied;

  /// No description provided for @contact_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get contact_pending;

  /// No description provided for @contact_adminReply.
  ///
  /// In en, this message translates to:
  /// **'Admin Reply'**
  String get contact_adminReply;

  /// No description provided for @contact_messageSent.
  ///
  /// In en, this message translates to:
  /// **'Message sent! We will reply soon.'**
  String get contact_messageSent;

  /// No description provided for @room_live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get room_live;

  /// No description provided for @room_members.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get room_members;

  /// No description provided for @room_gifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get room_gifts;

  /// No description provided for @room_chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get room_chat;

  /// No description provided for @room_mute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get room_mute;

  /// No description provided for @room_unmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get room_unmute;

  /// No description provided for @room_leaveMic.
  ///
  /// In en, this message translates to:
  /// **'Leave mic'**
  String get room_leaveMic;

  /// No description provided for @room_takeMic.
  ///
  /// In en, this message translates to:
  /// **'Take mic'**
  String get room_takeMic;

  /// No description provided for @room_invite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get room_invite;

  /// No description provided for @room_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get room_settings;

  /// No description provided for @room_contribution.
  ///
  /// In en, this message translates to:
  /// **'Contribution'**
  String get room_contribution;

  /// No description provided for @room_luckyBag.
  ///
  /// In en, this message translates to:
  /// **'Lucky Bag'**
  String get room_luckyBag;

  /// No description provided for @room_pk.
  ///
  /// In en, this message translates to:
  /// **'PK'**
  String get room_pk;

  /// No description provided for @room_teamPk.
  ///
  /// In en, this message translates to:
  /// **'Team PK'**
  String get room_teamPk;

  /// No description provided for @inventory_title.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory_title;

  /// No description provided for @inventory_frames.
  ///
  /// In en, this message translates to:
  /// **'Frames'**
  String get inventory_frames;

  /// No description provided for @inventory_empty.
  ///
  /// In en, this message translates to:
  /// **'No items yet'**
  String get inventory_empty;

  /// No description provided for @events_title.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events_title;

  /// No description provided for @invite_title.
  ///
  /// In en, this message translates to:
  /// **'Invite & Earn'**
  String get invite_title;

  /// No description provided for @cp_nestTitle.
  ///
  /// In en, this message translates to:
  /// **'CP Nest'**
  String get cp_nestTitle;

  /// No description provided for @buddies_title.
  ///
  /// In en, this message translates to:
  /// **'Buddies'**
  String get buddies_title;

  /// No description provided for @intimacy_title.
  ///
  /// In en, this message translates to:
  /// **'Intimacy'**
  String get intimacy_title;

  /// No description provided for @family_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'Family Center'**
  String get family_centerTitle;

  /// No description provided for @staff_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'Staff Center'**
  String get staff_centerTitle;

  /// No description provided for @bd_centerTitle.
  ///
  /// In en, this message translates to:
  /// **'BD Center'**
  String get bd_centerTitle;

  /// No description provided for @realName_title.
  ///
  /// In en, this message translates to:
  /// **'Real Name Verify'**
  String get realName_title;

  /// No description provided for @realName_guidelines.
  ///
  /// In en, this message translates to:
  /// **'Guidelines'**
  String get realName_guidelines;

  /// No description provided for @game_rupeeTitle.
  ///
  /// In en, this message translates to:
  /// **'Rupee Game'**
  String get game_rupeeTitle;

  /// No description provided for @game_help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get game_help;

  /// No description provided for @game_ranking.
  ///
  /// In en, this message translates to:
  /// **'Game Ranking'**
  String get game_ranking;

  /// No description provided for @social_discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get social_discover;

  /// No description provided for @social_createPost.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get social_createPost;

  /// No description provided for @edit_profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get edit_profileTitle;

  /// No description provided for @level_wealthTitle.
  ///
  /// In en, this message translates to:
  /// **'Wealth Level'**
  String get level_wealthTitle;

  /// No description provided for @level_charmTitle.
  ///
  /// In en, this message translates to:
  /// **'Charm Level'**
  String get level_charmTitle;

  /// No description provided for @level_userTitle.
  ///
  /// In en, this message translates to:
  /// **'User Level'**
  String get level_userTitle;

  /// No description provided for @level_cpTitle.
  ///
  /// In en, this message translates to:
  /// **'CP Level'**
  String get level_cpTitle;

  /// No description provided for @level_roomTitle.
  ///
  /// In en, this message translates to:
  /// **'Room Level'**
  String get level_roomTitle;

  /// No description provided for @room_removeAdminTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin?'**
  String get room_removeAdminTitle;

  /// No description provided for @room_removeAdminBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this admin?'**
  String get room_removeAdminBody;

  /// No description provided for @room_removedAsAdmin.
  ///
  /// In en, this message translates to:
  /// **'{username} removed as admin'**
  String room_removedAsAdmin(String username);

  /// No description provided for @room_cannotModerateSuperAdmin.
  ///
  /// In en, this message translates to:
  /// **'You cannot moderate another Super Admin.'**
  String get room_cannotModerateSuperAdmin;

  /// No description provided for @room_kickDuration3h.
  ///
  /// In en, this message translates to:
  /// **'3 Hours'**
  String get room_kickDuration3h;

  /// No description provided for @room_kickDuration24h.
  ///
  /// In en, this message translates to:
  /// **'24 Hours'**
  String get room_kickDuration24h;

  /// No description provided for @room_kickDurationPermanent.
  ///
  /// In en, this message translates to:
  /// **'Permanent'**
  String get room_kickDurationPermanent;

  /// No description provided for @room_kickRejoin3h.
  ///
  /// In en, this message translates to:
  /// **'Can rejoin after 3 hours'**
  String get room_kickRejoin3h;

  /// No description provided for @room_kickRejoin24h.
  ///
  /// In en, this message translates to:
  /// **'Can rejoin after 24 hours'**
  String get room_kickRejoin24h;

  /// No description provided for @room_kickBannedUntilCleared.
  ///
  /// In en, this message translates to:
  /// **'Banned until manually cleared'**
  String get room_kickBannedUntilCleared;

  /// No description provided for @room_couldNotKick.
  ///
  /// In en, this message translates to:
  /// **'Could not kick user: {error}'**
  String room_couldNotKick(String error);

  /// No description provided for @room_couldNotOpenChat.
  ///
  /// In en, this message translates to:
  /// **'Could not open chat: {error}'**
  String room_couldNotOpenChat(String error);

  /// No description provided for @room_noEmptySeat.
  ///
  /// In en, this message translates to:
  /// **'No empty seat available'**
  String get room_noEmptySeat;

  /// No description provided for @room_viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get room_viewProfile;

  /// No description provided for @room_makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get room_makeAdmin;

  /// No description provided for @room_removeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Remove Admin'**
  String get room_removeAdmin;

  /// No description provided for @room_removeFromSeat.
  ///
  /// In en, this message translates to:
  /// **'Remove from Seat'**
  String get room_removeFromSeat;

  /// No description provided for @room_addToBlacklist.
  ///
  /// In en, this message translates to:
  /// **'Add to blacklist'**
  String get room_addToBlacklist;

  /// No description provided for @room_chatRestrictedAdmins.
  ///
  /// In en, this message translates to:
  /// **'Chat is restricted to admins & host only.'**
  String get room_chatRestrictedAdmins;

  /// No description provided for @room_couldNotUploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Could not upload photo'**
  String get room_couldNotUploadPhoto;

  /// No description provided for @room_savingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Saving photo…'**
  String get room_savingPhoto;

  /// No description provided for @room_couldNotSyncMic.
  ///
  /// In en, this message translates to:
  /// **'Could not sync mic. Please try again.'**
  String get room_couldNotSyncMic;

  /// No description provided for @room_minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get room_minimize;

  /// No description provided for @room_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get room_close;

  /// No description provided for @room_couldNotStartYoutube.
  ///
  /// In en, this message translates to:
  /// **'Could not start YouTube for room: {error}'**
  String room_couldNotStartYoutube(String error);

  /// No description provided for @room_couldNotStopYoutube.
  ///
  /// In en, this message translates to:
  /// **'Could not stop YouTube: {error}'**
  String room_couldNotStopYoutube(String error);

  /// No description provided for @room_seatLocked.
  ///
  /// In en, this message translates to:
  /// **'Seat is locked'**
  String get room_seatLocked;

  /// No description provided for @room_infoTitle.
  ///
  /// In en, this message translates to:
  /// **'Room information'**
  String get room_infoTitle;

  /// No description provided for @room_noRoomForAccount.
  ///
  /// In en, this message translates to:
  /// **'No room found for your account.'**
  String get room_noRoomForAccount;

  /// No description provided for @room_createMyRoom.
  ///
  /// In en, this message translates to:
  /// **'Create My Room'**
  String get room_createMyRoom;

  /// No description provided for @room_alreadyHaveRoom.
  ///
  /// In en, this message translates to:
  /// **'You already have a room.'**
  String get room_alreadyHaveRoom;

  /// No description provided for @room_cover.
  ///
  /// In en, this message translates to:
  /// **'Room cover'**
  String get room_cover;

  /// No description provided for @room_idCopied.
  ///
  /// In en, this message translates to:
  /// **'Room ID copied!'**
  String get room_idCopied;

  /// No description provided for @room_name.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get room_name;

  /// No description provided for @room_topic.
  ///
  /// In en, this message translates to:
  /// **'Room topic'**
  String get room_topic;

  /// No description provided for @room_levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Room level'**
  String get room_levelLabel;

  /// No description provided for @room_country.
  ///
  /// In en, this message translates to:
  /// **'Room country'**
  String get room_country;

  /// No description provided for @room_announcement.
  ///
  /// In en, this message translates to:
  /// **'Room announcement'**
  String get room_announcement;

  /// No description provided for @room_decoration.
  ///
  /// In en, this message translates to:
  /// **'Room decoration'**
  String get room_decoration;

  /// No description provided for @room_clickToSet.
  ///
  /// In en, this message translates to:
  /// **'Click to set'**
  String get room_clickToSet;

  /// No description provided for @room_passwordSetTap.
  ///
  /// In en, this message translates to:
  /// **'Password set · tap to change'**
  String get room_passwordSetTap;

  /// No description provided for @room_setPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Set a 4–6 digit password to lock the room'**
  String get room_setPasswordHint;

  /// No description provided for @room_privateRoom.
  ///
  /// In en, this message translates to:
  /// **'Private room (will not be recommended by the system)'**
  String get room_privateRoom;

  /// No description provided for @room_showSpendingIcons.
  ///
  /// In en, this message translates to:
  /// **'Show spending icons (daily coins with online users)'**
  String get room_showSpendingIcons;

  /// No description provided for @room_viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get room_viewAll;

  /// No description provided for @room_membershipTag.
  ///
  /// In en, this message translates to:
  /// **'Membership tag'**
  String get room_membershipTag;

  /// No description provided for @room_lockPasswordRemoved.
  ///
  /// In en, this message translates to:
  /// **'Room lock password removed'**
  String get room_lockPasswordRemoved;

  /// No description provided for @room_lockPasswordSaved.
  ///
  /// In en, this message translates to:
  /// **'Room lock password saved — room is locked'**
  String get room_lockPasswordSaved;

  /// No description provided for @room_editTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {title}'**
  String room_editTitle(String title);

  /// No description provided for @room_passwordDigits.
  ///
  /// In en, this message translates to:
  /// **'Password must be 4–6 digits'**
  String get room_passwordDigits;

  /// No description provided for @room_lockPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Room Lock Password'**
  String get room_lockPasswordTitle;

  /// No description provided for @room_lockPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'Set a 4–6 digit password. Use Tools → Room Lock to lock/unlock. Leave empty to remove.'**
  String get room_lockPasswordHelp;

  /// No description provided for @room_enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get room_enterPassword;

  /// No description provided for @room_membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get room_membersTitle;

  /// No description provided for @room_membersAndAdmin.
  ///
  /// In en, this message translates to:
  /// **'Members & Add Admin'**
  String get room_membersAndAdmin;

  /// No description provided for @room_inviteSubAdmin.
  ///
  /// In en, this message translates to:
  /// **'Invite as Sub-Admin'**
  String get room_inviteSubAdmin;

  /// No description provided for @room_kickRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Kick-out Records'**
  String get room_kickRecordsTitle;

  /// No description provided for @room_unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock user?'**
  String get room_unblockUser;

  /// No description provided for @room_membersList.
  ///
  /// In en, this message translates to:
  /// **'Members list'**
  String get room_membersList;

  /// No description provided for @room_luckyBagTitle.
  ///
  /// In en, this message translates to:
  /// **'Room Lucky Bag'**
  String get room_luckyBagTitle;

  /// No description provided for @room_luckyBagValue.
  ///
  /// In en, this message translates to:
  /// **'Lucky Bag Value'**
  String get room_luckyBagValue;

  /// No description provided for @room_sendGift.
  ///
  /// In en, this message translates to:
  /// **'Send Gift'**
  String get room_sendGift;

  /// No description provided for @room_insufficientCoins.
  ///
  /// In en, this message translates to:
  /// **'Insufficient coins'**
  String get room_insufficientCoins;

  /// No description provided for @room_applyDecoration.
  ///
  /// In en, this message translates to:
  /// **'Apply decoration'**
  String get room_applyDecoration;

  /// No description provided for @room_shareToChat.
  ///
  /// In en, this message translates to:
  /// **'Share to chat'**
  String get room_shareToChat;

  /// No description provided for @room_seatInvite.
  ///
  /// In en, this message translates to:
  /// **'Seat invite'**
  String get room_seatInvite;

  /// No description provided for @room_youtube.
  ///
  /// In en, this message translates to:
  /// **'YouTube'**
  String get room_youtube;

  /// No description provided for @common_pullToRefresh.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Pull to refresh.'**
  String get common_pullToRefresh;

  /// No description provided for @chat_conversationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Conversation Blocked'**
  String get chat_conversationBlocked;

  /// No description provided for @chat_reportUser.
  ///
  /// In en, this message translates to:
  /// **'Report User'**
  String get chat_reportUser;

  /// No description provided for @chat_offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get chat_offline;

  /// No description provided for @chat_sentAGift.
  ///
  /// In en, this message translates to:
  /// **'Sent a gift'**
  String get chat_sentAGift;

  /// No description provided for @chat_copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get chat_copied;

  /// No description provided for @chat_noGiftCategories.
  ///
  /// In en, this message translates to:
  /// **'No gift categories'**
  String get chat_noGiftCategories;

  /// No description provided for @chat_insufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance!'**
  String get chat_insufficientBalance;

  /// No description provided for @chat_send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chat_send;

  /// No description provided for @chat_markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get chat_markAllRead;

  /// No description provided for @chat_couldNotMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Could not mark notifications as read'**
  String get chat_couldNotMarkRead;

  /// No description provided for @chat_notice.
  ///
  /// In en, this message translates to:
  /// **'Notice'**
  String get chat_notice;

  /// No description provided for @chat_activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get chat_activity;

  /// No description provided for @chat_feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get chat_feedback;

  /// No description provided for @party_couldNotOpenRoomGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not open room'**
  String get party_couldNotOpenRoomGeneric;

  /// No description provided for @party_eventNotFound.
  ///
  /// In en, this message translates to:
  /// **'Event not found'**
  String get party_eventNotFound;

  /// No description provided for @edit_nameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get edit_nameUpdated;

  /// No description provided for @edit_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get edit_male;

  /// No description provided for @edit_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get edit_female;

  /// No description provided for @edit_dobUpdated.
  ///
  /// In en, this message translates to:
  /// **'Date of birth updated'**
  String get edit_dobUpdated;

  /// No description provided for @profile_follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profile_follow;

  /// No description provided for @profile_unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get profile_unfollow;

  /// No description provided for @profile_noItemsToShow.
  ///
  /// In en, this message translates to:
  /// **'No items to show'**
  String get profile_noItemsToShow;

  /// No description provided for @wallet_selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select payment method'**
  String get wallet_selectPaymentMethod;

  /// No description provided for @wallet_searchSelectTargetId.
  ///
  /// In en, this message translates to:
  /// **'Please search and select a target ID'**
  String get wallet_searchSelectTargetId;

  /// No description provided for @inventory_cars.
  ///
  /// In en, this message translates to:
  /// **'Cars'**
  String get inventory_cars;

  /// No description provided for @inventory_entrance.
  ///
  /// In en, this message translates to:
  /// **'Entrance'**
  String get inventory_entrance;

  /// No description provided for @inventory_medals.
  ///
  /// In en, this message translates to:
  /// **'Medals'**
  String get inventory_medals;

  /// No description provided for @inventory_equippedOk.
  ///
  /// In en, this message translates to:
  /// **'Equipped successfully'**
  String get inventory_equippedOk;

  /// No description provided for @level_experienceRequirements.
  ///
  /// In en, this message translates to:
  /// **'Level Experience Requirements'**
  String get level_experienceRequirements;

  /// No description provided for @level_privileges.
  ///
  /// In en, this message translates to:
  /// **'Privileges of Levels'**
  String get level_privileges;

  /// No description provided for @level_comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get level_comingSoon;

  /// No description provided for @reseller_transferSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Transfer Successful'**
  String get reseller_transferSuccessful;

  /// No description provided for @reseller_approveBill.
  ///
  /// In en, this message translates to:
  /// **'Approve bill?'**
  String get reseller_approveBill;

  /// No description provided for @reseller_approvedWaiting.
  ///
  /// In en, this message translates to:
  /// **'Approved · Waiting for admin'**
  String get reseller_approvedWaiting;

  /// No description provided for @app_hostApplication.
  ///
  /// In en, this message translates to:
  /// **'Host Application'**
  String get app_hostApplication;

  /// No description provided for @app_realName.
  ///
  /// In en, this message translates to:
  /// **'Real Name'**
  String get app_realName;

  /// No description provided for @app_whatsappNumber.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Number'**
  String get app_whatsappNumber;

  /// No description provided for @agency_createAgency.
  ///
  /// In en, this message translates to:
  /// **'Create Agency'**
  String get agency_createAgency;

  /// No description provided for @agency_removeStaff.
  ///
  /// In en, this message translates to:
  /// **'Remove staff?'**
  String get agency_removeStaff;

  /// No description provided for @agency_makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin?'**
  String get agency_makeAdmin;

  /// No description provided for @agency_removeFromAgency.
  ///
  /// In en, this message translates to:
  /// **'Remove from Agency?'**
  String get agency_removeFromAgency;

  /// No description provided for @agency_joinRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Join request sent successfully!'**
  String get agency_joinRequestSent;

  /// No description provided for @agency_earningsTrend.
  ///
  /// In en, this message translates to:
  /// **'Earnings trend'**
  String get agency_earningsTrend;

  /// No description provided for @agency_topHosts.
  ///
  /// In en, this message translates to:
  /// **'Top hosts'**
  String get agency_topHosts;

  /// No description provided for @agency_basicSalary.
  ///
  /// In en, this message translates to:
  /// **'Basic Salary'**
  String get agency_basicSalary;

  /// No description provided for @agency_commission.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get agency_commission;

  /// No description provided for @bd_newBdCommission.
  ///
  /// In en, this message translates to:
  /// **'New BD Commission'**
  String get bd_newBdCommission;

  /// No description provided for @realName_telephone.
  ///
  /// In en, this message translates to:
  /// **'Telephone number'**
  String get realName_telephone;

  /// No description provided for @realName_whatsapp.
  ///
  /// In en, this message translates to:
  /// **'Whatsapp'**
  String get realName_whatsapp;

  /// No description provided for @realName_workProofScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Screenshot proof of work account'**
  String get realName_workProofScreenshot;

  /// No description provided for @family_createTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Family'**
  String get family_createTitle;

  /// No description provided for @family_enterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a family name'**
  String get family_enterName;

  /// No description provided for @family_setLeader.
  ///
  /// In en, this message translates to:
  /// **'Set as Leader'**
  String get family_setLeader;

  /// No description provided for @family_removeFromFamily.
  ///
  /// In en, this message translates to:
  /// **'Remove from Family'**
  String get family_removeFromFamily;

  /// No description provided for @family_experienceRequirements.
  ///
  /// In en, this message translates to:
  /// **'Family Experience Requirements'**
  String get family_experienceRequirements;

  /// No description provided for @family_levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Family Lv.{level}'**
  String family_levelLabel(int level);

  /// No description provided for @social_pickMoment.
  ///
  /// In en, this message translates to:
  /// **'Pick a beautiful moment…'**
  String get social_pickMoment;

  /// No description provided for @social_postShared.
  ///
  /// In en, this message translates to:
  /// **'Post shared successfully!'**
  String get social_postShared;

  /// No description provided for @social_postDetails.
  ///
  /// In en, this message translates to:
  /// **'Post Details'**
  String get social_postDetails;

  /// No description provided for @social_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get social_justNow;

  /// No description provided for @social_comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get social_comments;

  /// No description provided for @cp_proposalsTitle.
  ///
  /// In en, this message translates to:
  /// **'CP Proposals'**
  String get cp_proposalsTitle;

  /// No description provided for @cp_noPending.
  ///
  /// In en, this message translates to:
  /// **'No pending proposals'**
  String get cp_noPending;

  /// No description provided for @cp_accept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get cp_accept;

  /// No description provided for @cp_reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get cp_reject;

  /// No description provided for @cp_breakUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Break Up?'**
  String get cp_breakUpTitle;

  /// No description provided for @shop_sendGiftFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to send gift!'**
  String get shop_sendGiftFailed;

  /// No description provided for @shop_purchaseNow.
  ///
  /// In en, this message translates to:
  /// **'Purchase Now'**
  String get shop_purchaseNow;

  /// No description provided for @invite_codeCopied.
  ///
  /// In en, this message translates to:
  /// **'Invitation code copied'**
  String get invite_codeCopied;

  /// No description provided for @invite_rules.
  ///
  /// In en, this message translates to:
  /// **'Rules'**
  String get invite_rules;

  /// No description provided for @invite_records.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get invite_records;

  /// No description provided for @invite_noDraws.
  ///
  /// In en, this message translates to:
  /// **'No draws yet'**
  String get invite_noDraws;

  /// No description provided for @signin_dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Sign-in'**
  String get signin_dailyTitle;

  /// No description provided for @signin_winBig.
  ///
  /// In en, this message translates to:
  /// **'Sign to win big rewards'**
  String get signin_winBig;

  /// No description provided for @auth_enterId.
  ///
  /// In en, this message translates to:
  /// **'Please enter your ID'**
  String get auth_enterId;

  /// No description provided for @auth_loginWithCode.
  ///
  /// In en, this message translates to:
  /// **'Login with verification code'**
  String get auth_loginWithCode;

  /// No description provided for @auth_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get auth_forgotPassword;

  /// No description provided for @auth_checkEmailConfirm.
  ///
  /// In en, this message translates to:
  /// **'Check your email to confirm'**
  String get auth_checkEmailConfirm;

  /// No description provided for @auth_deviceSuspended.
  ///
  /// In en, this message translates to:
  /// **'Device Suspended'**
  String get auth_deviceSuspended;

  /// No description provided for @auth_accountSuspended.
  ///
  /// In en, this message translates to:
  /// **'Account Suspended'**
  String get auth_accountSuspended;

  /// No description provided for @auth_signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get auth_signOut;

  /// No description provided for @auth_adminNote.
  ///
  /// In en, this message translates to:
  /// **'Admin note'**
  String get auth_adminNote;

  /// No description provided for @splash_tagline.
  ///
  /// In en, this message translates to:
  /// **'Connect • Play • Shine'**
  String get splash_tagline;

  /// No description provided for @game_confirmParticipation.
  ///
  /// In en, this message translates to:
  /// **'Confirm participation'**
  String get game_confirmParticipation;

  /// No description provided for @game_participationConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Participation confirmed!'**
  String get game_participationConfirmed;

  /// No description provided for @ranking_todaysTopRoom.
  ///
  /// In en, this message translates to:
  /// **'Today’s #1 Room'**
  String get ranking_todaysTopRoom;

  /// No description provided for @ranking_enterRoom.
  ///
  /// In en, this message translates to:
  /// **'Enter Room'**
  String get ranking_enterRoom;

  /// No description provided for @ranking_maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get ranking_maybeLater;

  /// No description provided for @event_period.
  ///
  /// In en, this message translates to:
  /// **'Event Period'**
  String get event_period;

  /// No description provided for @event_coreGameplay.
  ///
  /// In en, this message translates to:
  /// **'Core Gameplay & Points'**
  String get event_coreGameplay;

  /// No description provided for @event_duringWindow.
  ///
  /// In en, this message translates to:
  /// **'During the event window'**
  String get event_duringWindow;

  /// No description provided for @event_shiningStarLastWeek.
  ///
  /// In en, this message translates to:
  /// **'Shining Star of Last week'**
  String get event_shiningStarLastWeek;

  /// No description provided for @event_lastWeekList.
  ///
  /// In en, this message translates to:
  /// **'Last Week List'**
  String get event_lastWeekList;

  /// No description provided for @event_skHostParty.
  ///
  /// In en, this message translates to:
  /// **'Livo Host Party'**
  String get event_skHostParty;

  /// No description provided for @event_noRewardLastPeriod.
  ///
  /// In en, this message translates to:
  /// **'No reward available for the last activity period.'**
  String get event_noRewardLastPeriod;

  /// No description provided for @home_noRankedRoom.
  ///
  /// In en, this message translates to:
  /// **'No ranked room available right now'**
  String get home_noRankedRoom;

  /// No description provided for @profile_inviteFriend.
  ///
  /// In en, this message translates to:
  /// **'Invite Friend'**
  String get profile_inviteFriend;

  /// No description provided for @profile_blacklist.
  ///
  /// In en, this message translates to:
  /// **'Blacklist'**
  String get profile_blacklist;

  /// No description provided for @profile_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profile_settings;

  /// No description provided for @blacklist_chatTab.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get blacklist_chatTab;

  /// No description provided for @blacklist_roomTab.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get blacklist_roomTab;

  /// No description provided for @blacklist_emptyChat.
  ///
  /// In en, this message translates to:
  /// **'No blocked chats'**
  String get blacklist_emptyChat;

  /// No description provided for @blacklist_emptyRoom.
  ///
  /// In en, this message translates to:
  /// **'No room kick records'**
  String get blacklist_emptyRoom;

  /// No description provided for @blacklist_unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get blacklist_unblock;

  /// No description provided for @blacklist_unblocked.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get blacklist_unblocked;

  /// No description provided for @blacklist_noRoom.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have a room yet'**
  String get blacklist_noRoom;

  /// No description provided for @chat_blockedCannotMessage.
  ///
  /// In en, this message translates to:
  /// **'You cannot send or receive messages in this chat.'**
  String get chat_blockedCannotMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'en',
    'hi',
    'id',
    'pt',
    'th',
    'tr',
    'ur',
    'vi',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'id':
      return AppLocalizationsId();
    case 'pt':
      return AppLocalizationsPt();
    case 'th':
      return AppLocalizationsTh();
    case 'tr':
      return AppLocalizationsTr();
    case 'ur':
      return AppLocalizationsUr();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
