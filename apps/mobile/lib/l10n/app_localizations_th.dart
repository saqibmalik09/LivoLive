// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Thai (`th`).
class AppLocalizationsTh extends AppLocalizations {
  AppLocalizationsTh([String locale = 'th']) : super(locale);

  @override
  String get lang_title => 'ภาษา';

  @override
  String get lang_english => 'English';

  @override
  String get lang_arabic => 'العربية';

  @override
  String get lang_indonesian => 'Bahasa Indonesia';

  @override
  String get lang_turkish => 'Türkçe';

  @override
  String get lang_urdu => 'اردو';

  @override
  String get lang_hindi => 'हिन्दी';

  @override
  String get lang_portuguese => 'Português';

  @override
  String get lang_thai => 'ไทย';

  @override
  String get lang_vietnamese => 'Tiếng Việt';

  @override
  String get lang_subtitle_en => 'ภาษาอังกฤษ';

  @override
  String get lang_subtitle_ar => 'ภาษาอาหรับ';

  @override
  String get lang_subtitle_id => 'ชาวอินโดนีเซีย';

  @override
  String get lang_subtitle_tr => 'ภาษาตุรกี';

  @override
  String get lang_subtitle_ur => 'ภาษาอูรดู';

  @override
  String get lang_subtitle_hi => 'ฮินดี';

  @override
  String get lang_subtitle_pt => 'โปรตุเกส';

  @override
  String get lang_subtitle_th => 'แบบไทย';

  @override
  String get lang_subtitle_vi => 'ภาษาเวียดนาม';

  @override
  String get lang_changed => 'อัปเดตภาษาแล้ว';

  @override
  String get common_cancel => 'ยกเลิก';

  @override
  String get common_ok => 'ตกลง';

  @override
  String get common_close => 'ปิด';

  @override
  String get common_search => 'ค้นหา';

  @override
  String get common_more => 'มากกว่า';

  @override
  String get common_edit => 'แก้ไข';

  @override
  String get common_create => 'สร้าง';

  @override
  String get common_user => 'ผู้ใช้';

  @override
  String get common_room => 'ห้อง';

  @override
  String get common_loading => 'กำลังโหลด...';

  @override
  String get common_done => 'เสร็จแล้ว';

  @override
  String get common_failed => 'ล้มเหลว';

  @override
  String get common_retry => 'ลองอีกครั้ง';

  @override
  String get common_save => 'บันทึก';

  @override
  String get common_submit => 'ส่ง';

  @override
  String get common_confirm => 'ยืนยัน';

  @override
  String get common_leave => 'ออกจาก';

  @override
  String get common_claim => 'เรียกร้อง';

  @override
  String get common_claimed => 'อ้างสิทธิ์';

  @override
  String get nav_home => 'บ้าน';

  @override
  String get nav_party => 'งานสังสรรค์';

  @override
  String get nav_game => 'เกม';

  @override
  String get nav_message => 'ข้อความ';

  @override
  String get nav_my => 'ของฉัน';

  @override
  String get nav_tabFallback => 'แท็บ';

  @override
  String get nav_roomOffline => 'ห้องออฟไลน์อยู่ในขณะนี้';

  @override
  String get profile_language => 'ภาษา';

  @override
  String get profile_followers => 'ผู้ติดตาม';

  @override
  String get profile_following => 'กำลังติดตาม';

  @override
  String get profile_friends => 'เพื่อน';

  @override
  String get profile_visits => 'การเข้าชม';

  @override
  String get profile_store => 'เก็บ';

  @override
  String get profile_level => 'ระดับ';

  @override
  String get profile_vip => 'วีไอพี';

  @override
  String get profile_decoration => 'การตกแต่ง';

  @override
  String get profile_events => 'กิจกรรม';

  @override
  String get profile_wallet => 'กระเป๋าสตางค์';

  @override
  String get profile_hostCenter => 'ศูนย์เจ้าภาพ';

  @override
  String get profile_roomReward => 'รางวัลห้องพัก';

  @override
  String get profile_micReward => 'รางวัลไมค์';

  @override
  String get profile_agency => 'เอเจนซี่';

  @override
  String get profile_invite => 'เชิญ';

  @override
  String get profile_getVip => 'รับวีไอพี';

  @override
  String get profile_upgrade => 'อัพเกรด';

  @override
  String profile_vipLevel(int level) {
    return 'วีไอพี $level';
  }

  @override
  String get profile_wealthCharmLevels => 'ระดับความมั่งคั่งและเสน่ห์';

  @override
  String get profile_agencyLevel => 'ระดับหน่วยงาน';

  @override
  String get profile_roomLevel => 'ระดับห้องพัก';

  @override
  String get profile_task => 'งาน';

  @override
  String get profile_feedback => 'ข้อเสนอแนะ';

  @override
  String get profile_realNameVerify => 'ยืนยันชื่อจริง';

  @override
  String get profile_cpNest => 'ซีพี เนสท์';

  @override
  String get profile_buddies => 'เพื่อน';

  @override
  String get profile_resellerPanel => 'แผงตัวแทนจำหน่าย';

  @override
  String get profile_merchantPanel => 'แผงผู้ค้า';

  @override
  String get profile_accountManagement => 'การจัดการบัญชี';

  @override
  String profile_staffCenter(String role) {
    return '$role ศูนย์';
  }

  @override
  String get profile_roleSuperAdmin => 'ผู้ดูแลระบบขั้นสูง';

  @override
  String get profile_roleCountyAdmin => 'ผู้บริหารเทศมณฑล';

  @override
  String get profile_roleAssistant => 'ผู้ช่วย';

  @override
  String get profile_roleCustomerService => 'บริการลูกค้า';

  @override
  String get profile_roleStaff => 'พนักงาน';

  @override
  String get profile_fallbackUser => 'ผู้ใช้';

