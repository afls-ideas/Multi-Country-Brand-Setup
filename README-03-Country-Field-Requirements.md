# Country Field Requirements Per Object

## Do We Need Country__c on Every Product-Related Object?

**Short answer: Yes, on most of them.** While the sub-brand Product2 record carries country context through its `Country__c` field, adding `Country__c` to downstream objects provides:

1. **Direct filtering** — List views, reports, and dashboards can filter by country without joining to Product2
2. **Admin Console management** — Admins managing multi-country orgs can quickly scope their work
3. **Data validation** — Ensures records are created against the correct country's sub-brand
4. **Mobile performance** — Reduces query complexity on the mobile app (no extra join needed)
5. **Sharing rules** — Country-based sharing rules can be applied directly

---

## Country__c Field Specification

All `Country__c` fields use the same definition for consistency:

| Property | Value |
|---|---|
| **API Name** | `Country__c` |
| **Type** | Picklist |
| **Values** | `US`, `GB`, `FR`, `IT`, `ES`, `DE` |
| **Required** | No (blank for global/brand-level records) |
| **Description** | Identifies the country/market this record belongs to |
| **Default** | None |

---

## Objects Requiring Country__c

### Tier 1: Essential (Deploy First)

These objects are core to the multi-country product setup and MUST have Country__c.

| # | Object API Name | Why Country__c Is Needed | Populating Strategy |
|---|---|---|---|
| 1 | `Product2` | Identifies which country a sub-brand or sample belongs to | Set during record creation; inherited from hierarchy |
| 2 | `LifeSciMarketableProduct` | Filter marketable products by country; validate territory alignment | Copy from related Product2.Country__c |
| 3 | `ProductGuidance` | Country-specific product messages; admin filtering | Copy from related Product2.Country__c |
| 4 | `LifeSciTerritoryProductPriority` | Manage priorities by country; prevent cross-country misalignment | Copy from related Product2.Country__c |

### Tier 2: Important (Deploy Second)

These objects benefit significantly from direct country filtering.

| # | Object API Name | Why Country__c Is Needed | Populating Strategy |
|---|---|---|---|
| 5 | `LifeSciProductAccountRestriction` | Country-specific formulary/compliance restrictions | Copy from related Product2.Country__c |
| 6 | `TerritoryProductQtyAllocation` | Country-specific sample allocation quantities | Copy from related Product2.Country__c |
| 7 | `SampleTransaction` | Compliance reporting by country (PDMA vs EU rules) | Copy from related Product2.Country__c |
| 8 | `SampleLot` | Country-specific lot tracking and expiry management | Copy from related Product2.Country__c |
| 9 | `SampleInventory` | Country-level inventory reporting | Copy from related Product2.Country__c |
| 10 | `LifeSciCallDiscussion` | Multi-country call analytics and reporting | Copy from related Product2.Country__c |

### Tier 3: Optional (Deploy If Needed)

These objects may or may not need Country__c depending on your implementation.

| # | Object API Name | Why Country__c Might Be Needed | When to Add |
|---|---|---|---|
| 11 | `ProductSpecificationType` | Country-specific indications/approvals | If indications differ by country |
| 12 | `ReceivedSampleTransaction` | Country-level receipt tracking | If separate receipt compliance by country |

### Objects That Do NOT Need Country__c

| Object | Reason |
|---|---|
| `ContentVersion` / `ContentDocumentLink` | Country context is inherited through the Product2 relationship; content files are linked to sub-brands |
| `ActionPlanTemplate` | Use filter criteria or record types for country scoping instead |
| `Territory2` | Territories already have geography built into their hierarchy |
| NBC/NBA Configuration | Driven by territory product priorities which already carry country context |

---

## Population Strategy

### Option A: Manual / Data Loader (Recommended for Initial Load)
Set `Country__c` during data creation. The Apex scripts in README-04 handle this.

### Option B: Flow / Trigger (Recommended for Ongoing)
Create a before-insert Flow or trigger on each object that:
1. Looks up the related Product2 record
2. Copies `Product2.Country__c` into the new record's `Country__c`
3. Validates that the country matches the user's territory assignment

### Option C: Formula Field (Alternative)
Instead of a stored picklist, use a formula field:
```
Product__r.Country__c
```
**Pros:** Always in sync, no population logic needed.
**Cons:** Cannot use in sharing rules, slower in reports with large data, cannot be used in list view filters on mobile.

**Recommendation:** Use a stored picklist (Option A/B) for flexibility and performance.

---

## Deployment Order

```
1. Product2.Country__c                          ← Deploy first (all others depend on this)
2. LifeSciMarketableProduct.Country__c
3. ProductGuidance.Country__c
4. LifeSciTerritoryProductPriority.Country__c
5. LifeSciProductAccountRestriction.Country__c
6. TerritoryProductQtyAllocation.Country__c
7. SampleTransaction.Country__c
8. SampleLot.Country__c
9. SampleInventory.Country__c
10. LifeSciCallDiscussion.Country__c
```

---

## SFDX Metadata Location

All custom field metadata is in:
```
260-pm/force-app/main/default/objects/<ObjectName>/fields/Country__c.field-meta.xml
```

See the `260-pm` project for deployable metadata.

---

## Related READMEs

- [README-01: Product Hierarchy Architecture](README-01-Product-Hierarchy.md)
- [README-02: LSC Areas Where Products Appear](README-02-LSC-Product-Areas.md)
- [README-04: Data Loading Scripts](README-04-Data-Loading-Scripts.md)
