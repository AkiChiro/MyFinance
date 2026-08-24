import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
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
/// import 'generated/app_localizations.dart';
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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('en'),
    Locale('vi')
  ];

  /// No description provided for @commonCancel.
  ///
  /// In vi, this message translates to:
  /// **'Huỷ'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In vi, this message translates to:
  /// **'Lưu'**
  String get commonSave;

  /// No description provided for @commonSaveChanges.
  ///
  /// In vi, this message translates to:
  /// **'Lưu thay đổi'**
  String get commonSaveChanges;

  /// No description provided for @commonDelete.
  ///
  /// In vi, this message translates to:
  /// **'Xoá'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In vi, this message translates to:
  /// **'Sửa'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In vi, this message translates to:
  /// **'Đóng'**
  String get commonClose;

  /// No description provided for @commonAdd.
  ///
  /// In vi, this message translates to:
  /// **'Thêm'**
  String get commonAdd;

  /// No description provided for @commonMarkStarred.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu sao'**
  String get commonMarkStarred;

  /// No description provided for @commonQuickAddLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thêm nhanh'**
  String get commonQuickAddLabel;

  /// No description provided for @commonUnexpectedError.
  ///
  /// In vi, this message translates to:
  /// **'Có lỗi xảy ra: {error}'**
  String commonUnexpectedError(String error);

  /// No description provided for @txTypeSpending.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiêu'**
  String get txTypeSpending;

  /// No description provided for @txTypeEarning.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập'**
  String get txTypeEarning;

  /// No description provided for @txTypeTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển khoản'**
  String get txTypeTransfer;

  /// No description provided for @categoryNecessities.
  ///
  /// In vi, this message translates to:
  /// **'Thiết yếu'**
  String get categoryNecessities;

  /// No description provided for @categoryFood.
  ///
  /// In vi, this message translates to:
  /// **'Ăn uống'**
  String get categoryFood;

  /// No description provided for @categoryHobbies.
  ///
  /// In vi, this message translates to:
  /// **'Sở thích'**
  String get categoryHobbies;

  /// No description provided for @categoryOthers.
  ///
  /// In vi, this message translates to:
  /// **'Khác'**
  String get categoryOthers;

  /// No description provided for @categoryProvided.
  ///
  /// In vi, this message translates to:
  /// **'Chu cấp'**
  String get categoryProvided;

  /// No description provided for @categorySelfEarned.
  ///
  /// In vi, this message translates to:
  /// **'Tự kiếm'**
  String get categorySelfEarned;

  /// No description provided for @walletKindCash.
  ///
  /// In vi, this message translates to:
  /// **'Tiền mặt'**
  String get walletKindCash;

  /// No description provided for @walletKindBank.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng'**
  String get walletKindBank;

  /// No description provided for @overspendError.
  ///
  /// In vi, this message translates to:
  /// **'Hãy kiểm tra lại số tiền thực tế'**
  String get overspendError;

  /// No description provided for @notifChannelDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nút thêm giao dịch nhanh từ thanh thông báo'**
  String get notifChannelDescription;

  /// No description provided for @notifBody.
  ///
  /// In vi, this message translates to:
  /// **'Nhấn để ghi giao dịch nhanh'**
  String get notifBody;

  /// No description provided for @navWallets.
  ///
  /// In vi, this message translates to:
  /// **'Ví'**
  String get navWallets;

  /// No description provided for @navTransactions.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch'**
  String get navTransactions;

  /// No description provided for @navAnalytics.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê'**
  String get navAnalytics;

  /// No description provided for @navSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get navSettings;

  /// No description provided for @monthYearLabel.
  ///
  /// In vi, this message translates to:
  /// **'Tháng {month}/{year}'**
  String monthYearLabel(int month, int year);

  /// No description provided for @walletsTotalBalance.
  ///
  /// In vi, this message translates to:
  /// **'Tổng số dư'**
  String get walletsTotalBalance;

  /// No description provided for @walletsAddButton.
  ///
  /// In vi, this message translates to:
  /// **'Thêm ví'**
  String get walletsAddButton;

  /// No description provided for @walletsEmptyMessage.
  ///
  /// In vi, this message translates to:
  /// **'Bạn chưa có ví nào. Hãy tạo ví đầu tiên để bắt đầu theo dõi chi tiêu nhé!'**
  String get walletsEmptyMessage;

  /// No description provided for @walletsNameField.
  ///
  /// In vi, this message translates to:
  /// **'Tên ví'**
  String get walletsNameField;

  /// No description provided for @walletsCurrentBalanceField.
  ///
  /// In vi, this message translates to:
  /// **'Số dư hiện tại (₫)'**
  String get walletsCurrentBalanceField;

  /// No description provided for @walletsBankLinkField.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng liên kết'**
  String get walletsBankLinkField;

  /// No description provided for @walletsBankLinkNone.
  ///
  /// In vi, this message translates to:
  /// **'— Không —'**
  String get walletsBankLinkNone;

  /// No description provided for @walletsRecentActivityTitle.
  ///
  /// In vi, this message translates to:
  /// **'Hoạt động gần đây'**
  String get walletsRecentActivityTitle;

  /// No description provided for @walletsRecentActivitySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Qua {count} giao dịch gần nhất'**
  String walletsRecentActivitySubtitle(int count);

  /// No description provided for @walletsBankConflictTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng đã được liên kết'**
  String get walletsBankConflictTitle;

  /// No description provided for @walletsBankConflictBody.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng này đang liên kết với ví \"{name}\". Chuyển sang ví mới?'**
  String walletsBankConflictBody(String name);

  /// No description provided for @walletBankLinkMoveAction.
  ///
  /// In vi, this message translates to:
  /// **'Chuyển'**
  String get walletBankLinkMoveAction;

  /// No description provided for @walletEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ví'**
  String get walletEditTitle;

  /// No description provided for @walletEditDeleteTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ví'**
  String get walletEditDeleteTooltip;

  /// No description provided for @walletEditNameRequired.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập tên ví.'**
  String get walletEditNameRequired;

  /// No description provided for @walletEditInitialBalanceField.
  ///
  /// In vi, this message translates to:
  /// **'Số dư ban đầu (₫)'**
  String get walletEditInitialBalanceField;

  /// No description provided for @walletEditBalanceHelperText.
  ///
  /// In vi, this message translates to:
  /// **'Thay đổi giá trị này sẽ đặt lại số dư — các giao dịch cũ sẽ không còn tính vào số dư nữa.'**
  String get walletEditBalanceHelperText;

  /// No description provided for @walletEditBankLinkNoneAlt.
  ///
  /// In vi, this message translates to:
  /// **'— Không liên kết —'**
  String get walletEditBankLinkNoneAlt;

  /// No description provided for @walletEditBankConflictBody.
  ///
  /// In vi, this message translates to:
  /// **'Ngân hàng này đang liên kết với ví \"{name}\". Chuyển sang ví này?'**
  String walletEditBankConflictBody(String name);

  /// No description provided for @walletEditDeleteConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ví \"{name}\"?'**
  String walletEditDeleteConfirmTitle(String name);

  /// No description provided for @walletEditDeleteConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch liên quan vẫn được giữ lại nhưng sẽ không còn ví tham chiếu.'**
  String get walletEditDeleteConfirmBody;

  /// No description provided for @txnsChipAll.
  ///
  /// In vi, this message translates to:
  /// **'Tất cả'**
  String get txnsChipAll;

  /// No description provided for @txnsChipMonth.
  ///
  /// In vi, this message translates to:
  /// **'Tháng'**
  String get txnsChipMonth;

  /// No description provided for @txnsChipStarred.
  ///
  /// In vi, this message translates to:
  /// **'Có sao'**
  String get txnsChipStarred;

  /// No description provided for @txnsAmountAsc.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền ↑'**
  String get txnsAmountAsc;

  /// No description provided for @txnsAmountDesc.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền ↓'**
  String get txnsAmountDesc;

  /// No description provided for @txnsPickCategoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn danh mục'**
  String get txnsPickCategoryTitle;

  /// No description provided for @pendingCaptureBanner.
  ///
  /// In vi, this message translates to:
  /// **'{count, plural, one{{count} thông báo ngân hàng chờ xác nhận} other{{count} thông báo ngân hàng chờ xác nhận}}'**
  String pendingCaptureBanner(int count);

  /// No description provided for @txnsEmptyStarred.
  ///
  /// In vi, this message translates to:
  /// **'Không có giao dịch nào có sao.'**
  String get txnsEmptyStarred;

  /// No description provided for @txnsEmptyMonth.
  ///
  /// In vi, this message translates to:
  /// **'Không có giao dịch nào trong tháng này.'**
  String get txnsEmptyMonth;

  /// No description provided for @txnsEmptyAll.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có giao dịch nào.'**
  String get txnsEmptyAll;

  /// No description provided for @txnsImportedBadge.
  ///
  /// In vi, this message translates to:
  /// **'đã nhập'**
  String get txnsImportedBadge;

  /// No description provided for @txnsOtherWallet.
  ///
  /// In vi, this message translates to:
  /// **'(ví khác)'**
  String get txnsOtherWallet;

  /// No description provided for @txnsUnmarkStarred.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ đánh dấu sao'**
  String get txnsUnmarkStarred;

  /// No description provided for @txnsDeleteConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá giao dịch?'**
  String get txnsDeleteConfirmTitle;

  /// No description provided for @quickAddEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa giao dịch'**
  String get quickAddEditTitle;

  /// No description provided for @quickAddNoWalletMessage.
  ///
  /// In vi, this message translates to:
  /// **'Hãy thêm ít nhất một ví trước khi ghi giao dịch.'**
  String get quickAddNoWalletMessage;

  /// No description provided for @fieldAmount.
  ///
  /// In vi, this message translates to:
  /// **'Số tiền'**
  String get fieldAmount;

  /// No description provided for @fieldDescription.
  ///
  /// In vi, this message translates to:
  /// **'Mô tả'**
  String get fieldDescription;

  /// No description provided for @fieldCategory.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục'**
  String get fieldCategory;

  /// No description provided for @fieldWallet.
  ///
  /// In vi, this message translates to:
  /// **'Ví'**
  String get fieldWallet;

  /// No description provided for @quickAddFromWallet.
  ///
  /// In vi, this message translates to:
  /// **'Từ ví'**
  String get quickAddFromWallet;

  /// No description provided for @quickAddToWallet.
  ///
  /// In vi, this message translates to:
  /// **'Đến ví'**
  String get quickAddToWallet;

  /// No description provided for @quickAddTimeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian'**
  String get quickAddTimeLabel;

  /// No description provided for @quickAddInvalidAmount.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng nhập số tiền hợp lệ.'**
  String get quickAddInvalidAmount;

  /// No description provided for @quickAddPickSourceWallet.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ví nguồn.'**
  String get quickAddPickSourceWallet;

  /// No description provided for @quickAddPickWallet.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ví.'**
  String get quickAddPickWallet;

  /// No description provided for @quickAddPickDestWallet.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ví đích.'**
  String get quickAddPickDestWallet;

  /// No description provided for @quickAddSameWalletError.
  ///
  /// In vi, this message translates to:
  /// **'Ví nguồn và ví đích phải khác nhau.'**
  String get quickAddSameWalletError;

  /// No description provided for @analyticsNoData.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có dữ liệu.'**
  String get analyticsNoData;

  /// No description provided for @analyticsMonthComparisonTitle.
  ///
  /// In vi, this message translates to:
  /// **'So sánh tháng'**
  String get analyticsMonthComparisonTitle;

  /// No description provided for @analyticsSpendByCategoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chi tiêu theo danh mục'**
  String get analyticsSpendByCategoryTitle;

  /// No description provided for @analyticsEnvelopeSectionTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách theo danh mục'**
  String get analyticsEnvelopeSectionTitle;

  /// No description provided for @analyticsEnvelopeRemaining.
  ///
  /// In vi, this message translates to:
  /// **'Còn lại: {amount}'**
  String analyticsEnvelopeRemaining(String amount);

  /// No description provided for @analyticsEnvelopeOverBy.
  ///
  /// In vi, this message translates to:
  /// **'Vượt: {amount}'**
  String analyticsEnvelopeOverBy(String amount);

  /// No description provided for @analyticsEnvelopeNotFundedYet.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có thu nhập để phân bổ'**
  String get analyticsEnvelopeNotFundedYet;

  /// No description provided for @analyticsEnvelopeEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa ngân sách: {label}'**
  String analyticsEnvelopeEditTitle(String label);

  /// No description provided for @analyticsEnvelopeResetTrigger.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại ngân sách…'**
  String get analyticsEnvelopeResetTrigger;

  /// No description provided for @analyticsEnvelopeResetConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại ngân sách cho \"{label}\"?'**
  String analyticsEnvelopeResetConfirmTitle(String label);

  /// No description provided for @analyticsEnvelopeResetConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Các giao dịch đã ghi trước đó sẽ không còn tính vào ngân sách của danh mục này — chỉ giao dịch từ bây giờ trở đi mới được tính.'**
  String get analyticsEnvelopeResetConfirmBody;

  /// No description provided for @analyticsEnvelopeResetAction.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get analyticsEnvelopeResetAction;

  /// No description provided for @analyticsEarnByCategoryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thu nhập theo danh mục'**
  String get analyticsEarnByCategoryTitle;

  /// No description provided for @analyticsCategoryTotal.
  ///
  /// In vi, this message translates to:
  /// **'Tổng: {total}'**
  String analyticsCategoryTotal(String total);

  /// No description provided for @spendingLegendLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chi ({period})'**
  String spendingLegendLabel(String period);

  /// No description provided for @earningLegendLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thu ({period})'**
  String earningLegendLabel(String period);

  /// No description provided for @analyticsTotalSpending.
  ///
  /// In vi, this message translates to:
  /// **'Tổng chi'**
  String get analyticsTotalSpending;

  /// No description provided for @analyticsTotalEarning.
  ///
  /// In vi, this message translates to:
  /// **'Tổng thu'**
  String get analyticsTotalEarning;

  /// No description provided for @analyticsNetThisMonth.
  ///
  /// In vi, this message translates to:
  /// **'Chênh lệch tháng này'**
  String get analyticsNetThisMonth;

  /// No description provided for @analyticsPctSuffix.
  ///
  /// In vi, this message translates to:
  /// **'{signedPct} so tháng trước'**
  String analyticsPctSuffix(String signedPct);

  /// No description provided for @analyticsNetComparisonLabel.
  ///
  /// In vi, this message translates to:
  /// **'So tháng trước: {signedPct} so tháng trước'**
  String analyticsNetComparisonLabel(String signedPct);

  /// No description provided for @yearCardTitle.
  ///
  /// In vi, this message translates to:
  /// **'Năm {year}'**
  String yearCardTitle(int year);

  /// No description provided for @analyticsNetLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chênh lệch'**
  String get analyticsNetLabel;

  /// No description provided for @settingsSectionNotifications.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo'**
  String get settingsSectionNotifications;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In vi, this message translates to:
  /// **'Ngôn ngữ'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionCurrency.
  ///
  /// In vi, this message translates to:
  /// **'Đơn vị tiền tệ'**
  String get settingsSectionCurrency;

  /// No description provided for @settingsSectionAutostar.
  ///
  /// In vi, this message translates to:
  /// **'Tự động đánh dấu sao'**
  String get settingsSectionAutostar;

  /// No description provided for @settingsSectionCategories.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục'**
  String get settingsSectionCategories;

  /// No description provided for @settingsSectionTheme.
  ///
  /// In vi, this message translates to:
  /// **'Giao diện'**
  String get settingsSectionTheme;

  /// No description provided for @settingsSectionCsv.
  ///
  /// In vi, this message translates to:
  /// **'Sao lưu dữ liệu (CSV)'**
  String get settingsSectionCsv;

  /// No description provided for @settingsSectionKeywords.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục gợi ý'**
  String get settingsSectionKeywords;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin'**
  String get settingsSectionAbout;

  /// No description provided for @settingsSectionDeveloper.
  ///
  /// In vi, this message translates to:
  /// **'Nhà phát triển'**
  String get settingsSectionDeveloper;

  /// No description provided for @settingsNotifTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo liên tục'**
  String get settingsNotifTitle;

  /// No description provided for @settingsNotifSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Giữ nút thêm nhanh trong thanh thông báo.'**
  String get settingsNotifSubtitle;

  /// No description provided for @settingsBatteryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ý pin'**
  String get settingsBatteryTitle;

  /// No description provided for @settingsBatteryBody.
  ///
  /// In vi, this message translates to:
  /// **'Nếu thông báo biến mất sau khi tắt màn hình, hãy tắt \"Tối ưu hoá pin\" cho MyFinance trong Cài đặt → Ứng dụng.'**
  String get settingsBatteryBody;

  /// No description provided for @settingsCurrencySymbolTitle.
  ///
  /// In vi, this message translates to:
  /// **'Ký hiệu tiền tệ'**
  String get settingsCurrencySymbolTitle;

  /// No description provided for @currencyExampleLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ví dụ: 100.000 {symbol}'**
  String currencyExampleLabel(String symbol);

  /// No description provided for @settingsAutostarTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tự động sao theo ngưỡng'**
  String get settingsAutostarTitle;

  /// No description provided for @settingsAutostarSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tự động đánh dấu sao cho khoản chi vượt ngưỡng danh mục.'**
  String get settingsAutostarSubtitle;

  /// No description provided for @settingsManageCategoriesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Quản lý danh mục'**
  String get settingsManageCategoriesTitle;

  /// No description provided for @settingsManageCategoriesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm, sửa, lưu trữ danh mục chi tiêu và thu nhập.'**
  String get settingsManageCategoriesSubtitle;

  /// No description provided for @settingsColorModeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ màu'**
  String get settingsColorModeLabel;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In vi, this message translates to:
  /// **'Hệ thống'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In vi, this message translates to:
  /// **'Sáng'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In vi, this message translates to:
  /// **'Tối'**
  String get settingsThemeDark;

  /// No description provided for @settingsAdvancedThemeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chỉnh nâng cao'**
  String get settingsAdvancedThemeTitle;

  /// No description provided for @settingsAdvancedThemeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Màu nền, màu chữ, ảnh nền, màu chủ đề.'**
  String get settingsAdvancedThemeSubtitle;

  /// No description provided for @settingsCsvExportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xuất CSV'**
  String get settingsCsvExportTitle;

  /// No description provided for @settingsCsvExportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu ví, giao dịch, danh mục, giao diện và từ khoá gợi ý ra một file CSV.'**
  String get settingsCsvExportSubtitle;

  /// No description provided for @settingsCsvShareSubject.
  ///
  /// In vi, this message translates to:
  /// **'MyFinance — sao lưu CSV'**
  String get settingsCsvShareSubject;

  /// No description provided for @settingsCsvImportTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập CSV'**
  String get settingsCsvImportTitle;

  /// No description provided for @settingsCsvImportSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập ví và giao dịch từ file CSV. Ví trùng id được giữ nguyên; giao dịch trùng id được cập nhật.'**
  String get settingsCsvImportSubtitle;

  /// No description provided for @settingsKeywordLibraryTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thư viện từ khoá'**
  String get settingsKeywordLibraryTitle;

  /// No description provided for @settingsKeywordLibrarySubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa từ khoá và danh mục gợi ý khi nhập mô tả.'**
  String get settingsKeywordLibrarySubtitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Phiên bản 0.2 · Hoàn toàn ngoại tuyến · Chỉ dùng VND.'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsListenerPermTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cấp quyền nghe thông báo'**
  String get settingsListenerPermTitle;

  /// No description provided for @settingsListenerPermSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt hệ thống để bật quyền cho dịch vụ chụp thông báo ngân hàng (BankCaptureService).'**
  String get settingsListenerPermSubtitle;

  /// No description provided for @settingsSeenPackagesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Gói ứng dụng đã thấy'**
  String get settingsSeenPackagesTitle;

  /// No description provided for @settingsSeenPackagesSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Xem tên gói của các ứng dụng đã gửi thông báo — dùng để xác minh hằng số BankPackages.'**
  String get settingsSeenPackagesSubtitle;

  /// No description provided for @settingsExportFailed.
  ///
  /// In vi, this message translates to:
  /// **'Xuất CSV thất bại: {error}'**
  String settingsExportFailed(String error);

  /// No description provided for @settingsCsvImportConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập dữ liệu từ CSV?'**
  String get settingsCsvImportConfirmTitle;

  /// No description provided for @settingsCsvImportConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Ví có id đã tồn tại sẽ được giữ nguyên. Giao dịch có id đã tồn tại sẽ được cập nhật theo file CSV; giao dịch mới sẽ được thêm vào.'**
  String get settingsCsvImportConfirmBody;

  /// No description provided for @settingsCsvImportConfirmAction.
  ///
  /// In vi, this message translates to:
  /// **'Nhập'**
  String get settingsCsvImportConfirmAction;

  /// No description provided for @settingsCsvWrongFileType.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn một file .csv.'**
  String get settingsCsvWrongFileType;

  /// No description provided for @csvImportResult.
  ///
  /// In vi, this message translates to:
  /// **'{walletsAdded} ví mới ({walletsSkipped} bỏ qua), {txnsAdded} giao dịch mới, {txnsUpdated} giao dịch đã cập nhật, {categoriesAdded} danh mục mới ({categoriesSkipped} bỏ qua), {budgetEntriesAdded} mức ngân sách mới.'**
  String csvImportResult(
      int walletsAdded,
      int walletsSkipped,
      int txnsAdded,
      int txnsUpdated,
      int categoriesAdded,
      int categoriesSkipped,
      int budgetEntriesAdded);

  /// No description provided for @settingsImportFailed.
  ///
  /// In vi, this message translates to:
  /// **'Nhập CSV thất bại: {error}'**
  String settingsImportFailed(String error);

  /// No description provided for @settingsNotifPermTitle.
  ///
  /// In vi, this message translates to:
  /// **'Cần quyền thông báo'**
  String get settingsNotifPermTitle;

  /// No description provided for @settingsNotifPermBody.
  ///
  /// In vi, this message translates to:
  /// **'Quyền thông báo đã bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt ứng dụng.'**
  String get settingsNotifPermBody;

  /// No description provided for @settingsNotNow.
  ///
  /// In vi, this message translates to:
  /// **'Không phải bây giờ'**
  String get settingsNotNow;

  /// No description provided for @settingsOpenSettings.
  ///
  /// In vi, this message translates to:
  /// **'Mở cài đặt'**
  String get settingsOpenSettings;

  /// No description provided for @settingsCurrencySymbolFieldLabel.
  ///
  /// In vi, this message translates to:
  /// **'Ký hiệu'**
  String get settingsCurrencySymbolFieldLabel;

  /// No description provided for @settingsNoPackagesSeen.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có gói nào. Cấp quyền nghe thông báo và chờ ứng dụng ngân hàng gửi thông báo.'**
  String get settingsNoPackagesSeen;

  /// No description provided for @settingsPackagesHint.
  ///
  /// In vi, this message translates to:
  /// **'Dùng các tên gói này để xác minh BankPackages.'**
  String get settingsPackagesHint;

  /// No description provided for @keywordEditorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Từ khoá gợi ý'**
  String get keywordEditorTitle;

  /// No description provided for @keywordEditorEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có từ khoá nào.'**
  String get keywordEditorEmpty;

  /// No description provided for @keywordEditorSaved.
  ///
  /// In vi, this message translates to:
  /// **'Đã lưu thư viện từ khoá.'**
  String get keywordEditorSaved;

  /// No description provided for @keywordEditorAddTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm từ khoá'**
  String get keywordEditorAddTitle;

  /// No description provided for @keywordEditorKeywordField.
  ///
  /// In vi, this message translates to:
  /// **'Từ khoá'**
  String get keywordEditorKeywordField;

  /// No description provided for @keywordEditorWeightField.
  ///
  /// In vi, this message translates to:
  /// **'Trọng số (1–10)'**
  String get keywordEditorWeightField;

  /// No description provided for @categoriesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục'**
  String get categoriesTitle;

  /// No description provided for @categoriesAddSpending.
  ///
  /// In vi, this message translates to:
  /// **'Thêm chi tiêu'**
  String get categoriesAddSpending;

  /// No description provided for @categoriesAddEarning.
  ///
  /// In vi, this message translates to:
  /// **'Thêm thu nhập'**
  String get categoriesAddEarning;

  /// No description provided for @categoriesAddSpendingTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm danh mục chi tiêu'**
  String get categoriesAddSpendingTitle;

  /// No description provided for @categoriesAddEarningTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thêm danh mục thu nhập'**
  String get categoriesAddEarningTitle;

  /// No description provided for @categoriesNameField.
  ///
  /// In vi, this message translates to:
  /// **'Tên danh mục'**
  String get categoriesNameField;

  /// No description provided for @categoriesThresholdFieldOptional.
  ///
  /// In vi, this message translates to:
  /// **'Ngưỡng tự động sao (₫, tùy chọn)'**
  String get categoriesThresholdFieldOptional;

  /// No description provided for @categoriesEmptySpending.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có danh mục chi tiêu.'**
  String get categoriesEmptySpending;

  /// No description provided for @categoriesEmptyEarning.
  ///
  /// In vi, this message translates to:
  /// **'Chưa có danh mục thu nhập.'**
  String get categoriesEmptyEarning;

  /// No description provided for @categoriesThresholdSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Tự động sao > {threshold}'**
  String categoriesThresholdSubtitle(String threshold);

  /// No description provided for @categoriesNoThreshold.
  ///
  /// In vi, this message translates to:
  /// **'Không tự động sao'**
  String get categoriesNoThreshold;

  /// No description provided for @categoriesArchiveTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trữ danh mục'**
  String get categoriesArchiveTooltip;

  /// No description provided for @categoriesEditTitle.
  ///
  /// In vi, this message translates to:
  /// **'Sửa danh mục'**
  String get categoriesEditTitle;

  /// No description provided for @categoriesThresholdFieldEdit.
  ///
  /// In vi, this message translates to:
  /// **'Ngưỡng tự động sao (₫, để trống = tắt)'**
  String get categoriesThresholdFieldEdit;

  /// No description provided for @categoriesArchiveConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trữ \"{label}\"?'**
  String categoriesArchiveConfirmTitle(String label);

  /// No description provided for @categoriesArchiveConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Danh mục sẽ ẩn khỏi lựa chọn nhưng giao dịch cũ vẫn giữ nguyên.'**
  String get categoriesArchiveConfirmBody;

  /// No description provided for @categoriesArchiveConfirmAction.
  ///
  /// In vi, this message translates to:
  /// **'Lưu trữ'**
  String get categoriesArchiveConfirmAction;

  /// No description provided for @categoriesBudgetPercentFieldOptional.
  ///
  /// In vi, this message translates to:
  /// **'Tỷ lệ ngân sách (%, tùy chọn)'**
  String get categoriesBudgetPercentFieldOptional;

  /// No description provided for @categoriesBudgetPercentSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ngân sách {percent}%'**
  String categoriesBudgetPercentSubtitle(int percent);

  /// No description provided for @budgetPercentExceededError.
  ///
  /// In vi, this message translates to:
  /// **'Tổng tỷ lệ ngân sách các danh mục vượt quá 100%.'**
  String get budgetPercentExceededError;

  /// No description provided for @themeTitle.
  ///
  /// In vi, this message translates to:
  /// **'Tuỳ chỉnh giao diện'**
  String get themeTitle;

  /// No description provided for @themeResetAction.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại'**
  String get themeResetAction;

  /// No description provided for @themeColorsSection.
  ///
  /// In vi, this message translates to:
  /// **'Màu sắc'**
  String get themeColorsSection;

  /// No description provided for @themeSeedColorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Màu chủ đề'**
  String get themeSeedColorTitle;

  /// No description provided for @themeSeedColorSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh hưởng tới nút, thanh tiêu đề và toàn bộ bảng màu.'**
  String get themeSeedColorSubtitle;

  /// No description provided for @themeBgColorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Màu nền ứng dụng'**
  String get themeBgColorTitle;

  /// No description provided for @themeBgColorSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Màu nền của màn hình. \"Tự động\" dùng màu mặc định theo chế độ sáng/tối.'**
  String get themeBgColorSubtitle;

  /// No description provided for @themeFontColorTitle.
  ///
  /// In vi, this message translates to:
  /// **'Màu chữ'**
  String get themeFontColorTitle;

  /// No description provided for @themeFontColorSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'\"Tự động\" theo chế độ sáng/tối. Cẩn thận khi chọn màu tương phản thấp.'**
  String get themeFontColorSubtitle;

  /// No description provided for @themeBgImageSection.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh nền'**
  String get themeBgImageSection;

  /// No description provided for @themeBgImagePickTitle.
  ///
  /// In vi, this message translates to:
  /// **'Chọn ảnh nền'**
  String get themeBgImagePickTitle;

  /// No description provided for @themeBgImagePickSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh hiển thị phía sau toàn bộ màn hình.'**
  String get themeBgImagePickSubtitle;

  /// No description provided for @themeBgImageNotFound.
  ///
  /// In vi, this message translates to:
  /// **'Không tìm thấy ảnh'**
  String get themeBgImageNotFound;

  /// No description provided for @themeBgImageDeleteTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xoá ảnh nền'**
  String get themeBgImageDeleteTitle;

  /// No description provided for @themeBgImageNote.
  ///
  /// In vi, this message translates to:
  /// **'Khi dùng ảnh nền, nền ứng dụng sẽ tự động trong suốt để hiện ảnh phía sau.'**
  String get themeBgImageNote;

  /// No description provided for @themeResetConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại giao diện?'**
  String get themeResetConfirmTitle;

  /// No description provided for @themeResetConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Màu chủ đề, màu nền, màu chữ, ảnh nền và biểu tượng tuỳ chỉnh sẽ trở về mặc định.'**
  String get themeResetConfirmBody;

  /// No description provided for @themeColorAuto.
  ///
  /// In vi, this message translates to:
  /// **'Tự động'**
  String get themeColorAuto;

  /// No description provided for @themeHexLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mã màu Hex'**
  String get themeHexLabel;

  /// No description provided for @themeHexError.
  ///
  /// In vi, this message translates to:
  /// **'Mã không hợp lệ (cần 6 ký tự)'**
  String get themeHexError;

  /// No description provided for @themeIconsSection.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng'**
  String get themeIconsSection;

  /// No description provided for @themeIconsHint.
  ///
  /// In vi, this message translates to:
  /// **'Ảnh vuông, nền trong suốt. Tối thiểu 128×128, khuyến nghị 256×256.'**
  String get themeIconsHint;

  /// No description provided for @themeIconGroupNav.
  ///
  /// In vi, this message translates to:
  /// **'Điều hướng'**
  String get themeIconGroupNav;

  /// No description provided for @themeIconGroupFab.
  ///
  /// In vi, this message translates to:
  /// **'Nút thêm nhanh'**
  String get themeIconGroupFab;

  /// No description provided for @themeIconGroupType.
  ///
  /// In vi, this message translates to:
  /// **'Loại giao dịch'**
  String get themeIconGroupType;

  /// No description provided for @themeIconGroupStar.
  ///
  /// In vi, this message translates to:
  /// **'Đánh dấu sao'**
  String get themeIconGroupStar;

  /// No description provided for @themeIconGroupWallet.
  ///
  /// In vi, this message translates to:
  /// **'Loại ví'**
  String get themeIconGroupWallet;

  /// No description provided for @themeIconSlotNavWallets.
  ///
  /// In vi, this message translates to:
  /// **'Ví (thanh điều hướng)'**
  String get themeIconSlotNavWallets;

  /// No description provided for @themeIconSlotNavTransactions.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch (thanh điều hướng)'**
  String get themeIconSlotNavTransactions;

  /// No description provided for @themeIconSlotNavAnalytics.
  ///
  /// In vi, this message translates to:
  /// **'Thống kê (thanh điều hướng)'**
  String get themeIconSlotNavAnalytics;

  /// No description provided for @themeIconSlotNavSettings.
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt (thanh điều hướng)'**
  String get themeIconSlotNavSettings;

  /// No description provided for @themeIconSlotFabAdd.
  ///
  /// In vi, this message translates to:
  /// **'Nút thêm (FAB)'**
  String get themeIconSlotFabAdd;

  /// No description provided for @themeIconSlotTypeSpending.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng chi tiêu'**
  String get themeIconSlotTypeSpending;

  /// No description provided for @themeIconSlotTypeEarning.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng thu nhập'**
  String get themeIconSlotTypeEarning;

  /// No description provided for @themeIconSlotTypeTransfer.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng chuyển khoản'**
  String get themeIconSlotTypeTransfer;

  /// No description provided for @themeIconSlotStar.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng sao'**
  String get themeIconSlotStar;

  /// No description provided for @themeIconSlotWalletCash.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng ví tiền mặt'**
  String get themeIconSlotWalletCash;

  /// No description provided for @themeIconSlotWalletBank.
  ///
  /// In vi, this message translates to:
  /// **'Biểu tượng ví ngân hàng'**
  String get themeIconSlotWalletBank;

  /// No description provided for @themeIconResetTooltip.
  ///
  /// In vi, this message translates to:
  /// **'Đặt lại biểu tượng mặc định'**
  String get themeIconResetTooltip;

  /// No description provided for @capturesTitle.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo ngân hàng'**
  String get capturesTitle;

  /// No description provided for @capturesEmpty.
  ///
  /// In vi, this message translates to:
  /// **'Không có thông báo nào cần xem.'**
  String get capturesEmpty;

  /// No description provided for @capturesNeedsReview.
  ///
  /// In vi, this message translates to:
  /// **'Cần xem lại'**
  String get capturesNeedsReview;

  /// No description provided for @capturesUnparsed.
  ///
  /// In vi, this message translates to:
  /// **'Chưa đọc được'**
  String get capturesUnparsed;

  /// No description provided for @captureConfirmManualTitle.
  ///
  /// In vi, this message translates to:
  /// **'Nhập thủ công'**
  String get captureConfirmManualTitle;

  /// No description provided for @captureConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Xác nhận giao dịch'**
  String get captureConfirmTitle;

  /// No description provided for @captureConfirmDismissAction.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua'**
  String get captureConfirmDismissAction;

  /// No description provided for @captureConfirmUnparsedBanner.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo chưa đọc được tự động'**
  String get captureConfirmUnparsedBanner;

  /// No description provided for @captureConfirmWalletField.
  ///
  /// In vi, this message translates to:
  /// **'Ví *'**
  String get captureConfirmWalletField;

  /// No description provided for @captureConfirmCategoryNone.
  ///
  /// In vi, this message translates to:
  /// **'— Bỏ qua —'**
  String get captureConfirmCategoryNone;

  /// No description provided for @captureConfirmTimeLabel.
  ///
  /// In vi, this message translates to:
  /// **'Thời gian giao dịch'**
  String get captureConfirmTimeLabel;

  /// No description provided for @captureConfirmRawContentLabel.
  ///
  /// In vi, this message translates to:
  /// **'Nội dung thông báo'**
  String get captureConfirmRawContentLabel;

  /// No description provided for @captureConfirmPickWallet.
  ///
  /// In vi, this message translates to:
  /// **'Vui lòng chọn ví.'**
  String get captureConfirmPickWallet;

  /// No description provided for @captureConfirmDismissConfirmTitle.
  ///
  /// In vi, this message translates to:
  /// **'Bỏ qua thông báo này?'**
  String get captureConfirmDismissConfirmTitle;

  /// No description provided for @captureConfirmDismissConfirmBody.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo sẽ không tạo giao dịch nào.'**
  String get captureConfirmDismissConfirmBody;

  /// No description provided for @notifCaptureChannelName.
  ///
  /// In vi, this message translates to:
  /// **'Thông báo giao dịch ngân hàng'**
  String get notifCaptureChannelName;

  /// No description provided for @notifCaptureChannelDescription.
  ///
  /// In vi, this message translates to:
  /// **'Báo khi có giao dịch ngân hàng mới được ghi nhận'**
  String get notifCaptureChannelDescription;

  /// No description provided for @notifCaptureTitle.
  ///
  /// In vi, this message translates to:
  /// **'Giao dịch ngân hàng mới'**
  String get notifCaptureTitle;

  /// No description provided for @notifCaptureBody.
  ///
  /// In vi, this message translates to:
  /// **'Có giao dịch {amount} vào {wallet}'**
  String notifCaptureBody(String amount, String wallet);

  /// No description provided for @notifCaptureBodyNoWallet.
  ///
  /// In vi, this message translates to:
  /// **'Có giao dịch {amount}, chưa xác định ví'**
  String notifCaptureBodyNoWallet(String amount);

  /// No description provided for @notifCaptureBodyUnparsed.
  ///
  /// In vi, this message translates to:
  /// **'Có một thông báo ngân hàng cần bạn xác nhận thủ công'**
  String get notifCaptureBodyUnparsed;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
