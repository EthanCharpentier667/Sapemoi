# Sapemoi 👗👔

Your smart wardrobe companion powered by AI. Track your clothes, generate perfect outfits, and never run out of style ideas!

## ✨ Features

### 📸 Smart Clothing Detection
- Take a photo or scan barcodes/QR codes from clothing tags
- AI-powered analysis extracts:
  - Brand, product name, and type
  - Color palette with percentages
  - Specific clothing category
- **Universal barcode support** (EAN-8, EAN-13, UPC-A, GTIN-14)
- **Multi-API product lookup** for comprehensive product data
- **QR code parsing** with automatic brand detection

### 🔍 Intelligent Barcode Scanner
- Detects barcode type automatically (EAN, UPC, GTIN, QR)
- **GS1 prefix mapping** for instant brand identification
- **3-tier API cascade** for maximum product data coverage:
  1. **UPCItemDB** (free, 100 req/day)
  2. **Open Food Facts** (free, unlimited)
  3. **Barcode Lookup** (optional, requires API key)
- **AI fallback** for QR codes and product URLs
- Domain-based brand extraction from URLs

### 🎯 Intelligent Outfit Generation
- Smart outfit matching based on:
  - Color compatibility
  - Style coherence
  - Wear frequency (prioritizes unworn items)
- Generates up to 10 diverse outfits
- Compatibility scoring system
- Bold mode for adventurous combinations

### 🎨 Manual Outfit Creator
- Drag & drop interface
- Optional slots (headwear, outerwear, accessories)
- Auto-generate best outfit from your wardrobe
- Real-time compatibility feedback
- Mark outfits as worn for tracking

### 📊 Wardrobe Analytics
- Track wear count for each item
- Last worn dates
- Estimated wardrobe value
- Usage patterns

### 🔐 Authentication
- Google Sign-In
- Apple Sign-In (iOS)
- Cloud sync with Firebase

## 🏷️ Barcode & Brand Support

### Barcode Types
- **EAN-8** (8 digits)
- **UPC-A** (12 digits)
- **EAN-13** (13 digits)
- **GTIN-14** (14 digits)
- **QR Codes** with product URLs

### Brand Detection
The app automatically detects brands through:
- **GS1 company prefixes** embedded in barcodes
- **Domain extraction** from QR code URLs
- **API product databases** for detailed information

Supported fashion brands include:
**Fast Fashion:** Zara, H&M, Uniqlo, Pull&Bear, Bershka, Stradivarius, Massimo Dutti, Mango, Gap, Reserved

**Sportswear:** Nike, Adidas, Puma, Reebok, New Balance, Vans, Converse, Lululemon

**Men's Fashion:** Celio, Jules

**Premium:** Lacoste, Levi's

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.10+
- Android Studio / Xcode
- Firebase project configured

### Installation

1. Clone the repository
```bash
git clone https://github.com/EthanCharpentier667/Sapemoi.git
cd sapemoi
```

2. Install dependencies
```bash
flutter pub get
cd ios && pod install && cd ..
```

3. Configure Firebase
- Add `google-services.json` (Android) to `android/app/`
- Add `GoogleService-Info.plist` (iOS) to `ios/Runner/`

4. (Optional) Configure Barcode Lookup API
- Sign up at [Barcode Lookup](https://www.barcodelookup.com/)
- Run with API key:
```bash
flutter run --dart-define=BARCODE_LOOKUP_API_KEY=your_api_key
```

5. Run the app
```bash
flutter run
```

## 🏗️ Architecture

```
lib/
├── main.dart              # App entry point
├── models.dart            # Data models (Clothing, Outfit, etc.)
├── db_manager.dart        # SQLite database operations
├── network_manager.dart   # AI API communication
├── outfit_generator.dart  # Smart outfit matching algorithm
├── login_page.dart        # Authentication UI
├── profile_page.dart      # User profile & settings
└── brands/
    ├── brand_parser.dart  # Universal barcode/QR scanner
    └── brands_init.dart   # Scanner initialization
```

### Barcode Scanner Flow
1. **Scan** → Detect barcode type (EAN/UPC/GTIN/QR)
2. **EAN Barcodes** → GS1 prefix lookup → API cascade (3 APIs)
3. **QR Codes** → Extract domain → Extract product code → AI analysis
4. **Return** → BrandInfo with product details

## 🛠️ Tech Stack

- **Frontend:** Flutter 3.10+ (Material 3)
- **Database:** SQLite (sqflite)
- **Authentication:** Firebase Auth
- **Barcode Scanning:** mobile_scanner 7.1.3
- **Image Processing:** image_picker
- **AI Analysis:** Custom API (clothing detection & URL parsing)
- **Product APIs:**
  - UPCItemDB (free tier)
  - Open Food Facts (free)
  - Barcode Lookup (optional)

## 📝 API Configuration

### Required
- Firebase (authentication & cloud sync)
- Custom AI API (image analysis)

### Optional
- Barcode Lookup API key (for enhanced product data)

Set API keys via environment variables:
```bash
flutter run --dart-define=BARCODE_LOOKUP_API_KEY=your_key
```

## 📱 Screenshots

Coming soon!

## 🤝 Contributing

This is a personal project, but suggestions are welcome!

## 📄 License

This project is private.

## 👨‍💻 Author

Ethan Charpentier - [@epitech.eu](mailto:ethan.charpentier@epitech.eu)

---

Made with ❤️ using Flutter