  @override
  String get profile_idCopied => 'คัดลอกรหัสแล้ว';

  @override
  String get auth_continueWithGoogle => 'ดำเนินการต่อด้วย Google';

  @override
  String get auth_agreePrefix => 'การใช้แอพของเราแสดงว่าคุณเห็นด้วยกับเรา';

  @override
  String get auth_termsOfService => 'ข้อกำหนดในการให้บริการ';

  @override
  String get auth_and => 'และ';

  @override
  String get auth_privacyPolicy => 'นโยบายความเป็นส่วนตัว';

  @override
  String get auth_acceptTermsSnack =>
      'โปรดยอมรับข้อกำหนดในการให้บริการและนโยบายความเป็นส่วนตัว';

  @override
  String get auth_verifyPhoneTitle => 'ยืนยันโทรศัพท์';

  @override
  String get auth_codeSentTo => 'ได้ส่งรหัสไปที่';

  @override
  String get auth_verifyAndProceed => 'ตรวจสอบและดำเนินการ';

  @override
  String get auth_resendCode => 'ส่งรหัสอีกครั้ง';

  @override
  String get auth_verificationSuccessful => 'การยืนยันสำเร็จ!';

  @override
  String get auth_completeProfileTitle => 'กรอกโปรไฟล์ของคุณให้สมบูรณ์';

  @override
  String get auth_selectGender => 'เลือกเพศของคุณ';

  @override
  String get auth_genderMale => 'ชาย';

  @override
  String get auth_genderFemale => 'หญิง';

  @override
  String get auth_nickname => 'ชื่อเล่น';

  @override
  String get auth_hintEnter => 'เข้า';

  @override
  String get auth_basicInformation => 'ข้อมูลพื้นฐาน';

  @override
  String get auth_dateOfBirth => 'วันเกิด';

  @override
  String get auth_countryRegion => 'ประเทศ/ภูมิภาค';

  @override
  String get auth_select => 'เลือก';

  @override
  String get auth_invitationCodeOptional => 'รหัสคำเชิญ (ไม่บังคับ)';

  @override
  String get auth_friendShortIdHint => 'รหัสสั้นของเพื่อน';

  @override
  String get auth_go => 'ไป';

  @override
  String get auth_searchCountryHint => 'ค้นหาประเทศ...';

  @override
  String get auth_fillRequiredFields =>
      'กรุณากรอกข้อมูลในช่องที่ต้องกรอกทั้งหมด';

  @override
  String get auth_chooseAvailableNickname => 'โปรดเลือกชื่อเล่นที่มีอยู่';

  @override
  String get auth_invitationBonusApplied => 'ใช้โบนัสคำเชิญแล้ว!';

  @override
  String get auth_failedUpdateProfile => 'ไม่สามารถอัปเดตโปรไฟล์ได้';

  @override
  String get auth_accountManagementTitle => 'การจัดการบัญชี';

  @override
  String get auth_sectionAccountBinding => 'การผูกบัญชี';

  @override
  String get auth_sectionAccountManagement => 'การจัดการบัญชี';

  @override
  String get auth_sectionOther => 'อื่น';

  @override
  String get auth_google => 'Google';

  @override
  String get auth_email => 'อีเมล';

  @override
  String get auth_notBound => 'ไม่ผูกมัด';

  @override
  String get auth_setPassword => 'ตั้งรหัสผ่าน';

  @override
  String get auth_accountCancellation => 'การยกเลิกบัญชี';

  @override
  String get auth_aboutSkLive => 'เกี่ยวกับ LIVO';

  @override
  String get auth_aboutBlurb =>
      'ชุมชนเสียงโซเชียลระดับพรีเมียมพร้อมห้องเสียง การให้ของขวัญ และอื่นๆ อีกมากมาย';

  @override
  String get auth_logout => 'ออกจากระบบ';

  @override
  String get auth_logoutConfirm => 'คุณแน่ใจหรือไม่ว่าต้องการออกจากระบบ?';

  @override
  String get auth_requestCancellation => 'ขอยกเลิก';

  @override
  String get auth_cancellationBody =>
      'นี่จะเป็นการส่งคำขอยกเลิก การเข้าถึงบัญชีของคุณจะสิ้นสุดลงหลังจากการตรวจสอบ สิ่งนี้ไม่สามารถยกเลิกได้ง่าย\n\nดำเนินการต่อ?';

  @override
  String get auth_cancellationSubmitted =>
      'ส่งคำขอยกเลิกแล้ว กำลังออกจากระบบ...';

  @override
  String get auth_bindEmailFirst => 'ไม่มีอีเมลในบัญชีนี้ ผูกอีเมลก่อน';

  @override
  String get auth_passwordUpdated => 'อัปเดตรหัสผ่านเรียบร้อยแล้ว';

  @override
  String get auth_newPassword => 'รหัสผ่านใหม่';

  @override
  String get auth_confirmPassword => 'ยืนยันรหัสผ่าน';

  @override
  String get auth_passwordMinLength => 'อย่างน้อย 6 ตัวอักษร';

  @override
  String get auth_passwordsDoNotMatch => 'รหัสผ่านไม่ตรงกัน';

  @override
  String get auth_savePassword => 'บันทึกรหัสผ่าน';

  @override
  String get auth_sendResetLinkInstead => 'ส่งลิงก์รีเซ็ตแทน';

  @override
  String get auth_passwordResetSent => 'ลิงก์รีเซ็ตรหัสผ่านส่งไปยังอีเมลของคุณ';

  @override
  String auth_versionLabel(String version) {
    return 'เวอร์ชัน $version';
  }

  @override
  String get wallet_title => 'กระเป๋าสตางค์';

  @override
  String get wallet_recordTooltip => 'บันทึกกระเป๋าเงิน';

