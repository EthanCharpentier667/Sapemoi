# API Requirements for Sapemoi

## New Endpoint: /total

### Purpose
Estimate the total value of a user's wardrobe using AI analysis of brand names and product types.

### Endpoint
```
POST https://sapemoi-api.onrender.com/total
```

### Request Format
```json
{
  "items": [
    {
      "brand": "Nike",
      "product": "Air Max 90",
      "type": "footwear",
      "specificType": "sneakers"
    },
    {
      "brand": "Levi's",
      "product": "501 Original Fit Jeans",
      "type": "bottom",
      "specificType": "jeans"
    }
  ]
}
```

### Response Format
```json
{
  "total": 450.00,
  "breakdown": [
    {
      "brand": "Nike",
      "product": "Air Max 90",
      "estimatedValue": 120.00
    },
    {
      "brand": "Levi's",
      "product": "501 Original Fit Jeans",
      "estimatedValue": 80.00
    }
  ]
}
```

### Implementation Notes

1. The AI should estimate retail/resale value based on:
   - Brand reputation and pricing tier
   - Product name and model
   - Type/category of clothing
   - Average market prices

2. For unknown brands, use generic category averages:
   - Sneakers: ~$80-100
   - T-shirts: ~$20-30
   - Jeans: ~$50-70
   - Jackets: ~$100-150

3. Handle errors gracefully:
   - Return error code if items array is empty
   - Skip items with "unknown" brand and product
   - Provide partial total if some items can't be estimated

4. Timeout: 2 minutes (same as /analyze endpoint)

### Error Responses
```json
{
  "error": "No items provided"
}
```

```json
{
  "error": "Invalid request format"
}
```

## Current Endpoint: /analyze

This endpoint already exists and analyzes clothing images to extract:
- Type
- SpecificType
- Colors (RGB + percentage)
- Brand
- Product name

No changes needed to this endpoint.
