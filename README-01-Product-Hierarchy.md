# Multi-Country Brand Setup: Product Hierarchy Architecture

## Overview

This project sets up a **multi-country pharmaceutical brand hierarchy** in Life Sciences Cloud (LSC) using the standard `Product2` object with parent-child relationships. Two brands — **Immunexis** and **Cordim** — are deployed across six countries: US, GB, FR, IT, ES, and DE.

## Product2 Hierarchy (3 Levels)

```
Level 1: BRAND (Top-Level Product2)
│
├── Immunexis                    (Family = "Brand", IsActive = true)
│   ├── Level 2: SUB-BRAND / COUNTRY VARIANT (Child Product2, ParentId → Brand)
│   │   ├── Immunexis US         (Country__c = "US", Family = "Sub-Brand")
│   │   ├── Immunexis GB         (Country__c = "GB", Family = "Sub-Brand")
│   │   ├── Immunexis FR         (Country__c = "FR", Family = "Sub-Brand")
│   │   ├── Immunexis IT         (Country__c = "IT", Family = "Sub-Brand")
│   │   ├── Immunexis ES         (Country__c = "ES", Family = "Sub-Brand")
│   │   └── Immunexis DE         (Country__c = "DE", Family = "Sub-Brand")
│   │       │
│   │       └── Level 3: SAMPLE (Child Product2, ParentId → Sub-Brand)
│   │           ├── Immunexis DE 10mg Sample   (Family = "Sample")
│   │           └── Immunexis DE 25mg Sample   (Family = "Sample")
│
└── Cordim                       (Family = "Brand", IsActive = true)
    ├── Cordim US                (Country__c = "US", Family = "Sub-Brand")
    ├── Cordim GB                (Country__c = "GB", Family = "Sub-Brand")
    ├── Cordim FR                (Country__c = "FR", Family = "Sub-Brand")
    ├── Cordim IT                (Country__c = "IT", Family = "Sub-Brand")
    ├── Cordim ES                (Country__c = "ES", Family = "Sub-Brand")
    └── Cordim DE                (Country__c = "DE", Family = "Sub-Brand")
        ├── Cordim DE 5mg Sample
        └── Cordim DE 20mg Sample
```

## Key Design Decisions

### Why Use Product2.ParentId?
- **Standard field** — no custom development needed
- LSC natively supports product hierarchy via `ParentId`
- Mobile app and Admin Console respect the parent-child relationship
- Enables roll-up reporting from sample → sub-brand → brand

### Why a Separate Sub-Brand Per Country?
- **Product messages** (ProductGuidance) differ by country due to regulatory/compliance
- **CLM content** (presentations, PDFs) must be country-specific
- **Sample regulations** vary by country (e.g., US has PDMA, EU has different rules)
- **Territory alignment** is country-specific — reps only see their country's products
- **Product priorities** differ by market
- **Account restrictions** may vary by country

### Country__c Custom Field on Product2
A custom picklist `Country__c` is added to Product2 to:
- Enable list views and reports filtered by country
- Drive assignment rules and sharing
- Allow Admin Console / DB Schema filtering
- Support data loader operations filtered by country

| Field API Name | Type | Values |
|---|---|---|
| `Country__c` | Picklist | US, GB, FR, IT, ES, DE |

### Product Family Picklist Values
The standard `Family` field on Product2 is used to distinguish hierarchy levels:

| Family Value | Level | Purpose |
|---|---|---|
| Brand | 1 | Top-level brand (Immunexis, Cordim) |
| Sub-Brand | 2 | Country variant of the brand |
| Sample | 3 | Physical sample SKU under a sub-brand |

## Record Counts

| Entity | Count |
|---|---|
| Brands | 2 (Immunexis, Cordim) |
| Sub-Brands | 12 (2 brands × 6 countries) |
| Samples per Sub-Brand | 2 |
| Total Samples | 24 (12 sub-brands × 2 samples) |
| **Total Product2 Records** | **38** |

## Related READMEs

- [README-02: LSC Areas Where Products Appear](README-02-LSC-Product-Areas.md)
- [README-03: Country Field Requirements Per Object](README-03-Country-Field-Requirements.md)
- [README-04: Data Loading Scripts](README-04-Data-Loading-Scripts.md)
