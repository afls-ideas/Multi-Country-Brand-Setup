# Data Loading Scripts

## Overview

These Anonymous Apex scripts create the full multi-country product hierarchy and marketable product records in your org. Both scripts are idempotent — safe to re-run without creating duplicates.

```mermaid
flowchart LR
    S1["Step 1<br/><b>create-products.apex</b><br/>38 Product2 records"] --> S2["Step 2<br/><b>create-marketable-products.apex</b><br/>12 LifeSciMarketableProduct"]
    S2 --> S3["Step 3<br/><b>create-territories.apex</b><br/>25 Territory2 records"]
    S3 --> S4["Step 4<br/><b>create-territory-product-alignment.apex</b><br/>12 ProductTerritoryAvailability"]
    S4 --> S5["Step 5<br/><b>Verify in org</b>"]

    style S1 fill:#4a90d9,color:#fff
    style S2 fill:#f5a623,color:#fff
    style S3 fill:#9b59b6,color:#fff
    style S4 fill:#e74c3c,color:#fff
    style S5 fill:#7ed321,color:#fff
```

**Prerequisites:**
- `Country__c` custom picklist field deployed to `Product2` and `LifeSciMarketableProduct` (see `force-app/` metadata)
- `ParentProduct__c` custom lookup deployed to `Product2` (see [README-06](README-06-Parent-Child-Approaches.md))
- `Family` picklist values `Brand`, `Sub-Brand`, `Sample` available on `Product2.Family`
- `Multi_Country_Brand_Admin` permission set assigned to running user (for FLS on custom fields)
- Existing `Immunexis` and `Cordim` Brand-type LifeSciMarketableProduct records (these exist in the standard LSC demo data)

---

## Step 1: Create Product2 Hierarchy

**Script:** `scripts/create-products.apex`

Creates 38 Product2 records in a three-level hierarchy:

| Level | Family | Records | Parent Field |
|-------|--------|---------|--------------|
| 1 | Brand | 2 | None |
| 2 | Sub-Brand | 12 (2 brands x 6 countries) | `ParentProduct__c` → Brand |
| 3 | Sample | 24 (12 sub-brands x 2 dosages) | `ParentProduct__c` → Sub-Brand |

**Run it:**
```bash
sf apex run --file scripts/create-products.apex --target-org 260-pm
```

**How it works:**
1. Queries all existing Product2 records by ProductCode (idempotency key)
2. Inserts new records or updates existing ones
3. Populates `ParentProduct__c` to link child → parent
4. Sets `Country__c` on Sub-Brands and Samples

> **Note:** The script uses `ParentProduct__c` (custom lookup) by default. If your org has Product Hierarchy enabled, swap to the lines marked `[STANDARD HIERARCHY]` in the script. See [README-06](README-06-Parent-Child-Approaches.md) for details.

---

## Step 2: Create LifeSciMarketableProduct Records

**Script:** `scripts/create-marketable-products.apex`

Creates 12 LifeSciMarketableProduct records — one per brand per country. These make the country-level sub-brands visible across LSC features (territory alignment, call discussions, product priorities, etc.).

| Brand | Records | Parent Brand (via ParentBrandProductId) |
|-------|---------|----------------------------------------|
| Immunexis | 6 (US, GB, FR, IT, ES, DE) | Existing "Immunexis" Brand marketable product |
| Cordim | 6 (US, GB, FR, IT, ES, DE) | Existing "Cordim" Brand marketable product |

Each record is:
- Linked to its **Product2 sub-brand** via `ProductId`
- Parented under the **Brand marketable product** via `ParentBrandProductId`
- Tagged with `Country__c`

**Run it:**
```bash
sf apex run --file scripts/create-marketable-products.apex --target-org 260-pm
```

**How it works:**
1. Looks up existing Brand-type LifeSciMarketableProduct records for Immunexis and Cordim
2. Looks up Product2 sub-brand records (Family = Sub-Brand)
3. Queries existing LifeSciMarketableProduct records by ProductCode (idempotency key)
4. Inserts new records or updates existing ones

