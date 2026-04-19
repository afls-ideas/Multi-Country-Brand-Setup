// ============================================================
// create-sample-shipment.apex
// Creates a Product Transfer (shipment) from a warehouse to
// a rep's inventory location. This simulates the production
// flow where a rep receives a shipment of samples.
//
// Creates:
//   ProductTransfer — one per product/batch being shipped
//
// The platform automatically increments ProductItem.QuantityOnHand
// and ProductBatchItem.RemainingQuantity when the transfer is
// marked as received.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';
String WAREHOUSE_NAME     = 'GB Sample Warehouse';  // Source warehouse
Integer SHIPMENT_QTY      = 100;                     // Quantity per product/batch
// ----------------------

// -----------------------------------------------------------
// 1. LOOK UP THE REP AND LOCATIONS
// -----------------------------------------------------------

List<Territory2> territories = [
    SELECT Id, Name FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}

List<UserTerritory2Association> utas = [
    SELECT UserId, User.Name
    FROM UserTerritory2Association
    WHERE Territory2Id = :territories[0].Id LIMIT 1
];
if (utas.isEmpty()) {
    System.debug('ERROR: No user assigned to territory.');
    return;
}
Id repUserId = utas[0].UserId;
String repName = utas[0].User.Name;
System.debug('Rep: ' + repName + ' (' + repUserId + ')');

// Rep's inventory location
List<Schema.Location> repLocations = [
    SELECT Id, Name FROM Location
    WHERE PrimaryUserId = :repUserId AND IsInventoryLocation = true
    LIMIT 1
];
if (repLocations.isEmpty()) {
    System.debug('ERROR: No inventory location for rep.');
    return;
}
Id destLocationId = repLocations[0].Id;
System.debug('Destination: ' + repLocations[0].Name + ' (' + destLocationId + ')');

// Warehouse location — create if not found
List<Schema.Location> warehouses = [
    SELECT Id, Name FROM Location
    WHERE Name = :WAREHOUSE_NAME LIMIT 1
];
Id sourceLocationId;
if (warehouses.isEmpty()) {
    Schema.Location wh = new Schema.Location(
        Name = WAREHOUSE_NAME,
        LocationType = 'Warehouse',
        IsInventoryLocation = true
    );
    insert wh;
    sourceLocationId = wh.Id;
    System.debug('Created warehouse: ' + WAREHOUSE_NAME + ' (' + sourceLocationId + ')');
} else {
    sourceLocationId = warehouses[0].Id;
    System.debug('Warehouse: ' + warehouses[0].Name + ' (' + sourceLocationId + ')');
}

// -----------------------------------------------------------
// 2. GET REP'S PRODUCT ITEMS AND BATCHES
// -----------------------------------------------------------

List<ProductItem> repProductItems = [
    SELECT Id, Product2Id, Product2.Name, QuantityOnHand
    FROM ProductItem
    WHERE LocationId = :destLocationId
    ORDER BY Product2.Name
];
if (repProductItems.isEmpty()) {
    System.debug('ERROR: No ProductItem records at rep location.');
    return;
}
System.debug('Found ' + repProductItems.size() + ' product items at rep location.');

// Collect product IDs to find batches
Set<Id> product2Ids = new Set<Id>();
for (ProductItem pi : repProductItems) {
    product2Ids.add(pi.Product2Id);
}

// Get production batches for these products
List<ProductionBatch> batches = [
    SELECT Id, Name, ProductId, Product.Name
    FROM ProductionBatch
    WHERE ProductId IN :product2Ids AND IsActive = true
    ORDER BY Product.Name
];
System.debug('Found ' + batches.size() + ' active production batches.');

// -----------------------------------------------------------
// 3. CREATE WAREHOUSE INVENTORY (SOURCE)
// -----------------------------------------------------------
// ProductTransfer requires a SourceProductItemId — the warehouse
// must have its own ProductItem records as the source of the shipment.

// Check for existing warehouse ProductItems
Map<Id, ProductItem> existingWhItems = new Map<Id, ProductItem>();
for (ProductItem wpi : [
    SELECT Id, Product2Id FROM ProductItem
    WHERE LocationId = :sourceLocationId AND Product2Id IN :product2Ids
]) {
    existingWhItems.put(wpi.Product2Id, wpi);
}

