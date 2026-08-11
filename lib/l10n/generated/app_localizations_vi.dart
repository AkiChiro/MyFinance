// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get commonCancel => 'Huỷ';

  @override
  String get commonSave => 'Lưu';

  @override
  String get commonSaveChanges => 'Lưu thay đổi';

  @override
  String get commonDelete => 'Xoá';

  @override
  String get commonEdit => 'Sửa';

  @override
  String get commonClose => 'Đóng';

  @override
  String get commonAdd => 'Thêm';

  @override
  String get commonMarkStarred => 'Đánh dấu sao';

  @override
  String get commonQuickAddLabel => 'Thêm nhanh';

  @override
  String commonUnexpectedError(String error) {
    return 'Có lỗi xảy ra: $error';
  }

  @override
  String get txTypeSpending => 'Chi tiêu';

  @override
  String get txTypeEarning => 'Thu nhập';

  @override
  String get txTypeTransfer => 'Chuyển khoản';

  @override
  String get categoryNecessities => 'Thiết yếu';

  @override
  String get categoryFood => 'Ăn uống';

  @override
  String get categoryHobbies => 'Sở thích';

  @override
  String get categoryOthers => 'Khác';

  @override
  String get categoryProvided => 'Chu cấp';

  @override
  String get categorySelfEarned => 'Tự kiếm';

  @override
  String get walletKindCash => 'Tiền mặt';

  @override
  String get walletKindBank => 'Ngân hàng';

  @override
  String get overspendError => 'Hãy kiểm tra lại số tiền thực tế';

  @override
  String get notifChannelDescription =>
      'Nút thêm giao dịch nhanh từ thanh thông báo';

  @override
  String get notifBody => 'Nhấn để ghi giao dịch nhanh';

  @override
  String get navWallets => 'Ví';

  @override
  String get navTransactions => 'Giao dịch';

  @override
  String get navAnalytics => 'Thống kê';

  @override
  String get navSettings => 'Cài đặt';

  @override
  String monthYearLabel(int month, int year) {
    return 'Tháng $month/$year';
  }

  @override
  String get walletsTotalBalance => 'Tổng số dư';

  @override
  String get walletsAddButton => 'Thêm ví';

  @override
  String get walletsEmptyMessage =>
      'Bạn chưa có ví nào. Hãy tạo ví đầu tiên để bắt đầu theo dõi chi tiêu nhé!';

  @override
  String get walletsNameField => 'Tên ví';

  @override
  String get walletsCurrentBalanceField => 'Số dư hiện tại (₫)';

  @override
  String get walletsBankLinkField => 'Ngân hàng liên kết';

  @override
  String get walletsBankLinkNone => '— Không —';

  @override
  String get walletsRecentActivityTitle => 'Hoạt động gần đây';

  @override
  String walletsRecentActivitySubtitle(int count) {
    return 'Qua $count giao dịch gần nhất';
  }

  @override
  String get walletsBankConflictTitle => 'Ngân hàng đã được liên kết';

  @override
  String walletsBankConflictBody(String name) {
    return 'Ngân hàng này đang liên kết với ví \"$name\". Chuyển sang ví mới?';
  }

  @override
  String get walletBankLinkMoveAction => 'Chuyển';

  @override
  String get walletEditTitle => 'Sửa ví';

  @override
  String get walletEditDeleteTooltip => 'Xoá ví';

  @override
  String get walletEditNameRequired => 'Vui lòng nhập tên ví.';

  @override
  String get walletEditInitialBalanceField => 'Số dư ban đầu (₫)';

  @override
  String get walletEditBalanceHelperText =>
      'Thay đổi giá trị này sẽ đặt lại số dư — các giao dịch cũ sẽ không còn tính vào số dư nữa.';

  @override
  String get walletEditBankLinkNoneAlt => '— Không liên kết —';

  @override
  String walletEditBankConflictBody(String name) {
    return 'Ngân hàng này đang liên kết với ví \"$name\". Chuyển sang ví này?';
  }

  @override
  String walletEditDeleteConfirmTitle(String name) {
    return 'Xoá ví \"$name\"?';
  }

  @override
  String get walletEditDeleteConfirmBody =>
      'Giao dịch liên quan vẫn được giữ lại nhưng sẽ không còn ví tham chiếu.';

  @override
  String get txnsChipAll => 'Tất cả';

  @override
  String get txnsChipMonth => 'Tháng';

  @override
  String get txnsChipStarred => 'Có sao';

  @override
  String get txnsAmountAsc => 'Số tiền ↑';

  @override
  String get txnsAmountDesc => 'Số tiền ↓';

  @override
  String get txnsPickCategoryTitle => 'Chọn danh mục';

  @override
  String pendingCaptureBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thông báo ngân hàng chờ xác nhận',
      one: '$count thông báo ngân hàng chờ xác nhận',
    );
    return '$_temp0';
  }

  @override
  String get txnsEmptyStarred => 'Không có giao dịch nào có sao.';

  @override
  String get txnsEmptyMonth => 'Không có giao dịch nào trong tháng này.';

  @override
  String get txnsEmptyAll => 'Chưa có giao dịch nào.';

  @override
  String get txnsImportedBadge => 'đã nhập';

  @override
  String get txnsOtherWallet => '(ví khác)';

  @override
  String get txnsUnmarkStarred => 'Bỏ đánh dấu sao';

  @override
  String get txnsDeleteConfirmTitle => 'Xoá giao dịch?';

  @override
  String get quickAddEditTitle => 'Sửa giao dịch';

  @override
  String get quickAddNoWalletMessage =>
      'Hãy thêm ít nhất một ví trước khi ghi giao dịch.';

  @override
  String get fieldAmount => 'Số tiền';

  @override
  String get fieldDescription => 'Mô tả';

  @override
  String get fieldCategory => 'Danh mục';

  @override
  String get fieldWallet => 'Ví';

  @override
  String get quickAddFromWallet => 'Từ ví';

  @override
  String get quickAddToWallet => 'Đến ví';

  @override
  String get quickAddTimeLabel => 'Thời gian';

  @override
  String get quickAddInvalidAmount => 'Vui lòng nhập số tiền hợp lệ.';

  @override
  String get quickAddPickSourceWallet => 'Chọn ví nguồn.';

  @override
  String get quickAddPickWallet => 'Chọn ví.';

  @override
  String get quickAddPickDestWallet => 'Chọn ví đích.';

  @override
  String get quickAddSameWalletError => 'Ví nguồn và ví đích phải khác nhau.';

  @override
  String get analyticsNoData => 'Chưa có dữ liệu.';

  @override
  String get analyticsMonthComparisonTitle => 'So sánh tháng';

  @override
  String get analyticsSpendByCategoryTitle => 'Chi tiêu theo danh mục';

  @override
  String get analyticsEarnByCategoryTitle => 'Thu nhập theo danh mục';

  @override
  String analyticsCategoryTotal(String total) {
    return 'Tổng: $total';
  }

  @override
  String spendingLegendLabel(String period) {
    return 'Chi ($period)';
  }

  @override
  String earningLegendLabel(String period) {
    return 'Thu ($period)';
  }

  @override
  String get analyticsTotalSpending => 'Tổng chi';

  @override
  String get analyticsTotalEarning => 'Tổng thu';

  @override
  String get analyticsNetThisMonth => 'Chênh lệch tháng này';

  @override
  String analyticsPctSuffix(String signedPct) {
    return '$signedPct so tháng trước';
  }

  @override
  String analyticsNetComparisonLabel(String signedPct) {
    return 'So tháng trước: $signedPct so tháng trước';
  }

  @override
  String yearCardTitle(int year) {
    return 'Năm $year';
  }

  @override
  String get analyticsNetLabel => 'Chênh lệch';

  @override
  String get settingsSectionNotifications => 'Thông báo';

  @override
  String get settingsSectionLanguage => 'Ngôn ngữ';

  @override
  String get settingsSectionCurrency => 'Đơn vị tiền tệ';

  @override
  String get settingsSectionAutostar => 'Tự động đánh dấu sao';

  @override
  String get settingsSectionCategories => 'Danh mục';

  @override
  String get settingsSectionTheme => 'Giao diện';

  @override
  String get settingsSectionCsv => 'Sao lưu dữ liệu (CSV)';

  @override
  String get settingsSectionKeywords => 'Danh mục gợi ý';

  @override
  String get settingsSectionAbout => 'Thông tin';

  @override
  String get settingsSectionDeveloper => 'Nhà phát triển';

  @override
  String get settingsNotifTitle => 'Thông báo liên tục';

  @override
  String get settingsNotifSubtitle =>
      'Giữ nút thêm nhanh trong thanh thông báo.';

  @override
  String get settingsBatteryTitle => 'Lưu ý pin';

  @override
  String get settingsBatteryBody =>
      'Nếu thông báo biến mất sau khi tắt màn hình, hãy tắt \"Tối ưu hoá pin\" cho MyFinance trong Cài đặt → Ứng dụng.';

  @override
  String get settingsCurrencySymbolTitle => 'Ký hiệu tiền tệ';

  @override
  String currencyExampleLabel(String symbol) {
    return 'Ví dụ: 100.000 $symbol';
  }

  @override
  String get settingsAutostarTitle => 'Tự động sao theo ngưỡng';

  @override
  String get settingsAutostarSubtitle =>
      'Tự động đánh dấu sao cho khoản chi vượt ngưỡng danh mục.';

  @override
  String get settingsManageCategoriesTitle => 'Quản lý danh mục';

  @override
  String get settingsManageCategoriesSubtitle =>
      'Thêm, sửa, lưu trữ danh mục chi tiêu và thu nhập.';

  @override
  String get settingsColorModeLabel => 'Chế độ màu';

  @override
  String get settingsThemeSystem => 'Hệ thống';

  @override
  String get settingsThemeLight => 'Sáng';

  @override
  String get settingsThemeDark => 'Tối';

  @override
  String get settingsAdvancedThemeTitle => 'Tuỳ chỉnh nâng cao';

  @override
  String get settingsAdvancedThemeSubtitle =>
      'Màu nền, màu chữ, ảnh nền, màu chủ đề.';

  @override
  String get settingsCsvExportTitle => 'Xuất CSV';

  @override
  String get settingsCsvExportSubtitle =>
      'Lưu ví, giao dịch, danh mục, giao diện và từ khoá gợi ý ra một file CSV.';

  @override
  String get settingsCsvShareSubject => 'MyFinance — sao lưu CSV';

  @override
  String get settingsCsvImportTitle => 'Nhập CSV';

  @override
  String get settingsCsvImportSubtitle =>
      'Nhập ví và giao dịch từ file CSV. Ví trùng id được giữ nguyên; giao dịch trùng id được cập nhật.';

  @override
  String get settingsKeywordLibraryTitle => 'Thư viện từ khoá';

  @override
  String get settingsKeywordLibrarySubtitle =>
      'Sửa từ khoá và danh mục gợi ý khi nhập mô tả.';

  @override
  String get settingsAboutSubtitle =>
      'Phiên bản 0.2 · Hoàn toàn ngoại tuyến · Chỉ dùng VND.';

  @override
  String get settingsListenerPermTitle => 'Cấp quyền nghe thông báo';

  @override
  String get settingsListenerPermSubtitle =>
      'Mở cài đặt hệ thống để bật quyền cho dịch vụ chụp thông báo ngân hàng (BankCaptureService).';

  @override
  String get settingsSeenPackagesTitle => 'Gói ứng dụng đã thấy';

  @override
  String get settingsSeenPackagesSubtitle =>
      'Xem tên gói của các ứng dụng đã gửi thông báo — dùng để xác minh hằng số BankPackages.';

  @override
  String settingsExportFailed(String error) {
    return 'Xuất CSV thất bại: $error';
  }

  @override
  String get settingsCsvImportConfirmTitle => 'Nhập dữ liệu từ CSV?';

  @override
  String get settingsCsvImportConfirmBody =>
      'Ví có id đã tồn tại sẽ được giữ nguyên. Giao dịch có id đã tồn tại sẽ được cập nhật theo file CSV; giao dịch mới sẽ được thêm vào.';

  @override
  String get settingsCsvImportConfirmAction => 'Nhập';

  @override
  String get settingsCsvWrongFileType => 'Vui lòng chọn một file .csv.';

  @override
  String csvImportResult(
      int walletsAdded, int walletsSkipped, int txnsAdded, int txnsUpdated) {
    return '$walletsAdded ví mới ($walletsSkipped bỏ qua), $txnsAdded giao dịch mới, $txnsUpdated giao dịch đã cập nhật.';
  }

  @override
  String settingsImportFailed(String error) {
    return 'Nhập CSV thất bại: $error';
  }

  @override
  String get settingsNotifPermTitle => 'Cần quyền thông báo';

  @override
  String get settingsNotifPermBody =>
      'Quyền thông báo đã bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt ứng dụng.';

  @override
  String get settingsNotNow => 'Không phải bây giờ';

  @override
  String get settingsOpenSettings => 'Mở cài đặt';

  @override
  String get settingsCurrencySymbolFieldLabel => 'Ký hiệu';

  @override
  String get settingsNoPackagesSeen =>
      'Chưa có gói nào. Cấp quyền nghe thông báo và chờ ứng dụng ngân hàng gửi thông báo.';

  @override
  String get settingsPackagesHint =>
      'Dùng các tên gói này để xác minh BankPackages.';

  @override
  String get keywordEditorTitle => 'Từ khoá gợi ý';

  @override
  String get keywordEditorEmpty => 'Chưa có từ khoá nào.';

  @override
  String get keywordEditorSaved => 'Đã lưu thư viện từ khoá.';

  @override
  String get keywordEditorAddTitle => 'Thêm từ khoá';

  @override
  String get keywordEditorKeywordField => 'Từ khoá';

  @override
  String get keywordEditorWeightField => 'Trọng số (1–10)';

  @override
  String get categoriesTitle => 'Danh mục';

  @override
  String get categoriesAddSpending => 'Thêm chi tiêu';

  @override
  String get categoriesAddEarning => 'Thêm thu nhập';

  @override
  String get categoriesAddSpendingTitle => 'Thêm danh mục chi tiêu';

  @override
  String get categoriesAddEarningTitle => 'Thêm danh mục thu nhập';

  @override
  String get categoriesNameField => 'Tên danh mục';

  @override
  String get categoriesThresholdFieldOptional =>
      'Ngưỡng tự động sao (₫, tùy chọn)';

  @override
  String get categoriesEmptySpending => 'Chưa có danh mục chi tiêu.';

  @override
  String get categoriesEmptyEarning => 'Chưa có danh mục thu nhập.';

  @override
  String categoriesThresholdSubtitle(String threshold) {
    return 'Tự động sao > $threshold';
  }

  @override
  String get categoriesNoThreshold => 'Không tự động sao';

  @override
  String get categoriesArchiveTooltip => 'Lưu trữ danh mục';

  @override
  String get categoriesEditTitle => 'Sửa danh mục';

  @override
  String get categoriesThresholdFieldEdit =>
      'Ngưỡng tự động sao (₫, để trống = tắt)';

  @override
  String categoriesArchiveConfirmTitle(String label) {
    return 'Lưu trữ \"$label\"?';
  }

  @override
  String get categoriesArchiveConfirmBody =>
      'Danh mục sẽ ẩn khỏi lựa chọn nhưng giao dịch cũ vẫn giữ nguyên.';

  @override
  String get categoriesArchiveConfirmAction => 'Lưu trữ';

  @override
  String get themeTitle => 'Tuỳ chỉnh giao diện';

  @override
  String get themeResetAction => 'Đặt lại';

  @override
  String get themeColorsSection => 'Màu sắc';

  @override
  String get themeSeedColorTitle => 'Màu chủ đề';

  @override
  String get themeSeedColorSubtitle =>
      'Ảnh hưởng tới nút, thanh tiêu đề và toàn bộ bảng màu.';

  @override
  String get themeBgColorTitle => 'Màu nền ứng dụng';

  @override
  String get themeBgColorSubtitle =>
      'Màu nền của màn hình. \"Tự động\" dùng màu mặc định theo chế độ sáng/tối.';

  @override
  String get themeFontColorTitle => 'Màu chữ';

  @override
  String get themeFontColorSubtitle =>
      '\"Tự động\" theo chế độ sáng/tối. Cẩn thận khi chọn màu tương phản thấp.';

  @override
  String get themeBgImageSection => 'Ảnh nền';

  @override
  String get themeBgImagePickTitle => 'Chọn ảnh nền';

  @override
  String get themeBgImagePickSubtitle =>
      'Ảnh hiển thị phía sau toàn bộ màn hình.';

  @override
  String get themeBgImageNotFound => 'Không tìm thấy ảnh';

  @override
  String get themeBgImageDeleteTitle => 'Xoá ảnh nền';

  @override
  String get themeBgImageNote =>
      'Khi dùng ảnh nền, nền ứng dụng sẽ tự động trong suốt để hiện ảnh phía sau.';

  @override
  String get themeResetConfirmTitle => 'Đặt lại giao diện?';

  @override
  String get themeResetConfirmBody =>
      'Màu chủ đề, màu nền, màu chữ, ảnh nền và biểu tượng tuỳ chỉnh sẽ trở về mặc định.';

  @override
  String get themeColorAuto => 'Tự động';

  @override
  String get themeHexLabel => 'Mã màu Hex';

  @override
  String get themeHexError => 'Mã không hợp lệ (cần 6 ký tự)';

  @override
  String get themeIconsSection => 'Biểu tượng';

  @override
  String get themeIconsHint =>
      'Ảnh vuông, nền trong suốt. Tối thiểu 128×128, khuyến nghị 256×256.';

  @override
  String get themeIconGroupNav => 'Điều hướng';

  @override
  String get themeIconGroupFab => 'Nút thêm nhanh';

  @override
  String get themeIconGroupType => 'Loại giao dịch';

  @override
  String get themeIconGroupStar => 'Đánh dấu sao';

  @override
  String get themeIconGroupWallet => 'Loại ví';

  @override
  String get themeIconSlotNavWallets => 'Ví (thanh điều hướng)';

  @override
  String get themeIconSlotNavTransactions => 'Giao dịch (thanh điều hướng)';

  @override
  String get themeIconSlotNavAnalytics => 'Thống kê (thanh điều hướng)';

  @override
  String get themeIconSlotNavSettings => 'Cài đặt (thanh điều hướng)';

  @override
  String get themeIconSlotFabAdd => 'Nút thêm (FAB)';

  @override
  String get themeIconSlotTypeSpending => 'Biểu tượng chi tiêu';

  @override
  String get themeIconSlotTypeEarning => 'Biểu tượng thu nhập';

  @override
  String get themeIconSlotTypeTransfer => 'Biểu tượng chuyển khoản';

  @override
  String get themeIconSlotStar => 'Biểu tượng sao';

  @override
  String get themeIconSlotWalletCash => 'Biểu tượng ví tiền mặt';

  @override
  String get themeIconSlotWalletBank => 'Biểu tượng ví ngân hàng';

  @override
  String get themeIconResetTooltip => 'Đặt lại biểu tượng mặc định';

  @override
  String get capturesTitle => 'Thông báo ngân hàng';

  @override
  String get capturesEmpty => 'Không có thông báo nào cần xem.';

  @override
  String get capturesNeedsReview => 'Cần xem lại';

  @override
  String get capturesUnparsed => 'Chưa đọc được';

  @override
  String get captureConfirmManualTitle => 'Nhập thủ công';

  @override
  String get captureConfirmTitle => 'Xác nhận giao dịch';

  @override
  String get captureConfirmDismissAction => 'Bỏ qua';

  @override
  String get captureConfirmUnparsedBanner => 'Thông báo chưa đọc được tự động';

  @override
  String get captureConfirmWalletField => 'Ví *';

  @override
  String get captureConfirmCategoryNone => '— Bỏ qua —';

  @override
  String get captureConfirmTimeLabel => 'Thời gian giao dịch';

  @override
  String get captureConfirmRawContentLabel => 'Nội dung thông báo';

  @override
  String get captureConfirmPickWallet => 'Vui lòng chọn ví.';

  @override
  String get captureConfirmDismissConfirmTitle => 'Bỏ qua thông báo này?';

  @override
  String get captureConfirmDismissConfirmBody =>
      'Thông báo sẽ không tạo giao dịch nào.';

  @override
  String get notifCaptureChannelName => 'Thông báo giao dịch ngân hàng';

  @override
  String get notifCaptureChannelDescription =>
      'Báo khi có giao dịch ngân hàng mới được ghi nhận';

  @override
  String get notifCaptureTitle => 'Giao dịch ngân hàng mới';

  @override
  String notifCaptureBody(String amount, String wallet) {
    return 'Có giao dịch $amount vào $wallet';
  }

  @override
  String notifCaptureBodyNoWallet(String amount) {
    return 'Có giao dịch $amount, chưa xác định ví';
  }

  @override
  String get notifCaptureBodyUnparsed =>
      'Có một thông báo ngân hàng cần bạn xác nhận thủ công';
}
