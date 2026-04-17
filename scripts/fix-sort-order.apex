// ============================================================
// fix-sort-order.apex
// Sets SortOrder on ProductTerrDtlAvailability records for a
// target territory. After PTA batch expansion, SortOrder is
// null — the Samples panel requires SortOrder != null.
// Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';  // Target territory (DeveloperName)
// ----------------------

// Step 1: Look up the target territory
List<Territory2> territories = [
    SELECT Id, Name FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}
Territory2 territory = territories[0];
System.debug('Found territory: ' + territory.Name);

// Step 2: Find ProductTerrDtlAvailability records with null SortOrder
List<ProductTerrDtlAvailability> ptdas = [
    SELECT Id, ProductId, SortOrder, Name
    FROM ProductTerrDtlAvailability
    WHERE TerritoryId = :territory.Id AND SortOrder = null
    ORDER BY Name
];

if (ptdas.isEmpty()) {
    System.debug('All ProductTerrDtlAvailability records already have SortOrder set.');
    return;
}

// Step 3: Set SortOrder sequentially
Integer sortNum = 1;

// Check what the max existing SortOrder is (in case some are already set)
List<ProductTerrDtlAvailability> existing = [
    SELECT SortOrder FROM ProductTerrDtlAvailability
    WHERE TerritoryId = :territory.Id AND SortOrder != null
    ORDER BY SortOrder DESC LIMIT 1
];
if (!existing.isEmpty()) {
    sortNum = existing[0].SortOrder + 1;
}

for (ProductTerrDtlAvailability p : ptdas) {
    p.SortOrder = sortNum++;
    System.debug('SET: ' + p.Name + ' -> SortOrder = ' + p.SortOrder);
}

update ptdas;
System.debug('Updated SortOrder on ' + ptdas.size() + ' records (starting from ' + (sortNum - ptdas.size()) + ').');
System.debug('=== DONE: SortOrder fix for ' + territory.Name + ' ===');
