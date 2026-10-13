class ReviewSettings {
  final bool notificationsEnabled;
  final int notificationHour;
  final int notificationMinute;
  final String reviewMode;

  const ReviewSettings({
    this.notificationsEnabled = true,
    this.notificationHour = 9,
    this.notificationMinute = 0,
    this.reviewMode = 'due',
  });

  ReviewSettings copyWith({
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    String? reviewMode,
  }) =>
      ReviewSettings(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        notificationHour: notificationHour ?? this.notificationHour,
        notificationMinute: notificationMinute ?? this.notificationMinute,
        reviewMode: reviewMode ?? this.reviewMode,
      );
}
