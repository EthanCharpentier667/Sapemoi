# Barcode Scanning avec Analyse IA

## Workflow Complet

### 1. Scanner un Code-Barres (EAN-13, UPC, etc.)

Quand l'utilisateur scanne un code-barres :

```
Utilisateur → QR Scanner → Code détecté (ex: 0193659433159)
                              ↓
                     BarcodeScanner.scan()
                              ↓
                  ┌──────────────────────────┐
                  │  Lookup dans 3 APIs :   │
                  │  - UPCItemDB            │
                  │  - Open Food Facts      │
                  │  - Barcode Lookup       │
                  └──────────────────────────┘
                              ↓
                  ┌──────────────────────────┐
                  │ Résultat trouvé :        │
                  │ Brand: "Generic"         │
                  │ Product: "Manchester... │
                  │ Code: 0193659433159      │
                  │ needsAIAnalysis: true    │
                  └──────────────────────────┘
                              ↓
              Message à l'utilisateur : 
              "✅ Generic detected!"
              "📸 Now take a photo for color/type analysis"
```

### 2. Prendre une Photo du Produit

L'utilisateur prend ensuite une photo du produit :

```
Utilisateur → Camera/Gallery → Photo capturée
                                    ↓
                           Base64 encodée
                                    ↓
                            _addClothing()
                                    ↓
                  ┌──────────────────────────────────┐
                  │ Si _scannedBarcodeInfo existe:   │
                  │                                   │
                  │ analyzeWithBarcodeInfo()          │
                  │   ↓                               │
                  │ POST /analyze_with_info           │
                  │   {                               │
                  │     base64: "...",                │
                  │     product_code: "0193659...",   │
                  │     product_name: "Manchester..." │
                  │   }                               │
                  └──────────────────────────────────┘
                                    ↓
                  ┌──────────────────────────────────┐
                  │ OpenAI GPT-4 Vision (SANS Lens)  │
                  │                                   │
                  │ Prompt:                           │
                  │ "I already know it's: Manchester  │
                  │  United Jersey. Identify:         │
                  │  - Type (top/bottom/etc)          │
                  │  - SpecificType (jersey/tshirt)   │
                  │  - Colors (RGB + percentages)"    │
                  └──────────────────────────────────┘
                                    ↓
                  ┌──────────────────────────────────┐
                  │ Réponse IA :                      │
                  │                                   │
                  │ Type: top                         │
                  │ SpecificType: jersey              │
                  │ Colors: 0,0,0,60; 255,255,255,25; │
                  │         200,16,46,15              │
                  │ Brand: Nike                       │
                  │ Product: Manchester United...     │
                  └──────────────────────────────────┘
                                    ↓
                          Clothing object créé :
                          - brand: "Nike" (ou "Generic" si IA échoue)
                          - productName: "Manchester United..."
                          - type: "top"
                          - specificType: "jersey"
                          - colors: [noir 60%, blanc 25%, rouge 15%]
                                    ↓
                            Sauvegardé dans DB
```

## Différences Clés

### Ancien Workflow (Sans Barcode)
```
Photo → Google Lens → IA détecte tout (brand/product/type/colors)
```
**Problème** : Google Lens peut se tromper sur le brand/product

### Nouveau Workflow (Avec Barcode)
```
Barcode → API lookup (brand/product fiables) → Photo → IA détecte uniquement type/colors
```
**Avantage** : 
- Brand/Product garantis par les APIs de codes-barres
- IA se concentre uniquement sur l'analyse visuelle (couleurs, type)
- Pas de Google Lens nécessaire

## Endpoints API

### POST /analyze_with_info
Nouveau endpoint qui analyse l'image SANS Google Lens.

**Request:**
```json
{
  "base64": "image en base64",
  "product_code": "0193659433159",
  "product_name": "Manchester United Ronaldo #7 Jersey"
}
```

**Response:** (même format que /analyze)
```json
{
  "choices": [{
    "message": {
      "content": "Type: top\nSpecificType: jersey\nColors: 0,0,0,60; 255,255,255,25; 200,16,46,15\nBrand: Nike\nProduct: Manchester United Ronaldo #7 Jersey"
    }
  }]
}
```

## Déploiement

Ajouter le nouveau endpoint à ton serveur Express sur Render :

```javascript
// Dans ton server.js principal, ajoute :
const analyzeWithInfo = require('./ENDPOINT_analyze_with_info');
app.use(analyzeWithInfo);
```

Ou merge le code dans ton fichier existant.

## Test Manuel

1. Scanner un code-barres EAN-13 (ex: produit Nike)
2. Vérifier que le message "📸 Now take a photo" apparaît
3. Prendre une photo du produit
4. Vérifier les logs : "🤖 Analyzing with barcode info: ..."
5. Vérifier que le clothing est créé avec les bonnes couleurs/type

## Logs de Debug

```
flutter: Type: EAN-13
flutter: Detected: EAN/GTIN barcode
flutter: [API] UPCItemDB lookup...
flutter: [API] ✅ UPCItemDB found: Manchester United Ronaldo #7 ...
flutter: ✅ Product found via API
flutter: ⏭️  Will send to AI for color/type analysis
flutter: ✅ Brand detected: Generic
flutter: 📦 Product code: 0193659433159
flutter: 🏷️ Product name: Manchester United Ronaldo #7 ...

[Utilisateur prend photo]

flutter: 🤖 Analyzing with barcode info: Manchester United Ronaldo #7 ...
flutter: 📥 Response status: 200
flutter: ✅ AI analysis complete
flutter: ✅ AI Parsed - type: top, specificType: jersey, colors: 3
```