// Create missing warehouse ProductItems
List<ProductItem> newWhItems = new List<ProductItem>();
for (Id pid : product2Ids) {
    if (!existingWhItems.containsKey(pid)) {
        newWhItems.add(new ProductItem(
            Product2Id = pid,
            LocationId = sourceLocationId,
            QuantityOnHand = 100000,
            QuantityUnitOfMeasure = 'Each'
        ));
    }
}
if (!newWhItems.isEmpty()) {
    insert newWhItems;
    System.debug('Created ' + newWhItems.size() + ' warehouse ProductItem records.');
    for (ProductItem wpi : newWhItems) {
        existingWhItems.put(wpi.Product2Id, wpi);
    }
}

// Create warehouse ProductBatchItems (junction: batch → warehouse ProductItem)
Set<Id> batchIds = new Set<Id>();
for (ProductionBatch pb : batches) {
    batchIds.add(pb.Id);
}

Map<String, ProductBatchItem> existingWhBatchItems = new Map<String, ProductBatchItem>();
for (ProductBatchItem wpbi : [
    SELECT Id, ProductionBatchId, ProductItemId
    FROM ProductBatchItem
    WHERE ProductItemId IN (SELECT Id FROM ProductItem WHERE LocationId = :sourceLocationId)
      AND ProductionBatchId IN :batchIds
]) {
    existingWhBatchItems.put(wpbi.ProductionBatchId + ':' + wpbi.ProductItemId, wpbi);
}

List<ProductBatchItem> newWhBatchItems = new List<ProductBatchItem>();
for (ProductionBatch pb : batches) {
    ProductItem whPi = existingWhItems.get(pb.ProductId);
    String key = pb.Id + ':' + whPi.Id;
    if (!existingWhBatchItems.containsKey(key)) {
        newWhBatchItems.add(new ProductBatchItem(
            ProductionBatchId = pb.Id,
            ProductItemId = whPi.Id,
            RemainingQuantity = 100000,
            IsActive = true
        ));
    }
}
if (!newWhBatchItems.isEmpty()) {
    insert newWhBatchItems;
    System.debug('Created ' + newWhBatchItems.size() + ' warehouse ProductBatchItem records.');
}

// -----------------------------------------------------------
// 4. CREATE PRODUCT TRANSFERS
// -----------------------------------------------------------

List<ProductTransfer> transfers = new List<ProductTransfer>();

for (ProductionBatch pb : batches) {
    ProductItem whPi = existingWhItems.get(pb.ProductId);

    transfers.add(new ProductTransfer(
        SourceLocationId = sourceLocationId,
        DestinationLocationId = destLocationId,
        SourceProductItemId = whPi.Id,
        Product2Id = pb.ProductId,
        ProductionBatchId = pb.Id,
        QuantitySent = SHIPMENT_QTY,
        QuantityReceived = SHIPMENT_QTY,
        QuantityUnitOfMeasure = 'Each',
        ReceivedById = repUserId,
        ReceivedDateTime = DateTime.now(),
        IsReceived = true,
        OwnerId = repUserId
    ));
    System.debug('  Transfer: ' + pb.Product.Name
        + ' / ' + pb.Name + ' qty=' + SHIPMENT_QTY);
}

Integer successCount = 0;
Integer failCount = 0;
if (!transfers.isEmpty()) {
    List<Database.SaveResult> results = Database.insert(transfers, false);
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            successCount++;
        } else {
            failCount++;
            System.debug('  FAIL: ' + results[i].getErrors()[0].getMessage());
        }
    }
}

// -----------------------------------------------------------
// 5. VERIFY INVENTORY CHANGES
// -----------------------------------------------------------

// Re-query to see if quantities were updated
List<ProductItem> updatedItems = [
    SELECT Product2.Name, QuantityOnHand
    FROM ProductItem
    WHERE LocationId = :destLocationId
    ORDER BY Product2.Name
];

System.debug('============================================');
System.debug('SAMPLE SHIPMENT');
System.debug('  Rep:           ' + repName);
System.debug('  Warehouse:     ' + WAREHOUSE_NAME);
System.debug('  Destination:   ' + repLocations[0].Name);
System.debug('  Qty per batch: ' + SHIPMENT_QTY);
System.debug('  Transfers:     ' + successCount + ' created (' + failCount + ' failed)');
System.debug('--------------------------------------------');
System.debug('  UPDATED INVENTORY:');
for (ProductItem pi : updatedItems) {
    System.debug('    ' + pi.Product2.Name + ': ' + pi.QuantityOnHand);
}
System.debug('============================================');
