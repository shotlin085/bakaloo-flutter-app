import 'package:flutter/widgets.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Maps each icon_key the backend can send (nav-buttons.schema.js's
/// NAV_BUTTON_ICON_KEYS — kept in sync by hand) to the Fill-weight Phosphor
/// icon the dashboard's picker previewed. Every entry verified against the
/// installed phosphoricons_flutter package before being added — an
/// unrecognized key (a stale app build vs. a newer backend enum) falls
/// back to [PhosphorIcons.starFill] rather than crashing.
const Map<String, IconData> navButtonIcons = <String, IconData>{
  'gift': PhosphorIcons.giftFill,
  'gameController': PhosphorIcons.gameControllerFill,
  'crown': PhosphorIcons.crownFill,
  'crownSimple': PhosphorIcons.crownSimpleFill,
  'star': PhosphorIcons.starFill,
  'starFour': PhosphorIcons.starFourFill,
  'sparkle': PhosphorIcons.sparkleFill,
  'fire': PhosphorIcons.fireFill,
  'rocket': PhosphorIcons.rocketFill,
  'rocketLaunch': PhosphorIcons.rocketLaunchFill,
  'trophy': PhosphorIcons.trophyFill,
  'medal': PhosphorIcons.medalFill,
  'target': PhosphorIcons.targetFill,
  'ticket': PhosphorIcons.ticketFill,
  'confetti': PhosphorIcons.confettiFill,
  'diamond': PhosphorIcons.diamondFill,
  'shieldStar': PhosphorIcons.shieldStarFill,
  'moonStars': PhosphorIcons.moonStarsFill,
  'house': PhosphorIcons.houseFill,
  'basket': PhosphorIcons.basketFill,
  'bag': PhosphorIcons.bagFill,
  'handbag': PhosphorIcons.handbagFill,
  'storefront': PhosphorIcons.storefrontFill,
  'tag': PhosphorIcons.tagFill,
  'percent': PhosphorIcons.percentFill,
  'lightning': PhosphorIcons.lightningFill,
  'megaphone': PhosphorIcons.megaphoneFill,
  'bell': PhosphorIcons.bellFill,
  'heart': PhosphorIcons.heartFill,
  'shoppingBag': PhosphorIcons.shoppingBagFill,
  'shoppingCart': PhosphorIcons.shoppingCartFill,
  'coin': PhosphorIcons.coinFill,
  'wallet': PhosphorIcons.walletFill,
  'image': PhosphorIcons.imageFill,
  'globe': PhosphorIcons.globeFill,
  'browser': PhosphorIcons.browserFill,
  'deviceMobile': PhosphorIcons.deviceMobileFill,
};

IconData resolveNavButtonIcon(String iconKey) =>
    navButtonIcons[iconKey] ?? PhosphorIcons.starFill;