  @override
  String get wallet_tabGoldCoins => 'เหรียญทอง';

  @override
  String get wallet_tabDiamonds => 'เพชร';

  @override
  String get wallet_tabBalance => 'สมดุล';

  @override
  String get wallet_coinBalance => 'ยอดเหรียญ';

  @override
  String get wallet_paymentUnavailable =>
      'ระบบการชำระเงินไม่พร้อมใช้งานบนอุปกรณ์นี้';

  @override
  String get wallet_rechargeIssuesPrefix => 'มีปัญหาในการชาร์จใช่ไหม?';

  @override
  String get wallet_contactUs => 'ติดต่อเรา';

  @override
  String get wallet_goldCoinReseller => 'ตัวแทนจำหน่ายเหรียญทอง';

  @override
  String get wallet_openResellerCenter =>
      'เปิดศูนย์ตัวแทนจำหน่าย · หุ้นและนโยบาย';

  @override
  String get wallet_exchangeGoldCoins => 'แลกเปลี่ยนเหรียญทอง';

  @override
  String get wallet_exchangeToSalary => 'แลกเป็นกระเป๋าสตางค์เงินเดือน';

  @override
  String get wallet_enterExchangeAmount => 'ป้อนจำนวนการแลกเปลี่ยน';

  @override
  String get wallet_maximum => 'สูงสุด';

  @override
  String get wallet_redeemablePrefix => 'แลกได้:';

  @override
  String get wallet_earnByParticipation => 'รับจากการเข้าร่วมหรือนั่งของขวัญ';

  @override
  String get wallet_diamond => 'เพชร';

  @override
  String get wallet_afterSalaryExchangePrefix => 'หลังจากแลกเงินเดือนได้แล้ว';

  @override
  String get wallet_exchangeForGoldCoins => 'แลกเหรียญทอง';

  @override
  String get wallet_inWalletAnytime => 'ในกระเป๋าสตางค์ได้ตลอดเวลา!';

  @override
  String get wallet_exchangeSuccessful => 'แลกเปลี่ยนสำเร็จ!';

  @override
  String get wallet_exchangeFailed => 'การแลกเปลี่ยนล้มเหลว';

  @override
  String get wallet_exchangeToOneself => 'แลกเปลี่ยนกับตัวเอง';

  @override
  String get wallet_exchangeToOther => 'แลกเปลี่ยนเป็นอย่างอื่น';

  @override
  String get wallet_goldCoinsExchange => 'การแลกเปลี่ยนเหรียญทอง';

  @override
  String get wallet_enterCoinsRedeemed => 'กรอกจำนวนเหรียญที่แลก';

  @override
  String get wallet_exchange => 'แลกเปลี่ยน';

  @override
  String get wallet_withdraw => 'ถอน';

  @override
  String get wallet_cashWallet => 'กระเป๋าเงิน';

  @override
  String get wallet_coinMerchants => 'พ่อค้าเหรียญ';

  @override
  String get wallet_buyFromResellers => 'ซื้อเหรียญจากผู้ค้าปลีกที่เชื่อถือได้';

  @override
  String get wallet_enterIdHint => 'กรุณากรอกรหัส';

  @override
  String get wallet_noUserFound => 'ไม่พบผู้ใช้';

  @override
  String get wallet_enterValidAmount => 'ป้อนจำนวนเงินที่ถูกต้อง';

  @override
  String get wallet_insufficientCash => 'ยอดเงินคงเหลือไม่เพียงพอ';

  @override
  String get wallet_selectRecipient => 'เลือกผู้รับ';

  @override
  String wallet_rechargeSuccess(String coins) {
    return 'ชาร์จ $coins เหรียญสำเร็จแล้ว!';
  }

  @override
  String get messages_tabMessage => 'ข้อความ';

  @override
  String get messages_tabContacts => 'รายชื่อผู้ติดต่อ';

  @override
  String get messages_searchFriendsHint => 'ค้นหาเพื่อน...';

  @override
  String get messages_pleaseSignIn => 'กรุณาเข้าสู่ระบบ';

  @override
  String get messages_noContent => 'ไม่มีเนื้อหา';

  @override
  String get messages_noMessagesYet => 'ยังไม่มีข้อความ';

  @override
  String messages_noUsersFound(String query) {
    return 'ไม่พบผู้ใช้สำหรับ \"$query\"';
  }

  @override
  String messages_inRoom(String title) {
    return 'ในห้อง: $title';
  }

  @override
  String messages_friendCount(int count) {
    return 'เพื่อน $count';
  }

  @override
  String messages_followingCount(int count) {
    return 'กำลังติดตาม $count';
  }

  @override
  String messages_fansCount(int count) {
    return 'แฟนๆ $count';
  }

  @override
  String get feedback_title => 'ข้อเสนอแนะ';

  @override
  String get feedback_contactDetails => 'รายละเอียดการติดต่อ';

  @override
  String get feedback_contactHint => 'โทรศัพท์ อีเมล หรือ WhatsApp';

  @override
  String get feedback_message => 'ข้อความ';

  @override
  String get feedback_required => 'ที่จำเป็น';

  @override
  String get feedback_submit => 'ส่ง';

  @override
  String get feedback_sentThanks => 'ส่งคำติชมแล้ว ขอบคุณ!';

  @override
  String get party_mineTitle => 'ของฉัน';

  @override
  String get party_tabHot => 'ร้อน';

  @override
  String get party_tabRoom => 'ห้อง';

  @override
  String get party_tabEvent => 'กิจกรรม';

  @override
  String get profile_coin => 'เหรียญ';

  @override
  String get home_selectCountry => 'เลือกประเทศ';

  @override
  String get home_regionMiddleEast => 'ตะวันออกกลาง';

  @override
  String get home_regionAsia => 'เอเชีย';

