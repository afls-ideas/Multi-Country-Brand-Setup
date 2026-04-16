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

> To add a new country, edit only `force-app/main/default/globalValueSets/Country.globalValueSet-meta.xml` — all 10 fields inherit the change.

---

## Objects Requiring Country__c

### Tier 1: Essential (Deploy First)

These objects are core to the multi-country product setup and MUST have Country__c.

| # | Object API Name | Why Country__c Is Needed | Populating Strategy | Deployed to 260-pm |
|---|---|---|---|---|
| 1 | `Product2` | Identifies which country a sub-brand or sample belongs to | Set during record creation; inherited from hierarchy | YES |
| 2 | `LifeSciMarketableProduct` | Filter marketable products by country; validate territory alignment | Copy from related Product2.Country__c | YES |
| 3 | `ProductGuidance` | Country-specific product messages; admin filtering | Copy from related Product2.Country__c | YES |
| 4 | `LifeSciTerritoryProductPriority` | Manage priorities by country; prevent cross-country misalignment | Copy from related Product2.Country__c | NO — object not provisioned |

### Tier 2: Important (Deploy Second)

These objects benefit significantly from direct country filtering.

| # | Object API Name | Why Country__c Is Needed | Populating Strategy | Deployed to 260-pm |
|---|---|---|---|---|
| 5 | `LifeSciProductAccountRestriction` | Country-specific formulary/compliance restrictions | Copy from related Product2.Country__c | NO — object not provisioned |
| 6 | `TerritoryProductQtyAllocation` | Country-specific sample allocation quantities | Copy from related Product2.Country__c | NO — object not provisioned |
| 7 | `SampleTransaction` | Compliance reporting by country (PDMA vs EU rules) | Copy from related Product2.Country__c | NO — object not provisioned |
| 8 | `SampleLot` | Country-specific lot tracking and expiry management | Copy from related Product2.Country__c | NO — object not provisioned |
| 9 | `SampleInventory` | Country-level inventory reporting | Copy from related Product2.Country__c | NO — object not provisioned |
| 10 | `LifeSciCallDiscussion` | Multi-country call analytics and reporting | Copy from related Product2.Country__c | NO — object not provisioned |

> **Note (2026-04-15):** 7 of 10 objects are not yet provisioned in the 260-pm org. They require LSC feature licenses for Sample Management, Territory Management, and Call Discussion to be enabled. The Country GVS and 3 fields (Product2, LifeSciMarketableProduct, ProductGuidance) deployed successfully.

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

    P2["1. Product2.Country__c ✅"] --> T1

    subgraph T1["Tier 1: Essential"]
        MP["2. LifeSciMarketableProduct ✅"]
        PG["3. ProductGuidance ✅"]
        TPP["4. LifeSciTerritoryProductPriority ⛔"]
    end

    T1 --> T2

    subgraph T2["Tier 2: Important — objects not provisioned in 260-pm"]
        PAR["5. LifeSciProductAccountRestriction ⛔"]
        TPA["6. TerritoryProductQtyAllocation ⛔"]
        ST["7. SampleTransaction ⛔"]
        SL["8. SampleLot ⛔"]
        SI["9. SampleInventory ⛔"]
        CD["10. LifeSciCallDiscussion ⛔"]
    end

    style GVS fill:#7ed321,color:#fff,stroke-width:3px
    style P2 fill:#7ed321,color:#fff,stroke-width:3px
    style MP fill:#7ed321,color:#fff
    style PG fill:#7ed321,color:#fff
    style TPP fill:#e74c3c,color:#fff
    style T1 fill:#fff3e0,stroke:#f5a623
    style T2 fill:#fde8e8,stroke:#e74c3c
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
