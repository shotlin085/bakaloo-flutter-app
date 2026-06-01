# Android Product UI — Visual QA Screenshots

Captured on Android emulator `Medium_Phone_API_36.1` (`emulator-5554`, Android 16)
against the live dev backend `https://bakaloo-api.shotlin.in`.

Emulator launched with `-dns-server 8.8.8.8,8.8.4.4` to fix an emulator DNS
resolution failure (the app's "Service unavailable" screen was caused by the
emulator being unable to resolve any hostname; the backend itself returns 200).

## Files
- 01-home-grid-before.png — Home product grid before adding any item
- 02-home-grid-scrolled.png — Home product grid scrolled mid-list
- 03-option-sheet-before-add.png — Option bottom sheet before adding
- 04-option-sheet-after-add.png — Option bottom sheet after adding one option
- 04b-option-sheet-after-two.png — Option bottom sheet after adding two options
- 05-view-cart-pill.png — Home with floating View Cart pill visible
- 06-cart-options.png — Cart page showing selected options
- 07-category-grid.png — Category product grid (if available)
- 08-search-results.png — Search results (if available)
- 09-product-detail.png — Product detail related products (if available)