```mermaid
graph TD
    subgraph "LifeSciMarketableProduct"
        B1["Immunexis<br/><i>Type: Brand</i>"]
        B2["Cordim<br/><i>Type: Brand</i>"]

        B1 --> M1["Immunexis US<br/><i>Type: Product</i>"]
        B1 --> M2["Immunexis GB<br/><i>Type: Product</i>"]
        B1 --> M3["Immunexis FR<br/><i>Type: Product</i>"]
        B1 --> M4["...IT, ES, DE"]

        B2 --> M5["Cordim US<br/><i>Type: Product</i>"]
        B2 --> M6["Cordim GB<br/><i>Type: Product</i>"]
        B2 --> M7["Cordim FR<br/><i>Type: Product</i>"]
        B2 --> M8["...IT, ES, DE"]
    end

    subgraph "Product2"
        P1["Immunexis US<br/><i>Family: Sub-Brand</i>"]
        P2["Cordim US<br/><i>Family: Sub-Brand</i>"]
    end

    M1 -.->|ProductId| P1
    M5 -.->|ProductId| P2

    style B1 fill:#4a90d9,color:#fff
    style B2 fill:#4a90d9,color:#fff
    style M1 fill:#f5a623,color:#fff
    style M2 fill:#f5a623,color:#fff
    style M3 fill:#f5a623,color:#fff
    style M4 fill:#f5a623,color:#fff
    style M5 fill:#f5a623,color:#fff
    style M6 fill:#f5a623,color:#fff
    style M7 fill:#f5a623,color:#fff
    style M8 fill:#f5a623,color:#fff
    style P1 fill:#7ed321,color:#fff
    style P2 fill:#7ed321,color:#fff
```

---

## Why Both Objects?

| Object | Role | Without It |
|--------|------|------------|
| **Product2** | Master product catalog — defines brands, dosages, hierarchy | No products exist |
| **LifeSciMarketableProduct** | Makes products available in LSC features — territory alignment, call discussions, priorities, sampling | Products exist but are invisible to reps and LSC workflows |

Think of Product2 as the **definition** and LifeSciMarketableProduct as the **activation** for LSC.

---

## Step 3: Create Territory Hierarchy

**Script:** `scripts/create-territories.apex`

Creates 25 Territory2 records in a three-level hierarchy under the existing active Territory2Model:

| Level | Naming Convention | Records |
|-------|-------------------|---------|
| 1 | GLOBAL | 1 |
| 2 | `{CC}-COUNTRY` | 6 (US, GB, FR, IT, ES, DE) |
| 3 | `{CC}-FSR-{seq}-{City}` | 18 (3 cities per country) |

All territories have `AccountAccessLevel = Edit` (view and edit for accounts).

**Run it:**
```bash
sf apex run --file scripts/create-territories.apex --target-org 260-pm
```

**How it works:**
1. Looks up the active Territory2Model and Territory2Type
2. Queries all existing territories by DeveloperName (idempotency key)
3. Creates GLOBAL top-level, then countries, then cities
4. Sets `AccountAccessLevel = 'Edit'` on all records

```mermaid
graph TD
    G["GLOBAL"]
    G --> US["US-COUNTRY"]
    G --> GB["GB-COUNTRY"]
    G --> FR["FR-COUNTRY"]
    G --> IT["IT-COUNTRY"]
    G --> ES["ES-COUNTRY"]
    G --> DE["DE-COUNTRY"]

    US --> US1["US-FSR-001-New York"]
    US --> US2["US-FSR-002-Los Angeles"]
    US --> US3["US-FSR-003-Chicago"]

    GB --> GB1["GB-FSR-001-London"]
    GB --> GB2["GB-FSR-002-Manchester"]
    GB --> GB3["GB-FSR-003-Birmingham"]

    DE --> DE1["DE-FSR-001-Berlin"]
    DE --> DE2["DE-FSR-002-Munich"]
    DE --> DE3["DE-FSR-003-Frankfurt"]

    FR --> FR1["...Paris, Lyon, Marseille"]
    IT --> IT1["...Rome, Milan, Naples"]
    ES --> ES1["...Madrid, Barcelona, Valencia"]

    style G fill:#9b59b6,color:#fff
    style US fill:#9b59b6,color:#fff
    style GB fill:#9b59b6,color:#fff
    style FR fill:#9b59b6,color:#fff
    style IT fill:#9b59b6,color:#fff
    style ES fill:#9b59b6,color:#fff
    style DE fill:#9b59b6,color:#fff
```

