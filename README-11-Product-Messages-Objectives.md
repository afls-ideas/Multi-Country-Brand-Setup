# README 11 — Product Messages & Objectives

## Overview

Product Messages and Objectives provide reps with approved talking points and strategic goals during visits. In LSC, both are stored on a single object — **ProductGuidance** — distinguished by the `Type` field. Each record is linked to a country-specific sub-brand `LifeSciMarketableProduct`, enabling localized content per market.

```mermaid
graph TD
    subgraph "ProductGuidance Records"
        M["Messages<br/><i>Type = Message</i><br/>Approved talking points"]
        O["Objectives<br/><i>Type = Objective</i><br/>Strategic goals"]
    end

    subgraph "LifeSciMarketableProduct (Sub-Brands)"
        CGB["Cordim GB"]
        CFR["Cordim FR"]
        CDE["Cordim DE"]
        CETC["...US, ES, IT"]
    end

    M -->|ProductReferenceRecordId| CGB
    M -->|ProductReferenceRecordId| CFR
    M -->|ProductReferenceRecordId| CDE
    O -->|ProductReferenceRecordId| CGB
    O -->|ProductReferenceRecordId| CFR
    O -->|ProductReferenceRecordId| CDE

    style M fill:#4a90d9,color:#fff
    style O fill:#f5a623,color:#fff
    style CGB fill:#2ecc71,color:#fff
    style CFR fill:#2ecc71,color:#fff
    style CDE fill:#2ecc71,color:#fff
    style CETC fill:#2ecc71,color:#fff
```

---

## Key Concepts

### Messages vs Objectives

Both live on the same object (`ProductGuidance`) and share the same fields. The `Type` picklist determines how they appear in the UI:

| Type | Purpose | Example |
|------|---------|---------|
| **Message** | Approved talking points reps deliver to HCPs during calls | "Delivers rapid symptom relief with up to 60% improvement by Week 12." |
| **Objective** | Strategic goals reps should work toward for the product | "Position Cordim as first-line biologic for moderate-to-severe RA." |

Messages appear in the **Messages** section and Objectives appear in the **Objectives** section of the Product Hierarchy detail panel and during Visit Engagement.

### Why Attach to the Sub-Brand (Not the Top-Level Brand)?

Each country has different:
- **Regulatory approvals** — approved indications and claims vary by market
- **Language requirements** — French reps need French content, German reps need German content
- **Market positioning** — competitive landscape differs by country
- **Payer/formulary context** — objectives reference local health authorities (NICE, HAS, G-BA, AIFA, AEMPS)

Attaching messages to `Cordim FR` (not `Cordim`) ensures French reps see French-language, France-specific content.

---

## ProductGuidance Object

### Key Fields

| Field API Name | Label | Type | Description |
|----------------|-------|------|-------------|
| `Name` | Name | String | Unique identifier (e.g., "Cordim GB Message1") |
| `ContentText` | Content Text | String | The message body or objective description |
| `Type` | Type | Picklist | `Message`, `Objective`, or `Other` |
| `Priority` | Priority | Integer | Numeric ordering (1 = highest priority) |
| `ProductReferenceRecordId` | Product Reference Record ID | Reference | Polymorphic lookup to `LifeSciMarketableProduct` or `Product2` |
| `EffectiveStartDate` | Effective Start Date | Date | When the guidance becomes active |
| `EffectiveEndDate` | Effective End Date | Date | When the guidance expires |
| `IsActive` | Active | Boolean | Must be `true` for the record to appear |
| `GroupName` | Group Name | String | Optional grouping label |
| `GroupSequence` | Group Sequence | Integer | Order within a group |
| `Reactions` | Reactions | String | Reaction options (e.g., Positive/Neutral/Negative) |

### ProductReferenceRecordId

This is a **polymorphic lookup** — it can point to either `LifeSciMarketableProduct` or `Product2`. For multi-country setups, always point to the **LifeSciMarketableProduct** sub-brand record (e.g., "Cordim GB"), because:

1. The Product Hierarchy UI resolves messages by this field
2. Territory-filtered product alignment flows through `LifeSciMarketableProduct`
3. Visit Engagement resolves detailable products from `LifeSciMarketableProduct`

---

## Data Created by the Script

**Script:** `scripts/create-product-guidance.apex`

The script creates 60 `ProductGuidance` records — 3 messages and 2 objectives for each of the 12 country sub-brands:

| Brand | Countries | Messages | Objectives | Total |
|-------|-----------|----------|------------|-------|
| Cordim | GB, US, FR, DE, ES, IT | 18 | 12 | 30 |
| Immunexis | GB, US, FR, DE, ES, IT | 18 | 12 | 30 |
| **Total** | | **36** | **24** | **60** |

All records have:
- `EffectiveStartDate` = 2025-01-01
- `EffectiveEndDate` = 2025-12-31
- `IsActive` = true

### Localization

Content is localized per country language:

| Country | Language | Example Message (Cordim) |
|---------|----------|--------------------------|
| GB | English | "Delivers rapid and sustained symptom relief, with up to 60% improvement in joint pain and swelling by Week 12." |
| US | English | "Now FDA-approved for moderate-to-severe rheumatoid arthritis in adults who have had an inadequate response to one or more DMARDs." |
| FR | French | "Cordim offre un soulagement rapide et durable des symptômes, avec une amélioration allant jusqu'à 60 % des douleurs articulaires et du gonflement à la semaine 12." |
| DE | German | "Cordim bietet eine schnelle und anhaltende Symptomlinderung mit bis zu 60 % Verbesserung von Gelenkschmerzen und Schwellungen bis Woche 12." |
| ES | Spanish | "Cordim ofrece un alivio rápido y sostenido de los síntomas, con una mejora de hasta el 60 % en el dolor articular y la hinchazón en la semana 12." |
| IT | Italian | "Cordim offre un sollievo rapido e duraturo dei sintomi, con un miglioramento fino al 60% del dolore articolare e del gonfiore entro la settimana 12." |

Objectives reference country-specific regulatory bodies and market context:

| Country | Regulatory Body Referenced |
|---------|---------------------------|
| GB | NICE (National Institute for Health and Care Excellence) / NHS ICBs |
| US | FDA |
| FR | HAS (Haute Autorité de Santé) |
| DE | G-BA (Gemeinsamer Bundesausschuss) / DGRh |
| ES | AEMPS (Agencia Española de Medicamentos) |
| IT | AIFA (Agenzia Italiana del Farmaco) |

---

## Running the Script

**Prerequisites:**
- Country sub-brand `LifeSciMarketableProduct` records exist (from `scripts/create-marketable-products.apex`)
- Sub-brands have `ParentProductId` set (from `scripts/fix-sub-brand-parent-hierarchy.apex`)

```bash
sf apex run --file scripts/create-product-guidance.apex --target-org {your_org}
```

The script is idempotent — it checks for existing records by `Name` and skips duplicates.

### Expected Output

```
Found: Cordim GB (CORDIM-GB) → 1KeHs0000010wBcKAI
Found: Immunexis GB (IMMUNEXIS-GB) → 1KeHs0000010wBWKAY
...
Inserted 60 ProductGuidance records.
============================================
PRODUCT GUIDANCE RECORDS
  Messages:   36
  Objectives: 24
  Total:      60
============================================
```

---

## How Messages and Objectives Appear

### Product Hierarchy UI (Setup)

In **Setup > Product Configuration > Product Hierarchy**, select a country sub-brand (e.g., "Cordim GB"). The detail panel on the right shows two sections:

- **Messages** — lists each `Type = 'Message'` record with Name, Content Text, Effective Start Date, Effective End Date, and Priority
- **Objectives** — same layout but for `Type = 'Objective'` records (visible by scrolling down or clicking the Objectives tab)

Both sections have an **Edit** button for inline modification.

### Visit Engagement (Mobile / Web)

During a visit, when a rep selects a product for detailing:
1. The platform resolves which `LifeSciMarketableProduct` records are aligned to the rep's territory
2. For each aligned product, it queries `ProductGuidance` where `ProductReferenceRecordId` matches and `IsActive = true` and the current date falls within the effective date range
3. Messages appear as talking points the rep can mark as discussed
4. Objectives appear as goals the rep can track progress against

### Call Discussion Records

When a rep marks a message as discussed during a visit, the platform creates a `ProviderVisitDtlProductMsg` record linking:
- The visit (`ProviderVisitDetail`)
- The product (`LifeSciMarketableProduct`)
- The message (`ProductGuidance`)
- The reaction (if reactions are configured)

---

## Cleanup

To delete all guidance records created by the script:

```apex
List<ProductGuidance> toDelete = [
    SELECT Id FROM ProductGuidance
    WHERE Name LIKE 'Cordim%' OR Name LIKE 'Immunexis%'
];
delete toDelete;
System.debug('Deleted ' + toDelete.size() + ' ProductGuidance records.');
```

---

## Design Decisions

### Naming Convention

Records follow the pattern `{Brand} {Country} {Type}{Sequence}`:
- `Cordim GB Message1`, `Cordim GB Message2`, `Cordim GB Message3`
- `Cordim FR Objectif1`, `Cordim FR Objectif2`

For non-English countries, the Type word is localized in the Name (Objectif, Ziel, Objetivo, Obiettivo) to make records immediately identifiable by language when browsing in list views.

### Priority as Integer

`Priority` is a numeric integer field, not a picklist. Lower numbers = higher priority. The script assigns:
- Messages: Priority 1, 2, 3
- Objectives: Priority 1, 2

### Effective Dates

All records use a calendar-year range (2025-01-01 to 2025-12-31). In production, you would:
- Align to your commercial planning cycle (e.g., quarterly brand plans)
- Expire outdated messages when new clinical data is available
- Create new records for the next cycle rather than editing existing ones (for audit trail)

---

## Script Summary

| Script | Creates | Records | Object |
|--------|---------|---------|--------|
| `scripts/create-product-guidance.apex` | Localized messages and objectives | 60 | ProductGuidance |

---

## Related READMEs

- [README-01: Product Hierarchy Architecture](README-01-Product-Hierarchy.md)
- [README-02: LSC Areas Where Products Appear](README-02-LSC-Product-Areas.md)
- [README-04: Data Loading Scripts](README-04-Data-Loading-Scripts.md)
- [README-06: Parent-Child Approaches](README-06-Parent-Child-Approaches.md)
- [README-08: Sample Management Setup](README-08-Sample-Management-Setup.md)