  @override
  String get home_regionAmerica => 'อเมริกา';

  @override
  String get home_regionEurope => 'ยุโรป';

  @override
  String get home_regionAfrica => 'แอฟริกา';

  @override
  String get party_tooltipRanking => 'การจัดอันดับ';

  @override
  String get party_tooltipSearch => 'ค้นหา';

  @override
  String get party_tooltipMyRoom => 'ห้องของฉัน';

  @override
  String get party_searchHint => 'ชื่อห้อง รหัสห้อง หรือชื่อผู้ใช้...';

  @override
  String get party_typeRoomNameOrId => 'พิมพ์ชื่อห้องหรือรหัสห้อง';

  @override
  String get party_typeUsernameOrUid => 'พิมพ์ชื่อผู้ใช้หรือ UID';

  @override
  String party_noRoomFound(String query) {
    return 'ไม่พบห้องสำหรับ \"$query\"';
  }

  @override
  String party_noUserFound(String query) {
    return 'ไม่พบผู้ใช้สำหรับ \"$query\"';
  }

  @override
  String get party_myRoom => 'ห้องของฉัน';

  @override
  String get party_roomLevelBadges => 'ระดับห้องและป้าย';

  @override
  String get party_recents => 'ล่าสุด';

  @override
  String get party_myFollowings => 'การติดตามของฉัน';

  @override
  String get party_managedRooms => 'ห้องที่ได้รับการจัดการ';

  @override
  String get party_emptyRecents => 'ไม่มีห้องที่เข้าเยี่ยมชมล่าสุด';

  @override
  String get party_emptyFollowings => 'ยังไม่มีห้องต่อไปนี้';

  @override
  String get party_noRoomsFromCountry => 'ไม่พบห้องจากประเทศนี้';

  @override
  String get party_countriesRegion => 'ประเทศ/ภูมิภาค';

  @override
  String get party_pullToRefresh => 'มีบางอย่างผิดพลาด ดึงเพื่อรีเฟรช';

  @override
  String get party_couldNotOpenRoom => 'ไม่สามารถเปิดห้องของคุณได้';

  @override
  String get party_alreadyHaveRoom => 'คุณมีห้องแล้ว';

  @override
  String get party_roomNotFoundOffline => 'ไม่พบห้องหรือออฟไลน์';

  @override
  String get party_unknownHost => 'โฮสต์ที่ไม่รู้จัก';

  @override
  String get party_defaultBio => 'ฉันหวังว่าคุณจะมีวันที่มีความสุข';

  @override
  String get party_searchCountry => 'ค้นหาประเทศ...';

  @override
  String get shop_title => 'ร้านค้า';

  @override
  String get shop_mine => 'ของฉัน';

  @override
  String get shop_noItems => 'ไม่พบรายการ';

  @override
  String get shop_purchase => 'ซื้อ';

  @override
  String get shop_send => 'ส่ง';

  @override
  String get shop_sendGiftTo => 'ส่งของขวัญไปที่';

  @override
  String get shop_noUsers => 'ไม่พบผู้ใช้';

  @override
  String get shop_notForSale => 'ไม่ขาย';

  @override
  String get shop_medal => 'เหรียญ';

  @override
  String get shop_medalOnly => 'เหรียญเท่านั้น';

  @override
  String get shop_locked => 'ล็อคแล้ว';

  @override
  String shop_vipLevelBadge(int level) {
    return 'วีไอพี เลเวล$level';
  }

  @override
  String get shop_insufficientCoins => 'เหรียญไม่พอ!';

  @override
  String get shop_purchasedSuccessfully => 'ซื้อสำเร็จแล้ว!';

  @override
  String get shop_purchaseFailed => 'การซื้อล้มเหลว!';

  @override
  String get shop_preview => 'ดูตัวอย่าง';

  @override
  String get vip_centerTitle => 'วีไอพีเซ็นเตอร์';

  @override
  String get vip_unlocked => 'ปลดล็อคแล้ว';

  @override
  String get vip_locked => 'ล็อคแล้ว';

  @override
  String get vip_gotIt => 'เข้าใจแล้ว';

  @override
  String get vip_includedInLevel => 'รวมอยู่ในระดับวีไอพีนี้';

  @override
  String get vip_lockedForLevel => 'ล็อคไว้สำหรับระดับนี้';

  @override
  String get vip_noPlans => 'ไม่มีแผนวีไอพี';

  @override
  String get task_newbieTasks => 'งานมือใหม่';

  @override
  String get task_dailyTasks => 'งานประจำวัน';

  @override
  String get task_noDrawsLeft =>
      'ไม่มีการจับฉลากเหลืออยู่ เช็คอินหรืออ้างสิทธิ์งาน';

  @override
  String get task_checkinBonus => 'โบนัสเช็คอิน';

  @override
  String get task_checkIn => 'เช็คอิน';

  @override
  String get task_checkedIn => 'เช็คอินแล้ว';

  @override
  String get task_go => 'ไป';

  @override
  String get task_got => 'ได้รับ';

  @override
  String get task_claimFailed => 'การอ้างสิทธิ์ล้มเหลว';

  @override
  String get task_checkinFailed => 'การเช็คอินล้มเหลว';

  @override
  String get task_luckyWheel => 'วงล้อนำโชค';

  @override
  String get task_spinRecord => 'บันทึกการหมุน';

  @override
  String get task_record => 'บันทึก';

  @override
  String get reward_micTitle => 'รางวัลไมค์';

  @override
  String get reward_roomTitle => 'รางวัลห้องพัก';

  @override
  String get reward_rules => 'กฎ';

  @override
  String get reward_levels => 'ระดับ';

  @override
  String get reward_today => 'วันนี้';

  @override
  String get reward_thisWeek => 'สัปดาห์นี้';

