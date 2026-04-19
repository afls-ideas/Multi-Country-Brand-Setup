# README 13 — Inventory Count Assessment

## Overview

An `InventoryCountAssessment` is a formal count of a rep's sample inventory. It records what the rep has on hand (by product and by batch) and compares it against expected quantities. Inventory counts are required for compliance — they verify that the rep's physical stock matches what the system says they should have.

### When It's Needed

The platform requires an inventory count before a rep can drop samples. Without a completed count, the Samples panel during Visit Engagement may show an error or be blocked entirely.

### Objects Involved

| Object | Purpose |
|--------|---------|
| `InventoryCountAssessment` | Header — the assessment itself |
| `InventoryCountProductItem` | Product-level count — one per ProductItem |
| `InventoryCntProdtBatchItem` | Batch-level count — one per ProductBatchItem |

```mermaid
erDiagram
    InventoryCountAssessment ||--o{ InventoryCountProductItem : "contains"
    InventoryCountAssessment ||--o{ InventoryCntProdtBatchItem : "contains"
    InventoryCountProductItem ||--o{ InventoryCntProdtBatchItem : "parent of"
    ProductItem ||--|| InventoryCountProductItem : "counted by"
    ProductBatchItem ||--|| InventoryCntProdtBatchItem : "counted by"
```

---

## Key Fields

**InventoryCountAssessment (header):**

| Field | Type | Notes |
|-------|------|-------|
| `LocationId` | Lookup(Location) | The rep's inventory location |
| `AssigneeId` | Lookup(User) | The rep performing the count |
| `Type` | Picklist | `Initial`, `Periodic`, `Adhoc`, `Audited` |
| `Purpose` | Picklist | `Audit`, `Verification`, `Reconciliation`, `Adjustment`, `Compliance`, `Accuracy` |
| `Status` | Picklist | `Assigned`, `InProgress`, `Complete`, `AuditorApproved`, `Saved` |
| `PlannedStartDateTime` | DateTime | Required for non-Initial types |
| `PlannedEndDateTime` | DateTime | Required for non-Initial types |

**InventoryCountProductItem (product-level):**

| Field | Type | Notes |
|-------|------|-------|
| `InventoryCountAssessmentId` | Lookup | Parent assessment |
| `ProductItemId` | Lookup(ProductItem) | The inventory being counted |
| `ExpectedQuantity` | Decimal | System's expected quantity |
| `ActualQuantity` | Decimal | Rep's counted quantity |
| `Status` | Picklist | `Assigned`, `In_Progress`, `Complete`, `Inactive` |

**InventoryCntProdtBatchItem (batch-level):**

| Field | Type | Notes |
|-------|------|-------|
| `InventoryCountAssessmentId` | Lookup | Parent assessment |
| `InventoryCountProductItemId` | Lookup | Parent product-level count |
| `ProductBatchItemId` | Lookup(ProductBatchItem) | The batch being counted |
| `ProductId` | Lookup(Product2) | **Required** — must be set for the UI to display batch data in the Details table |
| `ExpectedQuantity` | Decimal | System's expected quantity |
| `ActualQuantity` | Decimal | Rep's counted quantity |
| `Status` | Picklist | `NotStarted`, `InProgress`, `Completed` |

> **Important:** The `ProductId` field on `InventoryCntProdtBatchItem` must be explicitly set. Without it, the Inventory Count Assessment detail page shows an empty Details table even though child records exist.

### Status Values Differ Across Objects

The status picklist values are **not consistent** across the three objects:

| Object | Status Values |
|--------|---------------|
| `InventoryCountAssessment` | Assigned, InProgress, Complete, AuditorApproved, Saved |
| `InventoryCountProductItem` | Assigned, In_Progress, Complete, Inactive |
| `InventoryCntProdtBatchItem` | NotStarted, InProgress, Completed |

---

## Matching Count (No Discrepancies)

The simplest case: the rep counts their inventory and everything matches what the system expects. The script sets `ActualQuantity = ExpectedQuantity` for both product-level and batch-level records.

### What It Looks Like

A completed Inventory Count Assessment showing the Details table with product and batch data:

![Inventory Count Assessment — GB rep](images/inventory-count-assessment-gb.png)

The Details table shows each batch with its product name, batch number, and actual stock count. When actual matches expected, no discrepancy is flagged.

### Script: Matching Count

**Script:** `scripts/create-inventory-count.apex`

```bash
sf apex run --file scripts/create-inventory-count.apex --target-org {your_org}
```

**Configurable variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `TERRITORY_DEV_NAME` | `GB_FSR_001_London` | Target territory |
| `COUNT_TYPE` | `Periodic` | Assessment type |
| `COUNT_PURPOSE` | `Accuracy` | Assessment purpose |

**What it does:**

