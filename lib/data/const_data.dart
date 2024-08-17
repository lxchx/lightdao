import 'package:lightdao/ui/page/more/cookies_management.dart';

const List<(String, String)> appIcons = [
  ('appicon.icon_1', 'assets/app_icons/1.png'),
  ('appicon.icon_2', 'assets/app_icons/2.png'),
  ('appicon.icon_3', 'assets/app_icons/3.png'),
  ('appicon.icon_4', 'assets/app_icons/4.png'),
  ('appicon.icon_5', 'assets/app_icons/5.png'),
  ('appicon.icon_6', 'assets/app_icons/6.png'),
];

List<String> appIconsNamesList = [...appIcons.mapIndex<String>((i, namePath) => namePath.$1)];