  @override
  String get reward_stayUnmuted => 'เปิดเสียงไมโครโฟนเพื่อรับรายได้';

  @override
  String get reward_roomOwnerRewards => 'รางวัลเจ้าของห้อง';

  @override
  String get reward_yourRoomWeekly => 'ห้องของคุณ · เป้าหมายรายสัปดาห์';

  @override
  String get reward_claimedSuccessfully => 'อ้างสิทธิ์สำเร็จแล้ว';

  @override
  String get reward_claimFailed => 'การอ้างสิทธิ์ล้มเหลว';

  @override
  String get reward_noLevels => 'ไม่มีการกำหนดค่าระดับ';

  @override
  String get reward_allTiersUnlocked => 'วันนี้ปลดล็อคทุกระดับแล้ว';

  @override
  String get reward_lastWeekClaimed => 'สัปดาห์ที่แล้วอ้างสิทธิ์แล้ว';

  @override
  String get reward_assetReward => 'รางวัลสินทรัพย์';

  @override
  String get reward_noMicLevelsAdmin =>
      'ยังไม่มีระดับรางวัล ขอให้ผู้ดูแลระบบกำหนดค่า Mic Daily Rewards';

  @override
  String get reward_noRoomLevelsAdmin =>
      'ยังไม่มีระดับรางวัล ขอให้ผู้ดูแลระบบกำหนดค่ารางวัลห้อง';

  @override
  String get host_centerTitle => 'ศูนย์เจ้าภาพ';

  @override
  String get host_salaryHistory => 'ประวัติเงินเดือน';

  @override
  String get host_noSalaryPayouts => 'ยังไม่มีการจ่ายเงินเดือน';

  @override
  String get host_leaveAgency => 'ออกจากหน่วยงาน';

  @override
  String get host_leaveAgencyConfirmTitle => 'ออกจากเอเจนซี่?';

  @override
  String get host_leaveAgencyConfirmBody =>
      'คุณจะหยุดรับเพชรของขวัญจนกว่าคุณจะเข้าร่วมอีกครั้ง';

  @override
  String get host_periodCharm => 'เสน่ห์แห่งยุค';

  @override
  String get host_onMicHours => 'ชั่วโมงเปิดไมค์';

  @override
  String get host_validDays => 'วันที่ถูกต้อง';

  @override
  String get agency_title => 'เอเจนซี่';

  @override
  String get agency_recommended => 'เอเจนซี่แนะนำ';

  @override
  String get agency_searchHint => 'บัตรประจำตัวหรือชื่อ';

  @override
  String get agency_noAgencies => 'ไม่พบเอเจนซี่';

  @override
  String get agency_noMatching => 'ไม่มีหน่วยงานที่ตรงกัน';

  @override
  String get agency_welcomeJoin => 'ยินดีต้อนรับสู่การเข้าร่วมกับเรา';

  @override
  String get agency_centerTitle => 'ศูนย์ตัวแทน';

  @override
  String get contact_title => 'ติดต่อเรา';

  @override
  String get contact_previousTickets => 'ตั๋วก่อนหน้าของคุณ';

  @override
  String get contact_subject => 'เรื่อง';

  @override
  String get contact_message => 'ข้อความ';

  @override
  String get contact_enterSubject => 'ใส่หัวเรื่อง';

  @override
  String get contact_enterMessage => 'ใส่ข้อความ';

  @override
  String get contact_sendMessage => 'ส่งข้อความ';

  @override
  String get contact_attachmentOptional => 'เอกสารแนบ (ไม่บังคับ)';

  @override
  String get contact_tapUploadScreenshot => 'แตะเพื่ออัปโหลดภาพหน้าจอ';

  @override
  String get contact_noHistory => 'ไม่มีประวัติข้อความ';

  @override
  String get contact_replied => 'ตอบกลับ';

  @override
  String get contact_pending => 'รอดำเนินการ';

  @override
  String get contact_adminReply => 'แอดมินตอบ';

  @override
  String get contact_messageSent => 'ส่งข้อความแล้ว! เราจะตอบกลับเร็ว ๆ นี้';

  @override
  String get room_live => 'สด';

  @override
  String get room_members => 'สมาชิก';

  @override
  String get room_gifts => 'ของขวัญ';

  @override
  String get room_chat => 'แชท';

  @override
  String get room_mute => 'ปิดเสียง';

  @override
  String get room_unmute => 'เปิดเสียง';

  @override
  String get room_leaveMic => 'ทิ้งไมค์ไว้';

  @override
  String get room_takeMic => 'หยิบไมค์ขึ้นมา';

  @override
  String get room_invite => 'เชิญ';

  @override
  String get room_settings => 'การตั้งค่า';

  @override
  String get room_contribution => 'ผลงาน';

  @override
  String get room_luckyBag => 'กระเป๋านำโชค';

  @override
  String get room_pk => 'พีเค';

  @override
  String get room_teamPk => 'ทีมพีเค';

  @override
  String get inventory_title => 'รายการสิ่งของ';

  @override
  String get inventory_frames => 'เฟรม';

  @override
  String get inventory_empty => 'ยังไม่มีรายการ';

  @override
  String get events_title => 'กิจกรรม';

  @override
  String get invite_title => 'เชิญและรับ';

  @override
  String get cp_nestTitle => 'ซีพี เนสท์';

  @override
  String get buddies_title => 'เพื่อน';

  @override
  String get intimacy_title => 'ความใกล้ชิด';

  @override
  String get family_centerTitle => 'ศูนย์ครอบครัว';

  @override
  String get staff_centerTitle => 'ศูนย์บุคลากร';

  @override
  String get bd_centerTitle => 'บีดี เซ็นเตอร์';

  @override
  String get realName_title => 'ยืนยันชื่อจริง';

  @override
  String get realName_guidelines => 'แนวทาง';