1. Looks up the rep and their inventory location
2. Finds all ProductItem records at the location
3. Finds all active ProductBatchItem records
4. Creates an `InventoryCountAssessment` header
5. Creates `InventoryCountProductItem` records (one per ProductItem) with `ActualQuantity = ExpectedQuantity`
6. Creates `InventoryCntProdtBatchItem` records (one per active batch) with `ProductId` set
7. Marks the assessment as Complete

The script uses `Database.insert` with `allOrNone = false` for batch items to gracefully skip any that fail (e.g., due to unresolved product disbursements from prior activity).

---

## Count with Discrepancies

When the rep's physical count doesn't match the system's expected quantity, the assessment records a **discrepancy**. This is the more realistic scenario — reps may have lost, damaged, or miscounted samples.

### How Discrepancies Work

A discrepancy occurs when `ActualQuantity ≠ ExpectedQuantity` on an `InventoryCountProductItem` or `InventoryCntProdtBatchItem` record. Three scenarios:

| Scenario | Meaning | Example |
|----------|---------|---------|
| Actual < Expected | **Short** — rep has fewer than expected | Expected 500, counted 490 → short by 10 |
| Actual = Expected | **Match** — no discrepancy | Expected 500, counted 500 |
| Actual > Expected | **Over** — rep has more than expected | Expected 500, counted 503 → over by 3 |

The discrepancy is applied at the **batch level** — one specific lot may be short while others match. The product-level count sums across all batches.

### Example: GB Rep Discrepancy Count

The script creates an assessment with a mix of matches, shortages, and overages:

| Product | Expected | Actual | Discrepancy |
|---------|----------|--------|-------------|
| Cordim 10mg | 3994 | 3989 | Short by 5 |
| Cordim GB 20mg Sample | 1973 | 1973 | Match |
| Cordim GB 5mg Sample | 2000 | 2003 | Over by 3 |
| Immunexis GB 10mg Sample | 2000 | 1990 | Short by 10 |
| Immunexis GB 25mg Sample | 2000 | 2000 | Match |

At the batch level, the discrepancy is applied to the **first batch** of each product (simulating a shortage or overage in a specific lot), while the second batch matches.

### Script: Discrepancy Count

**Script:** `scripts/create-inventory-count-discrepancy.apex`

```bash
sf apex run --file scripts/create-inventory-count-discrepancy.apex --target-org {your_org}
```

**Configurable variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `TERRITORY_DEV_NAME` | `GB_FSR_001_London` | Target territory |
| `COUNT_TYPE` | `Periodic` | Assessment type |
| `COUNT_PURPOSE` | `Accuracy` | Assessment purpose |
| `DISCREPANCIES` | `{-5, 0, 3, -10}` | Per-product adjustments (alphabetical order). Negative = short, positive = over, 0 = match |

**What it does:**

1. Same setup as the matching count script (looks up rep, location, inventory)
2. Creates `InventoryCountProductItem` records with `ActualQuantity = ExpectedQuantity + discrepancy`
3. Applies the discrepancy to the **first batch** of each product at the batch level
4. Marks the assessment as Complete

---

## Platform Constraints

- **One Initial count per location** — the `Initial` type can only be used once per location. Use `Periodic`, `Adhoc`, or `Audited` for subsequent counts
- **Locked when Complete** — once an assessment is marked Complete, child records cannot be updated or deleted
- **PlannedStartDateTime / PlannedEndDateTime** required for non-Initial types on both the header and product-level children

---

## Troubleshooting

### Details Table Is Empty

The assessment record exists but clicking into it shows no data in the Details table.

**1. Do InventoryCntProdtBatchItem records have ProductId set?**

```apex
SELECT Id, ProductId, ProductBatchItemId, ExpectedQuantity
FROM InventoryCntProdtBatchItem
WHERE InventoryCountAssessmentId = '{assessmentId}'
```

If `ProductId` is null, the UI will not display the records. This field must be set during creation — completed assessments lock their child records and cannot be updated.

**2. Is the assessment status Complete?**

The Details table may not render for assessments in `Assigned` or `InProgress` status. Verify the assessment is marked `Complete`.

---

## Script Summary

| Script | Creates | Description |
|--------|---------|-------------|
| `scripts/create-inventory-count.apex` | Matching count | All actuals = expected, no discrepancies |
| `scripts/create-inventory-count-discrepancy.apex` | Discrepancy count | Configurable per-product discrepancies (short, over, match) |

---

## Related READMEs

- [README-12: Sample Inventory Setup](README-12-Sample-Inventory.md) — ProductItem, ProductionBatch, allocations
- [README-08: Sample Management Setup](README-08-Sample-Management-Setup.md)
- [README-04: Data Loading Scripts](README-04-Data-Loading-Scripts.md)
