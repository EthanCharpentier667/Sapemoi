# Sapemoi

Sapemoi is a digital wardrobe that helps people dress better with the clothes they already own.

Everything starts with a scan. Each scanned garment is identified (type, colours, brand) and added to the user's wardrobe. From there, the app suggests a daily outfit built only from what the user owns, scores it on colour harmony, and keeps track of what is actually worn. Pieces that are never worn can be resold, and new purchases are suggested only when a single piece would unlock many new outfits.

The goal is to fight clothing overconsumption by making the existing wardrobe easier to use.

Sapemoi is developed as a three-year Epitech Innovative Project (EIP) at Epitech Nantes, with the aim of turning it into a company.

## Features

| Area | Status |
| --- | --- |
| Sign-in with Google and Apple (Firebase Auth) | Done |
| Garment scan from camera or gallery, analysed by the backend | Done |
| Wardrobe with type, layer, colours, brand, wear count and estimated value | Done |
| Outfit generator with colour-harmony scoring (basic and multi-layer builder) | Done |
| Wear tracking and recency weighting | Done |
| User style profile (top brands, types and colours) | Done |
| Missing-piece recommendations | Done |
| Outfit feed with posts, likes and comments | Done |
| Reliable garment and brand recognition | In progress, see below |
| Laundry status (washed items are not suggested for a few days) | Planned |
| Resale flow for unworn items | Planned |
| Weather-aware suggestions | Planned |

## Garment recognition

Recognition is the core of the product: the whole experience depends on one quick, accurate scan. The type and colours can be extracted reliably. The brand is the hard part, and it matters because it largely defines a user's style.

The current approach is a single scan analysed by the backend, with a manual correction step when confidence is low. Every correction is meant to feed a shared dataset, so the more garments are scanned, the less often users need to correct anything. We are looking for a visual search solution that can identify garments and brands from a single photo.

## Outfit scoring

Outfits are scored from 0 (best) to 100 based on how layers and colours interact: colour recalls between non-adjacent layers, contrast between touching layers, dominant colours, neutral balance, the number of vivid colours and weighted colour clashes. Outer layers count more because they are the most visible.

The full rules are documented in [OUTFIT_ALGORITHM.md](OUTFIT_ALGORITHM.md) and implemented in `lib/outfit_generator.dart` and `lib/color_utils.dart`.

Known issues:

- `_evaluateNeutralColors` applies the opposite signs to the documentation: an all-neutral outfit gets a bonus (-20) and a neutral outfit with a single colour accent gets a penalty (+15).
- `_detectColorRecalls` builds pair keys in layer order (`i_j`), while `_evaluateColorClashes` looks them up in index order. Some pairs that share a colour recall can still be counted as clashes. Normalising the key as `min_max` fixes it.

## Tech stack

- Mobile app: Flutter (Dart SDK ^3.10), Android and iOS
- Authentication: Firebase Auth with Google Sign-In and Sign in with Apple
- Local storage: sqflite
- Backend: REST API (garment analysis, style estimation, recommendations, wardrobe storage)

## Project structure

```
lib/
  main.dart                  App entry, navigation, scan and garment editing
  models.dart                Clothing, ColorInfo, StyleProfile, OutfitPost, recommendations
  outfit_generator.dart      Outfit scoring
  color_utils.dart           HSL conversion and colour-pair scoring
  recommendation_engine.dart Missing-piece recommendations
  network_manager.dart       Backend API client
  db_manager.dart            Local database and sync
  auth_manager.dart          Firebase authentication
  theme.dart                 Design system (dark theme, violet accent)
  pages/                     Wardrobe, outfit generator, outfit builder, feed, posts, login
  widgets/                   Shared widgets and splash screen
assets/icon/                 App icon and logo
OUTFIT_ALGORITHM.md          Scoring rules
```

## Getting started

Requirements: Flutter SDK with Dart 3.10 or later, Xcode for iOS, Android Studio for Android.

```bash
git clone https://github.com/EthanCharpentier667/Sapemoi.git
cd Sapemoi
flutter pub get
flutter run
```

The backend URL is set in `lib/network_manager.dart` (`NetworkManager.actual`). Firebase is configured through `lib/firebase_options.dart`, `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`.

## Backend endpoints

| Endpoint | Purpose |
| --- | --- |
| `POST /analyze` | Analyse a garment photo (type, layer, colours, brand, product) |
| `POST /analyse_user_style` | Estimate the user's style from their wardrobe |
| `POST /recomands_clothing_items` | Suggest pieces that complete existing outfits |
| `POST /google_search` | Find product references for a recommendation |
| `/db/users`, `/db/clothing`, `/db/outfit` | Users, wardrobe items, worn outfits and statistics |

## Team

Sapemoi is built by students of Epitech Nantes as part of the EIP.