  @override
  String get game_rupeeTitle => 'เกมรูปี';

  @override
  String get game_help => 'ช่วย';

  @override
  String get game_ranking => 'อันดับเกม';

  @override
  String get social_discover => 'ค้นพบ';

  @override
  String get social_createPost => 'สร้างโพสต์';

  @override
  String get edit_profileTitle => 'แก้ไขโปรไฟล์';

  @override
  String get level_wealthTitle => 'ระดับความมั่งคั่ง';

  @override
  String get level_charmTitle => 'ระดับเสน่ห์';

  @override
  String get level_userTitle => 'ระดับผู้ใช้';

  @override
  String get level_cpTitle => 'ระดับซีพี';

  @override
  String get level_roomTitle => 'ระดับห้องพัก';

  @override
  String get room_removeAdminTitle => 'ลบผู้ดูแลระบบใช่ไหม';

  @override
  String get room_removeAdminBody =>
      'คุณแน่ใจหรือไม่ว่าต้องการลบผู้ดูแลระบบรายนี้';

  @override
  String room_removedAsAdmin(String username) {
    return '$username ถูกลบออกจากการเป็นผู้ดูแลระบบ';
  }

  @override
  String get room_cannotModerateSuperAdmin =>
      'คุณไม่สามารถกลั่นกรองผู้ดูแลระบบขั้นสูงรายอื่นได้';

  @override
  String get room_kickDuration3h => '3 ชั่วโมง';

  @override
  String get room_kickDuration24h => '24 ชม';

  @override
  String get room_kickDurationPermanent => 'ถาวร';

  @override
  String get room_kickRejoin3h =>
      'สามารถเข้าร่วมได้อีกครั้งหลังจากผ่านไป 3 ชั่วโมง';

  @override
  String get room_kickRejoin24h =>
      'สามารถเข้าร่วมได้อีกครั้งหลังจากผ่านไป 24 ชั่วโมง';

  @override
  String get room_kickBannedUntilCleared => 'ถูกแบนจนกว่าจะเคลียร์ด้วยตนเอง';

  @override
  String room_couldNotKick(String error) {
    return 'ไม่สามารถเตะผู้ใช้: $error';
  }

  @override
  String room_couldNotOpenChat(String error) {
    return 'ไม่สามารถเปิดการแชทได้: $error';
  }

  @override
  String get room_noEmptySeat => 'ไม่มีที่นั่งว่าง';

  @override
  String get room_viewProfile => 'ดูโปรไฟล์';

  @override
  String get room_makeAdmin => 'ทำให้แอดมิน';

  @override
  String get room_removeAdmin => 'ลบผู้ดูแลระบบ';

  @override
  String get room_removeFromSeat => 'ถอดออกจากที่นั่ง';

  @override
  String get room_addToBlacklist => 'เพิ่มลงในบัญชีดำ';

  @override
  String get room_chatRestrictedAdmins =>
      'แชทจำกัดเฉพาะผู้ดูแลระบบและโฮสต์เท่านั้น';

  @override
  String get room_couldNotUploadPhoto => 'ไม่สามารถอัปโหลดรูปภาพได้';

  @override
  String get room_savingPhoto => 'กำลังบันทึกรูปภาพ...';

  @override
  String get room_couldNotSyncMic =>
      'ไม่สามารถซิงค์ไมโครโฟนได้ โปรดลองอีกครั้ง';

  @override
  String get room_minimize => 'ย่อเล็กสุด';

  @override
  String get room_close => 'ปิด';

  @override
  String room_couldNotStartYoutube(String error) {
    return 'ไม่สามารถเริ่ม YouTube สำหรับห้อง: $error';
  }

  @override
  String room_couldNotStopYoutube(String error) {
    return 'ไม่สามารถหยุด YouTube: $error';
  }

  @override
  String get room_seatLocked => 'ที่นั่งถูกล็อค';

  @override
  String get room_infoTitle => 'ข้อมูลห้องพัก';

  @override
  String get room_noRoomForAccount => 'ไม่พบห้องสำหรับบัญชีของคุณ';

  @override
  String get room_createMyRoom => 'สร้างห้องของฉัน';

  @override
  String get room_alreadyHaveRoom => 'คุณมีห้องแล้ว';

  @override
  String get room_cover => 'ผ้าคลุมห้อง';

  @override
  String get room_idCopied => 'คัดลอกรหัสห้องแล้ว!';

  @override
  String get room_name => 'ชื่อห้อง';

  @override
  String get room_topic => 'หัวข้อห้อง';

  @override
  String get room_levelLabel => 'ระดับห้อง';

  @override
  String get room_country => 'ประเทศห้อง';

  @override
  String get room_announcement => 'ประกาศเรื่องห้อง';

  @override
  String get room_decoration => 'การตกแต่งห้อง';

  @override
  String get room_clickToSet => 'คลิกเพื่อตั้งค่า';

  @override
  String get room_passwordSetTap => 'ตั้งรหัสผ่าน · แตะเพื่อเปลี่ยน';

  @override
  String get room_setPasswordHint => 'ตั้งรหัสผ่าน 4-6 หลักเพื่อล็อคห้อง';

  @override
  String get room_privateRoom => 'ห้องส่วนตัว (ระบบจะไม่แนะนำ)';

  @override
  String get room_showSpendingIcons =>
      'แสดงไอคอนการใช้จ่าย (เหรียญรายวันกับผู้ใช้ออนไลน์)';

  @override
  String get room_viewAll => 'ดูทั้งหมด';

  @override
  String get room_membershipTag => 'แท็กสมาชิก';

  @override
  String get room_lockPasswordRemoved => 'ลบรหัสผ่านล็อคห้องแล้ว';

