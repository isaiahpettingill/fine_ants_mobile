import 'package:flutter/material.dart';

import 'account_icon_choices.dart';

class AccountIconGroup {
  final String name;
  final Map<String, IconData> icons;
  const AccountIconGroup(this.name, this.icons);
}

Map<String, IconData> _pick(List<String> keys) {
  final out = <String, IconData>{};
  for (final k in keys) {
    final v = kAccountIconChoices[k];
    if (v != null) out[k] = v;
  }
  return out;
}

const _finance = [
  'savings',
  'account_balance',
  'account_balance_wallet',
  'credit_card',
  'attach_money',
  'monetization_on',
  'paid',
  'payments',
  'request_quote',
  'receipt_long',
  'receipt',
  'point_of_sale',
  'price_check',
  'price_change',
  'local_atm',
  'card_giftcard',
  'trending_up',
  'trending_down',
  'currency_exchange',
  'currency_rupee',
  'currency_pound',
  'currency_yen',
  'currency_ruble',
  'currency_lira',
  'currency_franc',
  'currency_yuan',
];

const _crypto = [
  'currency_bitcoin',
  'token',
];

const _commerce = [
  'shopping_bag',
  'shopping_cart',
  'store',
  'storefront',
  'sell',
  'inventory',
  'inventory_2',
  'local_mall',
  'qr_code_scanner',
  'local_shipping',
  'request_page',
];

const _business = [
  'business_center',
  'corporate_fare',
  'work',
  'work_outline',
  'analytics',
  'assessment',
  'bar_chart',
  'pie_chart_outline',
  'account_tree',
  'business',
  'calculate',
];

const _relationships = [
  'favorite',
  'favorite_border',
  'people',
  'group',
  'group_add',
  'emoji_people',
  'mood',
  'mood_bad',
  'emoji_emotions',
];

const _fun = [
  'sports_esports',
  'casino',
  'celebration',
  'beach_access',
  'cake',
  'music_note',
  'local_cafe',
  'pets',
  'emoji_nature',
  'park',
  'cruelty_free',
];

const _religious = [
  'church',
  'mosque',
  'synagogue',
  'temple_hindu',
  'temple_buddhist',
];

const _communications = [
  'phone',
  'call',
  'phone_iphone',
  'smartphone',
  'email',
  'alternate_email',
  'sms',
  'chat',
  'chat_bubble',
  'forum',
  'contact_phone',
];

const _travel = [
  'flight',
  'flight_takeoff',
  'flight_land',
  'local_airport',
  'luggage',
  'hotel',
  'map',
  'explore',
  'directions_car',
  'directions_bus',
  'directions_train',
  'directions_bike',
  'directions_boat',
  'directions_walk',
];

const _tech = [
  'computer',
  'laptop',
  'devices',
  'router',
  'memory',
  'desktop_windows',
  'tablet_mac',
  'android',
];

final List<AccountIconGroup> kAccountIconGroups = [
  AccountIconGroup('Finance', _pick(_finance)),
  AccountIconGroup('Crypto', _pick(_crypto)),
  AccountIconGroup('Commerce', _pick(_commerce)),
  AccountIconGroup('Business', _pick(_business)),
  AccountIconGroup('Relationships', _pick(_relationships)),
  AccountIconGroup('Fun', _pick(_fun)),
  AccountIconGroup('Religious', _pick(_religious)),
  AccountIconGroup('Comms', _pick(_communications)),
  AccountIconGroup('Travel', _pick(_travel)),
  AccountIconGroup('Tech', _pick(_tech)),
];

