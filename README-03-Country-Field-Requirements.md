# Country Field Requirements Per Object

## Do We Need Country__c on Every Product-Related Object?

**Short answer: No — only on the master/configuration objects.** The sub-brand Product2 record is the source of truth for country context. Downstream transactional objects (sample transactions, call discussions, inventory) inherit country context through their relationship to Product2 or LifeSciMarketableProduct. Adding `Country__c` to those objects is unnecessary overhead.

Adding `Country__c` to the **core product objects** provides:

1. **Direct filtering** — List views, reports, and dashboards can filter by country without joining to Product2
2. **Admin Console management** — Admins managing multi-country orgs can quickly scope their work
3. **Data validation** — Ensures records are created against the correct country's sub-brand
4. **Sharing rules** — Country-based sharing rules can be applied directly

---

## Country__c Field Specification

All `Country__c` fields use the same definition for consistency, backed by a **Global Value Set** (`Country`):

| Property | Value |
|---|---|
| **API Name** | `Country__c` |
| **Type** | Picklist (Global Value Set) |
| **Global Value Set** | `Country` |
| **Values** | `US`, `GB`, `FR`, `IT`, `ES`, `DE` |
| **Required** | No (blank for global/brand-level records) |
| **Description** | Identifies the country/market this record belongs to |
| **Default** | None |

> To add a new country, edit only `force-app/main/default/globalValueSets/Country.globalValueSet-meta.xml` — all fields inherit the change.

---

## Objects Requiring Country__c

These objects are core to the multi-country product setup and MUST have Country__c.

| # | Object API Name | Why Country__c Is Needed | Populating Strategy | Deployed |
|---|---|---|---|---|
| 1 | `Product2` | Identifies which country a sub-brand or sample belongs to | Set during record creation; inherited from hierarchy | YES |
| 2 | `LifeSciMarketableProduct` | Filter marketable products by country; validate territory alignment | Copy from related Product2.Country__c | YES |
| 3 | `ProductGuidance` | Country-specific product messages; admin filtering | Copy from related Product2.Country__c | YES |

### Objects That Do NOT Need Country__c

Transactional and downstream objects inherit country context through their relationships to Product2 or LifeSciMarketableProduct. Adding `Country__c` directly is redundant.

| Object | Reason Country__c Is Not Needed |
|---|---|
| `LifeSciTerritoryProductPriority` | References Product2 which carries Country__c; territory itself implies country |
| `LifeSciProductAccountRestriction` | References Product2 which carries Country__c |
| `TerritoryProdtQtyAllocation` | References Product2 (sample-level) which carries Country__c; territory implies country |
| `SampleTransaction` / `SampleLot` / `SampleInventory` | References Product2 which carries Country__c; use Product2.Country__c in reports |
| `LifeSciCallDiscussion` | References Product2 which carries Country__c |
| `ContentVersion` / `ContentDocumentLink` | Country context inherited through the Product2 relationship |
| `ActionPlanTemplate` | Use filter criteria or record types for country scoping instead |
| `Territory2` | Territories already have geography built into their hierarchy |
| `ProductSpecificationType` | References Product2 which carries Country__c |
| NBC/NBA Configuration | Driven by territory product priorities which reference Product2 |

> **Design principle:** Country belongs on the **master data** (Product2, LifeSciMarketableProduct, ProductGuidance) — not on every transactional record. For reporting, join to Product2.Country__c.

---

## Population Strategy

```mermaid
flowchart TD
    START["New Record Created"] --> DECIDE{"Population Method?"}

    DECIDE -->|"Initial Load"| A["<b>Option A: Manual / Data Loader</b><br/>Set Country__c during creation<br/>Apex scripts in README-04"]
    DECIDE -->|"Ongoing Operations"| B["<b>Option B: Flow / Trigger</b><br/>Before-insert automation"]
    DECIDE -->|"Low Maintenance"| C["<b>Option C: Formula Field</b><br/>Product__r.Country__c"]

    B --> B1["1. Look up related Product2"]
    B1 --> B2["2. Copy Product2.Country__c"]
    B2 --> B3["3. Validate vs territory assignment"]

    C --> PROS["Always in sync, no logic needed"]
    C --> CONS["Cannot use in sharing rules,<br/>slower in reports, no mobile list view filters"]

    style START fill:#4a90d9,color:#fff
    style A fill:#7ed321,color:#fff
    style B fill:#7ed321,color:#fff
    style C fill:#f5a623,color:#fff
    style PROS fill:#e8f5e9,stroke:#7ed321
    style CONS fill:#fde8e8,stroke:#e74c3c
```

**Recommendation:** Use a stored picklist (Option A/B) for flexibility and performance.

---

## Deployment Order

```mermaid
flowchart TD
    GVS["0. Country GlobalValueSet ✅"] --> P2
    P2["1. Product2.Country__c ✅"] --> MP["2. LifeSciMarketableProduct ✅"]
    MP --> PG["3. ProductGuidance ✅"]

    style GVS fill:#7ed321,color:#fff,stroke-width:3px
    style P2 fill:#7ed321,color:#fff,stroke-width:3px
    style MP fill:#7ed321,color:#fff
    style PG fill:#7ed321,color:#fff
```

---

## SFDX Metadata Location

All custom field metadata is in:
```
force-app/main/default/objects/<ObjectName>/fields/Country__c.field-meta.xml
```

---

## Related READMEs

- [README-01: Product Hierarchy Architecture](README-01-Product-Hierarchy.md)
- [README-02: LSC Areas Where Products Appear](README-02-LSC-Product-Areas.md)
- [README-04: Data Loading Scripts](README-04-Data-Loading-Scripts.md)
- [README-05: Country Global Value Set](README-05-Country-Global-Value-Set.md)
- [README-06: Parent-Child Approaches](README-06-Parent-Child-Approaches.md)
- [README-07: Provider Account Territory Info](README-07-Provider-Account-Territory-Info.md)
- [README-08: Sample Management Setup](README-08-Sample-Management-Setup.md)
