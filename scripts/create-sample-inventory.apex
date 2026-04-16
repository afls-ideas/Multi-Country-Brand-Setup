// ============================================================
// create-sample-inventory.apex
// Creates ProductItem records in a rep's inventory location
// for sample products. The rep must have inventory of the
// sample products for them to appear in the Samples panel
// during Visit Engagement — see README-08 query #8.
// Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';  // Target territory (DeveloperName)
String COUNTRY_CODE       = 'GB';                  // Country filter for sample products
Integer INITIAL_QUANTITY  = 1000;                   // Starting inventory per product
// ----------------------

// Step 1: Look up the rep assigned to this territory
List<Territory2> territories = [
    SELECT Id, Name FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}
Territory2 territory = territories[0];

List<UserTerritory2Association> utas = [
    SELECT UserId, User.Username FROM UserTerritory2Association
    WHERE Territory2Id = :territory.Id LIMIT 1
];
if (utas.isEmpty()) {
    System.debug('ERROR: No user assigned to territory ' + territory.Name);
    return;
}
Id repUserId = utas[0].UserId;
System.debug('Rep: ' + utas[0].User.Username);

// Step 2: Find the rep's inventory location
List<Location> locations = [
    SELECT Id, Name FROM Location
    WHERE PrimaryUserId = :repUserId
      AND IsInventoryLocation = true
      AND LocationType = 'User Inventory'
    LIMIT 1
];
if (locations.isEmpty()) {
    System.debug('ERROR: No inventory location found for rep. Create a Location with LocationType = "User Inventory" first.');
    return;
}
Id locationId = locations[0].Id;
System.debug('Inventory location: ' + locations[0].Name + ' (' + locationId + ')');

// Step 3: Find sample-level Product2 records for this country
List<Product2> sampleProducts = [
    SELECT Id, Name, ProductCode FROM Product2
    WHERE Family = 'Sample' AND Country__c = :COUNTRY_CODE AND IsActive = true
    ORDER BY Name
];
if (sampleProducts.isEmpty()) {
    System.debug('ERROR: No active sample products found for country: ' + COUNTRY_CODE);
    return;
}
System.debug('Found ' + sampleProducts.size() + ' sample products');

// Step 4: Check for existing ProductItem records (idempotency)
Set<Id> sampleProduct2Ids = new Set<Id>();
for (Product2 p : sampleProducts) {
    sampleProduct2Ids.add(p.Id);
}
Set<Id> existingProduct2Ids = new Set<Id>();
for (ProductItem existing : [
    SELECT Product2Id FROM ProductItem
    WHERE LocationId = :locationId AND Product2Id IN :sampleProduct2Ids
]) {
    existingProduct2Ids.add(existing.Product2Id);
}

// Step 5: Create ProductItem records
List<ProductItem> toInsert = new List<ProductItem>();
for (Product2 p : sampleProducts) {
    if (existingProduct2Ids.contains(p.Id)) {
        System.debug('SKIP (exists): ' + p.Name);
        continue;
    }
    toInsert.add(new ProductItem(
        LocationId = locationId,
        Product2Id = p.Id,
        QuantityOnHand = INITIAL_QUANTITY,
        QuantityUnitOfMeasure = 'Each'
    ));
    System.debug('INSERT: ' + p.Name + ' qty=' + INITIAL_QUANTITY);
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' ProductItem records.');
} else {
    System.debug('All inventory items already exist. Nothing to insert.');
}

System.debug('=== DONE: Sample inventory for ' + territory.Name + ' ===');