> These territories sit alongside the existing US-only territory hierarchy (RD - Midwest, Northeast, etc.) and do not modify it.

---

## Step 4: Align Marketable Products to Territories

**Script:** `scripts/create-territory-product-alignment.apex`

Creates 12 `ProductTerritoryAvailability` records — one per country marketable product aligned to its matching country territory.

| Field | Value |
|-------|-------|
| `ProductId` | Country-level LifeSciMarketableProduct |
| `TerritoryId` | Matching `{CC}-COUNTRY` Territory2 |
| `AlignmentType` | Territory and Subordinates Inclusion |
| `Purpose` | Visit |
| `Status` | Active |
| `UsageType` | LifeSciences |

**"Territory and Subordinates Inclusion"** means the product is available in the country territory AND all city FSR territories underneath — no need to create separate alignments per city.

**Run it:**
```bash
sf apex run --file scripts/create-territory-product-alignment.apex --target-org 260-pm
```

**How it works:**
1. Looks up country territories and country marketable products
2. Checks for existing alignments (idempotency)
3. Inserts as `Draft` (platform requirement), then updates to `Active`

```mermaid
graph LR
    subgraph "Marketable Product"
        MGB["Cordim GB"]
        MDE["Immunexis DE"]
    end

    subgraph "Territory (+ Subordinates)"
        TGB["GB-COUNTRY<br/>→ London, Manchester, Birmingham"]
        TDE["DE-COUNTRY<br/>→ Berlin, Munich, Frankfurt"]
    end

    MGB -->|PTA| TGB
    MDE -->|PTA| TDE

    style MGB fill:#f5a623,color:#fff
    style MDE fill:#f5a623,color:#fff
    style TGB fill:#9b59b6,color:#fff
    style TDE fill:#9b59b6,color:#fff
```

> **After running the script**, go to **Setup > Product Alignment Jobs** and run the **"Publish Draft Product Territory Alignments Batch Job"**. This is a standard Salesforce step that finalizes PTA records. While the script updates records to Active programmatically, running this job ensures the alignments are fully published and visible across all LSC features.
>
> ![Product Alignment Jobs](images/product-alignment-jobs.png)

After the batch job completes, 12 `ProductTerritoryAvailability` records are created — one per country marketable product:

| Product | Territory | Alignment Type | Status |
|---------|-----------|---------------|--------|
| Immunexis US | US-COUNTRY | Territory and Subordinates Inclusion | Active |
| Immunexis GB | GB-COUNTRY | Territory and Subordinates Inclusion | Active |
| Immunexis FR | FR-COUNTRY | Territory and Subordinates Inclusion | Active |
| Immunexis IT | IT-COUNTRY | Territory and Subordinates Inclusion | Active |
| Immunexis ES | ES-COUNTRY | Territory and Subordinates Inclusion | Active |
| Immunexis DE | DE-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim US | US-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim GB | GB-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim FR | FR-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim IT | IT-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim ES | ES-COUNTRY | Territory and Subordinates Inclusion | Active |
| Cordim DE | DE-COUNTRY | Territory and Subordinates Inclusion | Active |

Because each alignment uses **"Territory and Subordinates Inclusion"**, reps assigned to any city FSR territory (e.g., `GB-FSR-001-London`) automatically see the country's products (Immunexis GB, Cordim GB) without needing separate alignments per city.

---

## Expected Output After All Scripts

