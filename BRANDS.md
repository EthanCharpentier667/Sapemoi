# Supported Brands for QR Code Scanning

Sapemoi supports automatic brand and product detection for the following 22 major fashion brands:

## 🏷️ Fast Fashion
1. **Zara** - QR codes and product URLs
2. **H&M** - Product codes and URLs
3. **Uniqlo** - Product codes with color variants
4. **Pull&Bear** - Product URLs (Inditex group)
5. **Bershka** - Product URLs (Inditex group)
6. **Stradivarius** - Product URLs (Inditex group)
7. **Massimo Dutti** - Product URLs (Inditex group)
8. **Mango** - Product URLs and codes
9. **Gap** - Product URLs and barcodes
10. **Reserved** - Product URLs and codes

## 👟 Sportswear & Sneakers
11. **Nike** - Product codes and URLs
12. **Adidas** - Product codes and URLs
13. **Puma** - Product URLs and barcodes
14. **Reebok** - Product codes and URLs
15. **New Balance** - Product codes and URLs
16. **Vans** - Product codes and URLs
17. **Converse** - Product codes and URLs
18. **Lululemon** - Product URLs with SKU

## 👔 Men's Fashion
19. **Celio** - Product URLs (French brand)
20. **Jules** - Product URLs (French brand)

## 🏆 Premium
21. **Lacoste** - Product codes and URLs
22. **Levi's** - Product codes and URLs

## How it works

When you scan a QR code or barcode:
1. **URL Detection**: If it's a URL, the parser identifies the brand from the domain
2. **Code Extraction**: Product codes, names, and other metadata are extracted from the URL pattern
3. **Barcode Support**: EAN-13 and UPC-A barcodes are supported for most brands
4. **API Fallback**: If the brand is not recognized, the URL is sent to the AI API for analysis
5. **Smart Parsing**: Each brand has custom parsing logic to extract maximum information

## Extracted Information

For each detected item, we try to extract:
- ✅ Brand name
- ✅ Product code/SKU
- ✅ Product name (when available in URL)
- ✅ Color code (for some brands like Uniqlo)
- ✅ Category (when detectable)

## Debug Mode

All parsers include extensive debug logging:
```
========== BRAND PARSER ==========
Input: http://www.zara.com/qr/0828835241803
Detected: URL
Host: www.zara.com
Path: /qr/0828835241803
[Zara] Parsing URL: http://www.zara.com/qr/0828835241803
[Zara] Found product code: 0828835241803
Parsed by: Zara
Result: Brand: Zara, Product: 0828835241803, Name: Zara Item 0828835241803
==================================
```

## Adding New Brands

To add support for a new brand:
1. Create a new file `lib/brands/brandname.dart`
2. Extend `BrandParser` class
3. Implement `parseURL`, `parseBarcode`, and `parseQRCode` methods
4. Register in `lib/brands/brands_init.dart`
5. Update this README
