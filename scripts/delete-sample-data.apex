// ============================================================
// delete-sample-data.apex
// Deletes TerritoryProdtQtyAllocation and ProviderSampleLimit
// records for a target territory and country. Safe cleanup.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';  // Target territory (DeveloperName)
String COUNTRY_CODE       = 'GB';                  // Country filter
// ----------------------

// Step 1: Look up the target territory
List<Territory2> territories = [
    SELECT Id, Name
    FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME
    LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('Territory not found: ' + TERRITORY_DEV_NAME + '. Nothing to delete.');
    return;
}
Territory2 territory = territories[0];

// Step 2: Delete TerritoryProdtQtyAllocation records
List<Product2> sampleProducts = [
    SELECT Id FROM Product2
    WHERE Family = 'Sample' AND Country__c = :COUNTRY_CODE
];
Set<Id> sampleProductIds = new Set<Id>();
for (Product2 p : sampleProducts) {
    sampleProductIds.add(p.Id);
}

List<TerritoryProdtQtyAllocation> allocations = [
    SELECT Id FROM TerritoryProdtQtyAllocation
    WHERE TerritoryId = :territory.Id AND ProductId IN :sampleProductIds
];
if (!allocations.isEmpty()) {
    delete allocations;
    System.debug('Deleted ' + allocations.size() + ' TerritoryProdtQtyAllocation records.');
} else {
    System.debug('No TerritoryProdtQtyAllocation records to delete.');
}

// Step 3: Delete ProviderSampleLimit records
List<LifeSciMarketableProduct> mktProducts = [
    SELECT Id FROM LifeSciMarketableProduct
    WHERE Country__c = :COUNTRY_CODE AND Type = 'Brand'
];
Set<Id> mktProductIds = new Set<Id>();
for (LifeSciMarketableProduct mp : mktProducts) {
    mktProductIds.add(mp.Id);
}

// Find accounts in the territory
Set<Id> accountIds = new Set<Id>();
for (ProviderAcctTerritoryInfo pati : [
    SELECT AccountId FROM ProviderAcctTerritoryInfo
    WHERE Territory2Id = :territory.Id
]) {
    accountIds.add(pati.AccountId);
}

if (!accountIds.isEmpty() && !mktProductIds.isEmpty()) {
    List<ProviderSampleLimit> limits = [
        SELECT Id FROM ProviderSampleLimit
        WHERE AccountId IN :accountIds AND ProductId IN :mktProductIds
    ];
    if (!limits.isEmpty()) {
        delete limits;
        System.debug('Deleted ' + limits.size() + ' ProviderSampleLimit records.');
    } else {
        System.debug('No ProviderSampleLimit records to delete.');
    }
} else {
    System.debug('No accounts or marketable products found. Nothing to delete.');
}

System.debug('=== DONE: Sample data cleanup for ' + territory.Name + ' ===');
