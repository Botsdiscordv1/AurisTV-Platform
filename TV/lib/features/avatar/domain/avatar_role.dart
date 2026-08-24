enum AvatarRole {
  main,
  supporting,
  antagonist;

  static AvatarRole fromJson(String? value) {
    switch (value) {
      case 'main':
        return AvatarRole.main;
      case 'antagonist':
        return AvatarRole.antagonist;
      case 'supporting':
      default:
        return AvatarRole.supporting;
    }
  }
}