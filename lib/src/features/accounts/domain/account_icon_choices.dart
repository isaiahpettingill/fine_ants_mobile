import 'package:flutter/material.dart';

/// Canonical list of available account icons.
/// Keys are stored in the database; values are the corresponding Material icons.
/// Ordered with financial icons first for convenience.
const Map<String, IconData> kAccountIconChoices = <String, IconData>{
  // Financial / money first
  'savings': Icons.savings,
  'account_balance': Icons.account_balance,
  'account_balance_wallet': Icons.account_balance_wallet,
  'credit_card': Icons.credit_card,
  'attach_money': Icons.attach_money,
  'monetization_on': Icons.monetization_on,
  'paid': Icons.paid,
  'payments': Icons.payments,
  'request_quote': Icons.request_quote,
  'receipt_long': Icons.receipt_long,
  'receipt': Icons.receipt,
  'point_of_sale': Icons.point_of_sale,
  'price_check': Icons.price_check,
  'price_change': Icons.price_change,
  'local_atm': Icons.local_atm,
  'card_giftcard': Icons.card_giftcard,
  'shopping_bag': Icons.shopping_bag,
  'shopping_cart': Icons.shopping_cart,
  'store': Icons.store,
  'storefront': Icons.storefront,
  'sell': Icons.sell,
  'inventory': Icons.inventory,
  'inventory_2': Icons.inventory_2,
  'trending_up': Icons.trending_up,
  'trending_down': Icons.trending_down,

  // Business / work
  'business_center': Icons.business_center,
  'corporate_fare': Icons.corporate_fare,
  'work': Icons.work,
  'work_outline': Icons.work_outline,
  'analytics': Icons.analytics,
  'assessment': Icons.assessment,
  'bar_chart': Icons.bar_chart,
  'pie_chart_outline': Icons.pie_chart_outline,
  'account_tree': Icons.account_tree,
  'business': Icons.business,
  'calculate': Icons.calculate,

  // Commerce / logistics
  'local_mall': Icons.local_mall,
  'qr_code_scanner': Icons.qr_code_scanner,
  'local_shipping': Icons.local_shipping,
  'request_page': Icons.request_page,

  // Relationship-themed
  'favorite': Icons.favorite,
  'favorite_border': Icons.favorite_border,
  'people': Icons.people,
  'group': Icons.group,
  'group_add': Icons.group_add,
  'emoji_people': Icons.emoji_people,

  // Fun
  'sports_esports': Icons.sports_esports,
  'casino': Icons.casino,
  'celebration': Icons.celebration,
  'beach_access': Icons.beach_access,
  'cake': Icons.cake,
  'music_note': Icons.music_note,
  'local_cafe': Icons.local_cafe,
  'pets': Icons.pets,
  'emoji_nature': Icons.emoji_nature,
  'park': Icons.park,

  // Religious-themed (where supported by current Material set)
  'church': Icons.church,
  'mosque': Icons.mosque,
  'synagogue': Icons.synagogue,
  'temple_hindu': Icons.temple_hindu,
  'temple_buddhist': Icons.temple_buddhist,

  // Communications
  'phone': Icons.phone,
  'call': Icons.call,
  'phone_iphone': Icons.phone_iphone,
  'smartphone': Icons.smartphone,
  'email': Icons.email,
  'alternate_email': Icons.alternate_email,
  'sms': Icons.sms,
  'chat': Icons.chat,
  'chat_bubble': Icons.chat_bubble,
  'forum': Icons.forum,
  'contact_phone': Icons.contact_phone,

  // Travel & transportation
  'flight': Icons.flight,
  'flight_takeoff': Icons.flight_takeoff,
  'flight_land': Icons.flight_land,
  'local_airport': Icons.local_airport,
  'luggage': Icons.luggage,
  'hotel': Icons.hotel,
  'map': Icons.map,
  'explore': Icons.explore,
  'directions_car': Icons.directions_car,
  'directions_bus': Icons.directions_bus,
  'directions_train': Icons.directions_train,
  'directions_bike': Icons.directions_bike,
  'directions_boat': Icons.directions_boat,
  'directions_walk': Icons.directions_walk,

  // Tech
  'computer': Icons.computer,
  'laptop': Icons.laptop,
  'devices': Icons.devices,
  'router': Icons.router,
  'memory': Icons.memory,
  'desktop_windows': Icons.desktop_windows,
  'tablet_mac': Icons.tablet_mac,
  'android': Icons.android,
  // 'apple': Icons.apple, // Uncomment if available in your Flutter SDK
  // 'google': Icons.google, // Uncomment if available in your Flutter SDK

  // Crypto / currencies
  'currency_bitcoin': Icons.currency_bitcoin,
  'token': Icons.token,
  'currency_exchange': Icons.currency_exchange,
  'currency_rupee': Icons.currency_rupee,
  'currency_pound': Icons.currency_pound,
  'currency_yen': Icons.currency_yen,
  'currency_ruble': Icons.currency_ruble,
  'currency_lira': Icons.currency_lira,
  'currency_franc': Icons.currency_franc,
  'currency_yuan': Icons.currency_yuan,

  // Ethical / fun extras
  'cruelty_free': Icons.cruelty_free,
  'emoji_emotions': Icons.emoji_emotions,
  'mood': Icons.mood,
  'mood_bad': Icons.mood_bad,
};