```mermaid
graph TD
    subgraph "Product2 (38 records)"
        IMM["<b>Immunexis</b><br/>Brand"]
        IMM_US["Immunexis US<br/>Sub-Brand"]
        IMM_US_10["10mg Sample"]
        IMM_US_25["25mg Sample"]
        IMM --> IMM_US
        IMM_US --> IMM_US_10
        IMM_US --> IMM_US_25
        IMM --> IMM_ETC["...GB, FR, IT, ES, DE<br/>(each with 2 samples)"]

        COR["<b>Cordim</b><br/>Brand"]
        COR_US["Cordim US<br/>Sub-Brand"]
        COR_US_5["5mg Sample"]
        COR_US_20["20mg Sample"]
        COR --> COR_US
        COR_US --> COR_US_5
        COR_US --> COR_US_20
        COR --> COR_ETC["...GB, FR, IT, ES, DE<br/>(each with 2 samples)"]
    end

    subgraph "LifeSciMarketableProduct (12 new records)"
        MKIMM["Immunexis<br/>Brand (existing)"]
        MKIMM_US["Immunexis US"]
        MKIMM_GB["Immunexis GB"]
        MKIMM_ETC["...FR, IT, ES, DE"]
        MKIMM --> MKIMM_US & MKIMM_GB & MKIMM_ETC

        MKCOR["Cordim<br/>Brand (existing)"]
        MKCOR_US["Cordim US"]
        MKCOR_GB["Cordim GB"]
        MKCOR_ETC["...FR, IT, ES, DE"]
        MKCOR --> MKCOR_US & MKCOR_GB & MKCOR_ETC
    end

    MKIMM_US -.->|ProductId| IMM_US
    MKCOR_US -.->|ProductId| COR_US

    style IMM fill:#4a90d9,color:#fff
    style COR fill:#4a90d9,color:#fff
    style MKIMM fill:#4a90d9,color:#fff
    style MKCOR fill:#4a90d9,color:#fff
```

> **Record counts:** 38 Product2 + 12 LifeSciMarketableProduct + 25 Territory2 + 12 ProductTerritoryAvailability = **87 total records created**

---

## Cleanup Scripts

Run in reverse order — alignments first, then territories, then marketable products, then products.

### 1. Delete Territory-Product Alignments
```apex
// Delete PTA records for our country marketable products
List<Id> mktIds = new List<Id>();
for (LifeSciMarketableProduct m : [SELECT Id FROM LifeSciMarketableProduct WHERE ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%']) {
    mktIds.add(m.Id);
}
delete [SELECT Id FROM ProductTerritoryAvailability WHERE ProductId IN :mktIds];
System.debug('Territory-product alignments deleted.');
```

### 2. Delete Territories
```bash
sf apex run --file scripts/delete-territories.apex --target-org 260-pm
```

Deletes in reverse order: Cities → Countries → GLOBAL.

### 3. Delete LifeSciMarketableProduct Records
```apex
// Delete country-level marketable products (not the Brand-level parents)
delete [
    SELECT Id FROM LifeSciMarketableProduct
    WHERE ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%'
];
System.debug('Country marketable products deleted.');
```

### 4. Delete Product2 Records
```bash
sf apex run --file scripts/delete-products.apex --target-org 260-pm
```

Deletes in reverse hierarchy order: Samples → Sub-Brands → Brands.

---

## Data Sources

| File | What It Defines |
|------|-----------------|
| `data/products.json` | Brands, countries, sample dosages |
| `data/territories.json` | Country territories and cities |

Edit these files and update the corresponding scripts to match, then re-run.

---

## Script Summary

| Script | Creates | Records | Object |
|--------|---------|---------|--------|
| `scripts/create-products.apex` | Product hierarchy | 38 | Product2 |
| `scripts/create-marketable-products.apex` | Marketable products | 12 | LifeSciMarketableProduct |
| `scripts/create-territories.apex` | Territory hierarchy | 25 | Territory2 |
| `scripts/create-territory-product-alignment.apex` | Product-territory alignment | 12 | ProductTerritoryAvailability |
| `scripts/delete-products.apex` | Cleanup products | — | Product2 |
| `scripts/delete-territories.apex` | Cleanup territories | — | Territory2 |

---

## Related READMEs

- [README-01: Product Hierarchy Architecture](README-01-Product-Hierarchy.md)
- [README-02: LSC Areas Where Products Appear](README-02-LSC-Product-Areas.md)
- [README-03: Country Field Requirements Per Object](README-03-Country-Field-Requirements.md)
- [README-05: Country Global Value Set](README-05-Country-Global-Value-Set.md)
- [README-06: Parent-Child Approaches](README-06-Parent-Child-Approaches.md)
