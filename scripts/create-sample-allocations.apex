// ============================================================
// create-sample-allocations.apex
// Creates TerritoryProdtQtyAllocation records for sample
// products in a target territory. Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';  // Target territory (DeveloperName)
String COUNTRY_CODE       = 'GB';                  // Country filter for sample products
Integer DROP_QUANTITY     = 10000;                  // Allocated qty for Drop type
Integer SHIP_QUANTITY     = 1000;                   // Allocated qty for Ship type
// ----------------------

// Step 1: Look up the target territory
List<Territory2> territories = [
    SELECT Id, Name, DeveloperName
    FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME
    LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}
Territory2 territory = territories[0];
System.debug('Found territory: ' + territory.Name + ' (' + territory.Id + ')');

// Step 2: Find sample-level Product2 records for this country
List<Product2> sampleProducts = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE Family = 'Sample' AND Country__c = :COUNTRY_CODE AND IsActive = true
    ORDER BY Name
];
if (sampleProducts.isEmpty()) {
    System.debug('ERROR: No active sample products found for country: ' + COUNTRY_CODE);
    return;
}
System.debug('Found ' + sampleProducts.size() + ' sample products for ' + COUNTRY_CODE);

// Step 3: Find a current TimePeriod (covers today)
Date today = Date.today();
List<TimePeriod> timePeriods = [
    SELECT Id, Name, StartDate, EndDate
    FROM TimePeriod
    WHERE StartDate <= :today AND EndDate >= :today
    ORDER BY EndDate ASC
    LIMIT 1
];
if (timePeriods.isEmpty()) {
    System.debug('ERROR: No active TimePeriod covers today (' + today + '). Create one first.');
    return;
}
TimePeriod tp = timePeriods[0];
System.debug('Using TimePeriod: ' + tp.Name + ' (' + tp.StartDate + ' to ' + tp.EndDate + ')');

// Step 4: Check for existing allocations (idempotency)
Set<Id> productIds = new Set<Id>();
for (Product2 p : sampleProducts) {
    productIds.add(p.Id);
}
Map<String, TerritoryProdtQtyAllocation> existingMap = new Map<String, TerritoryProdtQtyAllocation>();
for (TerritoryProdtQtyAllocation existing : [
    SELECT Id, ProductId, TerritoryId, AllocationType, TimePeriodId
    FROM TerritoryProdtQtyAllocation
    WHERE ProductId IN :productIds
      AND TerritoryId = :territory.Id
      AND TimePeriodId = :tp.Id
]) {
    String key = existing.ProductId + '_' + existing.AllocationType;
    existingMap.put(key, existing);
}

// Step 5: Create allocation records (Drop + Ship per product)
List<TerritoryProdtQtyAllocation> toInsert = new List<TerritoryProdtQtyAllocation>();
List<TerritoryProdtQtyAllocation> toUpdate = new List<TerritoryProdtQtyAllocation>();

for (Product2 p : sampleProducts) {
    for (String allocType : new List<String>{ 'Drop', 'Ship' }) {
        Integer qty = allocType == 'Drop' ? DROP_QUANTITY : SHIP_QUANTITY;
        String key = p.Id + '_' + allocType;

        if (existingMap.containsKey(key)) {
            TerritoryProdtQtyAllocation existing = existingMap.get(key);
            existing.AllocatedQuantity = qty;
            toUpdate.add(existing);
            System.debug('UPDATE: ' + p.Name + ' / ' + allocType + ' -> ' + qty);
        } else {
            toInsert.add(new TerritoryProdtQtyAllocation(
                ProductId = p.Id,
                TerritoryId = territory.Id,
                TimePeriodId = tp.Id,
                AllocationType = allocType,
                AllocatedQuantity = qty
            ));
            System.debug('INSERT: ' + p.Name + ' / ' + allocType + ' -> ' + qty);
        }
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' allocation records.');
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' existing allocation records.');
}

System.debug('=== DONE: Sample allocations for ' + territory.Name + ' ===');
