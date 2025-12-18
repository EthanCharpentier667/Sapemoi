# Outfit Evaluation Algorithm

## Layer System

The outfit evaluation algorithm is based on a **layer system** that represents how clothing items are worn on the body. Each item has a `layer` field that determines its physical position:

### Layer Definitions

- **Layer 0 (Base)**: Underwear, base layers, compression wear, lycra
- **Layer 1 (Main)**: Primary garments like t-shirts, pants, dresses, shorts
- **Layer 2 (Mid-Layer)**: Vests, gilets, cardigans, light jackets
- **Layer 3 (Outerwear)**: Coats, heavy jackets, parkas, overcoats

### Layer Constraints

**Important Rule**: You cannot have the same clothing type on the same layer twice.

#### ✅ Valid Examples:
- Pants (bottom, layer=1) + Lycra (bottom, layer=0) → Different layers, same type = OK
- T-shirt (top, layer=1) + Jacket (outerwear, layer=3) → Different types = OK

#### ❌ Invalid Examples:
- T-shirt (top, layer=1) + Another t-shirt (top, layer=1) → Same type AND same layer = CONFLICT
- Pants (bottom, layer=1) + Shorts (bottom, layer=1) → Same type AND same layer = CONFLICT

## Algorithm Components

The outfit evaluation algorithm analyzes outfits through several key components:

### 1. Color Recall Detection

**Purpose**: Identify when the same color appears on non-adjacent layers, creating visual cohesion.

**How it works**:
- Compares colors across all items in the outfit
- Only counts as "color recall" if the layers are NOT adjacent (diff > 1)
- Example: Red on shoes (layer 1) and red on hat (layer 3) = GOOD (bonus)
- Counter-example: Red on shirt (layer 1) and red on jacket (layer 2) = Adjacent, doesn't count

**Scoring**: Each color recall gives a **-50 point bonus** (lower score = better)

### 2. Adjacent Layer Evaluation

**Purpose**: Analyze color harmony between layers that touch each other physically.

**Layer Adjacency**: Layers N and N+1 are considered adjacent (e.g., layer 1 and layer 2)

**Rules**:
- **Monochrome clash**: If both adjacent items are solid colors (1 hue each) and very similar (hue difference < 30°) → **+45 penalty**
  - Why bad: Too matchy-matchy, lacks contrast
  
- **Subtle recall**: If one item has a minor color that matches a major color on the adjacent item → **-25 bonus**
  - Example: Jacket with small red detail (30% red) over shirt that's 60% red
  - Why good: Creates sophisticated visual connection

### 3. Color Dominance Check

**Purpose**: Prevent the same color from overwhelming the outfit.

**How it works**:
- Counts how many items share the same hue (within 30° difference)
- If 3+ items have the same dominant color → **+50 penalty**

**Why**: Too much of one color (except neutrals) looks monotonous

### 4. Neutral Color Balance

**Purpose**: Reward sophisticated use of neutral colors (black, white, gray, beige).

**Rules**:
- All neutral outfit (3+ items, all neutral) → **-20 penalty** (boring)
- Mostly neutral with 1 colored accent → **+15 bonus** (elegant)

### 5. Vibrant Color Limit

**Purpose**: Prevent rainbow outfits.

**How it works**:
- Counts vibrant colors (non-neutral, >30% of item)
- If more than 3 vibrant colors → **+25 penalty per extra color**

### 6. Color Clash Evaluation

**Purpose**: Detect color combinations that don't work well together.

**Visibility Weighting**: Not all items are equally visible, so clashes are weighted:

#### Layer-Based Visibility:
- **Same layer** (layerDiff = 0): 0.5x weight
  - Example: Two items both on layer 1 (unlikely to clash visibly)
  
- **Adjacent layers** (layerDiff = 1): 3.0x weight
  - Example: Shirt (layer 1) and jacket (layer 2)
  - Why: Most visible interaction
  