  @override
  String get room_lockPasswordSaved =>
      'บันทึกรหัสผ่านล็อคห้องแล้ว — ห้องถูกล็อค';

  @override
  String room_editTitle(String title) {
    return 'แก้ไข $title';
  }

  @override
  String get room_passwordDigits => 'รหัสผ่านต้องเป็นตัวเลข 4-6 หลัก';

  @override
  String get room_lockPasswordTitle => 'รหัสผ่านล็อคห้อง';

  @override
  String get room_lockPasswordHelp =>
      'ตั้งรหัสผ่าน 4-6 หลัก ใช้เครื่องมือ → ล็อคห้องเพื่อล็อค/ปลดล็อค เว้นว่างไว้เพื่อนำออก';

  @override
  String get room_enterPassword => 'ใส่รหัสผ่าน';

  @override
  String get room_membersTitle => 'สมาชิก';

  @override
  String get room_membersAndAdmin => 'สมาชิก & เพิ่มผู้ดูแลระบบ';

  @override
  String get room_inviteSubAdmin => 'เชิญเป็นผู้ดูแลระบบย่อย';

  @override
  String get room_kickRecordsTitle => 'บันทึกการเตะออก';

  @override
  String get room_unblockUser => 'เลิกบล็อกผู้ใช้?';

  @override
  String get room_membersList => 'รายชื่อสมาชิก';

  @override
  String get room_luckyBagTitle => 'รูมลัคกี้แบ็ก';

  @override
  String get room_luckyBagValue => 'มูลค่าถุงโชคดี';

  @override
  String get room_sendGift => 'ส่งของขวัญ';

  @override
  String get room_insufficientCoins => 'เหรียญไม่เพียงพอ';

  @override
  String get room_applyDecoration => 'ใช้ตกแต่ง';

  @override
  String get room_shareToChat => 'แชร์เพื่อแชท';

  @override
  String get room_seatInvite => 'เชิญนั่งครับ';

  @override
  String get room_youtube => 'ยูทูบ';

  @override
  String get common_pullToRefresh => 'มีบางอย่างผิดพลาด ดึงเพื่อรีเฟรช';

  @override
  String get chat_conversationBlocked => 'การสนทนาถูกบล็อก';

  @override
  String get chat_reportUser => 'รายงานผู้ใช้';

  @override
  String get chat_offline => 'ออฟไลน์';

  @override
  String get chat_sentAGift => 'ส่งของขวัญแล้ว';

  @override
  String get chat_copied => 'คัดลอกแล้ว';

  @override
  String get chat_noGiftCategories => 'ไม่มีหมวดหมู่ของขวัญ';

  @override
  String get chat_insufficientBalance => 'ยอดคงเหลือไม่เพียงพอ!';

  @override
  String get chat_send => 'ส่ง';

  @override
  String get chat_markAllRead => 'ทำเครื่องหมายว่าอ่านแล้วทั้งหมด';

  @override
  String get chat_couldNotMarkRead =>
      'ไม่สามารถทำเครื่องหมายการแจ้งเตือนว่าอ่านแล้ว';

  @override
  String get chat_notice => 'สังเกต';

  @override
  String get chat_activity => 'กิจกรรม';

  @override
  String get chat_feedback => 'ข้อเสนอแนะ';

  @override
  String get party_couldNotOpenRoomGeneric => 'ไม่สามารถเปิดห้องได้';

  @override
  String get party_eventNotFound => 'ไม่พบกิจกรรม';

  @override
  String get edit_nameUpdated => 'อัปเดตชื่อแล้ว';

  @override
  String get edit_male => 'ชาย';

  @override
  String get edit_female => 'หญิง';

  @override
  String get edit_dobUpdated => 'วันเกิดอัพเดทแล้ว';

  @override
  String get profile_follow => 'ติดตาม';

  @override
  String get profile_unfollow => 'เลิกติดตาม';

  @override
  String get profile_noItemsToShow => 'ไม่มีรายการที่จะแสดง';

  @override
  String get wallet_selectPaymentMethod => 'เลือกวิธีการชำระเงิน';

  @override
  String get wallet_searchSelectTargetId => 'กรุณาค้นหาและเลือกรหัสเป้าหมาย';

  @override
  String get inventory_cars => 'รถยนต์';

  @override
  String get inventory_entrance => 'ทางเข้า';

  @override
  String get inventory_medals => 'เหรียญรางวัล';

  @override
  String get inventory_equippedOk => 'ติดตั้งเรียบร้อยแล้ว';

  @override
  String get level_experienceRequirements => 'ข้อกำหนดประสบการณ์ระดับ';

  @override
  String get level_privileges => 'สิทธิพิเศษของระดับ';

  @override
  String get level_comingSoon => 'เร็วๆ นี้';

  @override
  String get reseller_transferSuccessful => 'โอนสำเร็จ';

  @override
  String get reseller_approveBill => 'อนุมัติบิล?';

  @override
  String get reseller_approvedWaiting => 'อนุมัติแล้ว · กำลังรอผู้ดูแลระบบ';

  @override
  String get app_hostApplication => 'แอปพลิเคชันโฮสต์';

  @override
  String get app_realName => 'ชื่อจริง';

  @override
  String get app_whatsappNumber => 'หมายเลข WhatsApp';

  @override
  String get agency_createAgency => 'สร้างเอเจนซี่';

  @override
  String get agency_removeStaff => 'ถอดพนักงาน?';

  @override
  String get agency_makeAdmin => 'ทำให้ผู้ดูแลระบบ?';

  @override
  String get agency_removeFromAgency => 'ลบออกจากเอเจนซี่ใช่ไหม';

  @override
  String get agency_joinRequestSent => 'ส่งคำขอเข้าร่วมเรียบร้อยแล้ว!';

  @override
  String get agency_earningsTrend => 'แนวโน้มกำไร';

