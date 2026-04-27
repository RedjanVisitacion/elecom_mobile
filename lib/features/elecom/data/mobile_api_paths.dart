import '../../../core/config/api_config.dart';

class MobileApiPaths {
  static String get base => '${ApiConfig.baseUrl}/api/mobile';
  static String get rootApi => '${ApiConfig.baseUrl}/api';

  static String get electionWindow => '$base/election/window/';
  static String get ballot => '$base/ballot/';
  static String get voteStatus => '$base/vote/status/';
  static String get voteReceipt => '$base/vote/receipt/';
  static String get voteSubmit => '$base/vote/submit/';
  static String get results => '$base/results/';

  static String get accountProfile => '$base/account/profile/';
  static String get accountProfilePhoto => '$base/account/profile/photo/';
  static String get accountProfileUpdate => '$base/account/profile/update/';
  static String get accountProfilePassword => '$base/account/profile/password/';
  static String get accountAppRating => '$base/account/app-rating/';
  static String get notifications => '$base/notifications/';
  static String get notificationsCreate => '$base/notifications/create/';
  static String get notificationsRead => '$base/notifications/read/';
  static String get notificationsReadAll => '$base/notifications/read-all/';
  static String get notificationsUnread => '$base/notifications/unread/';
  static String get notificationsPin => '$base/notifications/pin/';
  static String get notificationsDelete => '$base/notifications/delete/';

  static String get networkCheck => '$base/network/check/';

  static String get adminDashboard => '$base/admin/dashboard/';
  static String get adminResults => '$base/admin/results/';
  static String get adminElectionWindow => '$base/admin/election-window/';
  static String get adminReportsSummary => '$base/admin/reports/summary/';
  static String get adminResetStatus => '$base/admin/reset/status/';
  static String get adminResetVotes => '$base/admin/reset/votes/';
  static String get adminResetNotifications => '$base/admin/reset/notifications/';
  static String get adminNetworkSettings => '$base/admin/network-settings/';
  static String get adminNetworkLogs => '$base/admin/network-logs/';
  static String get adminCloudinarySignature => '$base/admin/cloudinary/signature/';
  static String get cloudinaryProfileSignature => '$rootApi/cloudinary/signature/?type=profile_photo';
  static String get adminCandidatesList => '$base/admin/candidates/list/';
  static String get adminCandidatesDetail => '$base/admin/candidates/detail/';
  static String get adminCandidatesCreate => '$base/admin/candidates/create/';
  static String get adminCandidatesUpdate => '$base/admin/candidates/update/';
  static String get adminCandidatesDelete => '$base/admin/candidates/delete/';
  static String get adminCandidatesBulkDelete => '$base/admin/candidates/bulk-delete/';
}