- **Skip one layer** (layerDiff = 2): 5.0x weight
  - Example: Base layer (0) and mid-layer (2)
  - Why: Very visible when outer layer opens
  
- **Other differences**: 2.0x weight

#### Type-Based Visibility:
- **Coats/Jackets/Manteaux**: 2.0x additional multiplier
  - These are the most dominant visual elements

**Clash Thresholds**:
- Normal mode: Color pair score > 60 = clash
- Bold mode: Color pair score > 100 = clash (more tolerant)

### 7. Recency Weighting

**Purpose**: Encourage wearing items that haven't been worn recently.

**Penalties**:
- Worn < 7 days ago: +15 points per item
- Worn 7-14 days ago: +8 points per item
- Worn 14-30 days ago: +3 points per item

## Final Scoring

### Score Calculation:
1. Start at 0
2. Apply all bonuses/penalties from above
3. Clamp result to 0-100 range

### Validity:
- **Valid outfit**: No clashes AND score < 40
- **Warning outfit**: No clashes BUT score ≥ 40
- **Invalid outfit**: Has color clashes OR type conflicts

### Score Interpretation:
- **0-20**: Excellent outfit
- **20-40**: Good outfit
- **40-60**: Mediocre outfit
- **60-80**: Poor outfit
- **80-100**: Very bad outfit

## Two Pages for Outfit Creation

### 1. Basic Outfit Generator (`outfit_generator_page.dart`)
- Predefined slots: Top, Bottom, Footwear (mandatory), + optional items
- Each type can only appear once
- Simpler interface for everyday outfits
- Automatically handles layer constraints

### 2. Complex Outfit Builder (`complex_outfit_page.dart`)
- Add unlimited items with one rule: no duplicate (type + layer) combinations
- Visual layer representation showing which layers are filled
- Color-coded layer badges (Base=blue, Main=green, Mid=orange, Outer=red)
- Real-time validation preventing invalid additions
- Full flexibility for creative outfits with multiple layers

## Examples

### Example 1: Simple Casual Outfit
```
Items:
- White t-shirt (top, layer=1)
- Blue jeans (bottom, layer=1)
- White sneakers (footwear, layer=1)

Analysis:
- Mostly neutral with blue accent → +15 bonus
- No clashes detected
- All items on layer 1 (same layer) → lower visibility weights
Final Score: ~15 (Excellent)
```

### Example 2: Layered Winter Outfit
```
Items:
- Black thermal shirt (top, layer=0)
- Gray sweater (top, layer=1)
- Black coat (outerwear, layer=3)
- Dark blue jeans (bottom, layer=1)
- Black boots (footwear, layer=1)

Analysis:
- Color recall: Black appears on layers 0, 3, and 1 (boots)
  - Layer 0 and 3 (not adjacent) → +1 recall
  - Layer 0 and 1 (adjacent) → doesn't count
  - Layer 3 and 1 → +1 recall
  - Total: -100 bonus
- Mostly neutral → slight penalty
- Coat visibility → higher weight for any clashes
Final Score: ~5 (Excellent)
```

### Example 3: Invalid Outfit
```
Items:
- Red t-shirt (top, layer=1)
- Blue t-shirt (top, layer=1)  ← CONFLICT!

Error: Cannot add second t-shirt on layer 1
System blocks this combination
```

## Algorithm Advantages

1. **Physical Realism**: Layers represent actual clothing physics
2. **Flexible Layering**: Can wear multiple items of same type if on different layers
3. **Smart Visibility**: Outer layers get more weight in clash detection
4. **Adjacent Focus**: Emphasizes harmony between touching layers
5. **Color Theory**: Uses HSL color space for accurate hue comparison
6. **Freshness**: Encourages variety through recency penalties

## Future Enhancements

Potential improvements:
- Seasonal appropriateness (layer count vs weather)
- Texture/material clash detection
- Pattern mixing analysis
- Cultural style rules
- AI-powered style learning from user preferences