  @override
  String get agency_topHosts => 'เจ้าภาพชั้นนำ';

  @override
  String get agency_basicSalary => 'เงินเดือนพื้นฐาน';

  @override
  String get agency_commission => 'คณะกรรมการ';

  @override
  String get bd_newBdCommission => 'คณะกรรมการ BD ใหม่';

  @override
  String get realName_telephone => 'หมายเลขโทรศัพท์';

  @override
  String get realName_whatsapp => 'วอทส์แอพพ์';

  @override
  String get realName_workProofScreenshot => 'ภาพหน้าจอหลักฐานบัญชีงาน';

  @override
  String get family_createTitle => 'สร้างครอบครัว';

  @override
  String get family_enterName => 'กรุณากรอกนามสกุล';

  @override
  String get family_setLeader => 'ตั้งเป็นผู้นำ';

  @override
  String get family_removeFromFamily => 'ลบออกจากครอบครัว';

  @override
  String get family_experienceRequirements => 'ข้อกำหนดประสบการณ์ครอบครัว';

  @override
  String family_levelLabel(int level) {
    return 'ครอบครัว เลเวล$level';
  }

  @override
  String get social_pickMoment => 'เลือกช่วงเวลาที่สวยงาม...';

  @override
  String get social_postShared => 'แชร์โพสต์สำเร็จ!';

  @override
  String get social_postDetails => 'รายละเอียดการโพสต์';

  @override
  String get social_justNow => 'แค่ตอนนี้';

  @override
  String get social_comments => 'ความคิดเห็น';

  @override
  String get cp_proposalsTitle => 'ข้อเสนอของซีพี';

  @override
  String get cp_noPending => 'ไม่มีข้อเสนอที่รอดำเนินการ';

  @override
  String get cp_accept => 'ยอมรับ';

  @override
  String get cp_reject => 'ปฏิเสธ';

  @override
  String get cp_breakUpTitle => 'เลิกกัน?';

  @override
  String get shop_sendGiftFailed => 'ไม่สามารถส่งของขวัญได้!';

  @override
  String get shop_purchaseNow => 'ซื้อเลย';

  @override
  String get invite_codeCopied => 'คัดลอกรหัสคำเชิญแล้ว';

  @override
  String get invite_rules => 'กฎ';

  @override
  String get invite_records => 'บันทึก';

  @override
  String get invite_noDraws => 'ยังไม่มีการจับสลาก';

  @override
  String get signin_dailyTitle => 'เข้าสู่ระบบรายวัน';

  @override
  String get signin_winBig => 'ลงชื่อเข้าใช้เพื่อรับรางวัลใหญ่';

  @override
  String get auth_enterId => 'กรุณากรอกรหัสประจำตัวของคุณ';

  @override
  String get auth_loginWithCode => 'เข้าสู่ระบบด้วยรหัสยืนยัน';

  @override
  String get auth_forgotPassword => 'ลืมรหัสผ่าน?';

  @override
  String get auth_checkEmailConfirm => 'ตรวจสอบอีเมลของคุณเพื่อยืนยัน';

  @override
  String get auth_deviceSuspended => 'อุปกรณ์ถูกระงับ';

  @override
  String get auth_accountSuspended => 'บัญชีถูกระงับ';

  @override
  String get auth_signOut => 'ออกจากระบบ';

  @override
  String get auth_adminNote => 'หมายเหตุผู้ดูแลระบบ';

  @override
  String get splash_tagline => 'เชื่อมต่อ • เล่น • เปล่งประกาย';

  @override
  String get game_confirmParticipation => 'ยืนยันการเข้าร่วม';

  @override
  String get game_participationConfirmed => 'ยืนยันการเข้าร่วมแล้ว!';

  @override
  String get ranking_todaysTopRoom => 'ห้องที่ 1 ของวันนี้';

  @override
  String get ranking_enterRoom => 'เข้าห้อง';

  @override
  String get ranking_maybeLater => 'อาจจะในภายหลัง';

  @override
  String get event_period => 'ระยะเวลากิจกรรม';

  @override
  String get event_coreGameplay => 'การเล่นเกมหลักและคะแนน';

  @override
  String get event_duringWindow => 'ในช่วงหน้าต่างกิจกรรม';

  @override
  String get event_shiningStarLastWeek => 'Shining Star ของสัปดาห์ที่แล้ว';

  @override
  String get event_lastWeekList => 'รายการสัปดาห์ที่แล้ว';

  @override
  String get event_skHostParty => 'Livo โฮสต์ปาร์ตี้';

  @override
  String get event_noRewardLastPeriod => 'ไม่มีรางวัลสำหรับช่วงกิจกรรมสุดท้าย';

  @override
  String get home_noRankedRoom => 'ไม่มีห้องจัดอันดับว่างในขณะนี้';

  @override
  String get profile_inviteFriend => 'Invite Friend';

  @override
  String get profile_blacklist => 'Blacklist';

  @override
  String get profile_settings => 'Settings';

  @override
  String get blacklist_chatTab => 'Chat';

  @override
  String get blacklist_roomTab => 'Room';

  @override
  String get blacklist_emptyChat => 'No blocked chats';

  @override
  String get blacklist_emptyRoom => 'No room kick records';

  @override
  String get blacklist_unblock => 'Unblock';

  @override
  String get blacklist_unblocked => 'User unblocked';

  @override
  String get blacklist_noRoom => 'You don\'t have a room yet';

  @override
  String get chat_blockedCannotMessage =>
      'You cannot send or receive messages in this chat.';

  @override
  String get topBanner_leaveRoomConfirm =>
      'คุณแน่ใจหรือไม่ว่าต้องการออกจากห้องนี้?';

  @override
  String get topBanner_enterRoomConfirm => 'คุณต้องการเข้าห้องนี้หรือไม่?';
}
