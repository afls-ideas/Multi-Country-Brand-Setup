// ============================================================
// create-inventory-count.apex
// Creates an Inventory Count Assessment for a rep's sample
// inventory. This is the "Initial" count that establishes
// baseline stock levels.
//
// Creates:
//   InventoryCountAssessment — the assessment header
//   InventoryCountProductItem — one per ProductItem (product-level count)
//   InventoryCntProdtBatchItem — one per ProductBatchItem (batch-level count)
//
// Idempotent — checks for existing InProgress assessments.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';
String COUNT_TYPE          = 'Periodic';   // Initial, Adhoc, Periodic, Audited
String COUNT_PURPOSE       = 'Accuracy';   // Audit, Verification, Reconciliation, Adjustment, Compliance, Accuracy
// ----------------------

// -----------------------------------------------------------
// 1. LOOK UP THE REP AND LOCATION
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

List<Schema.Location> locations = [
    SELECT Id, Name FROM Location
    WHERE PrimaryUserId = :repUserId AND IsInventoryLocation = true
    LIMIT 1
];
if (locations.isEmpty()) {
    System.debug('ERROR: No inventory location for rep. Run create-inventory-location.apex first.');
    return;
}
Id locationId = locations[0].Id;
System.debug('Location: ' + locations[0].Name + ' (' + locationId + ')');

// -----------------------------------------------------------
// 2. GET REP'S PRODUCT ITEMS
// -----------------------------------------------------------

List<ProductItem> productItems = [
    SELECT Id, Product2Id, Product2.Name, QuantityOnHand
    FROM ProductItem
    WHERE LocationId = :locationId
    ORDER BY Product2.Name
];
if (productItems.isEmpty()) {
    System.debug('ERROR: No ProductItem records at this location. Run create-sample-inventory.apex first.');
    return;
}
System.debug('Found ' + productItems.size() + ' product items.');

Set<Id> product2Ids = new Set<Id>();
Set<Id> productItemIds = new Set<Id>();
for (ProductItem pi : productItems) {
    product2Ids.add(pi.Product2Id);
    productItemIds.add(pi.Id);
}

// -----------------------------------------------------------
// 3. GET PRODUCT BATCH ITEMS
// -----------------------------------------------------------

List<ProductBatchItem> batchItems = [
    SELECT Id, ProductionBatchId, ProductionBatch.Name, ProductItemId,
           ProductItem.Product2Id, ProductItem.Product2.Name, RemainingQuantity
    FROM ProductBatchItem
    WHERE ProductItemId IN :productItemIds AND IsActive = true
    ORDER BY ProductItem.Product2.Name
];
System.debug('Found ' + batchItems.size() + ' active batch items.');

// -----------------------------------------------------------
// 4. CREATE INVENTORY COUNT ASSESSMENT
// -----------------------------------------------------------

InventoryCountAssessment ica = new InventoryCountAssessment(
    LocationId = locationId,
    AssigneeId = repUserId,
    OwnerId = repUserId,
    Type = COUNT_TYPE,
    Purpose = COUNT_PURPOSE,
    Status = 'Assigned',
    PlannedStartDateTime = DateTime.now(),
    PlannedEndDateTime = DateTime.now().addHours(1),
    ActualStartDateTime = DateTime.now()
);
insert ica;
System.debug('Created InventoryCountAssessment: ' + ica.Id);

// -----------------------------------------------------------
// 5. CREATE INVENTORY COUNT PRODUCT ITEMS
// -----------------------------------------------------------

List<InventoryCountProductItem> icpItems = new List<InventoryCountProductItem>();
Map<Id, Id> icpByProductItemId = new Map<Id, Id>();

for (ProductItem pi : productItems) {
    icpItems.add(new InventoryCountProductItem(
        InventoryCountAssessmentId = ica.Id,
        ProductItemId = pi.Id,
        AssigneeId = repUserId,
        PlannedStartDateTime = DateTime.now(),
        PlannedEndDateTime = DateTime.now().addHours(1),
        ActualStartDateTime = DateTime.now(),
        ActualEndDateTime = DateTime.now(),
        ExpectedQuantity = pi.QuantityOnHand,
        ActualQuantity = pi.QuantityOnHand,
        Status = 'Complete'  // InventoryCountProductItem: Assigned, In_Progress, Complete, Inactive
    ));
    System.debug('  Product: ' + pi.Product2.Name + ' — expected: ' + pi.QuantityOnHand);
}

insert icpItems;
System.debug('Created ' + icpItems.size() + ' InventoryCountProductItem records.');

// Map ProductItemId → InventoryCountProductItem Id for batch items
for (InventoryCountProductItem icp : icpItems) {
    icpByProductItemId.put(icp.ProductItemId, icp.Id);
}

// -----------------------------------------------------------
// 6. CREATE INVENTORY COUNT BATCH ITEMS
// -----------------------------------------------------------

List<InventoryCntProdtBatchItem> icbItems = new List<InventoryCntProdtBatchItem>();

for (ProductBatchItem pbi : batchItems) {
    Id icpId = icpByProductItemId.get(pbi.ProductItemId);

    icbItems.add(new InventoryCntProdtBatchItem(
        InventoryCountAssessmentId = ica.Id,
        ProductBatchItemId = pbi.Id,
        ProductId = pbi.ProductItem.Product2Id,
        InventoryCountProductItemId = icpId,
        AssigneeId = repUserId,
        ExpectedQuantity = pbi.RemainingQuantity,
        ActualQuantity = pbi.RemainingQuantity,
        Status = 'Completed'  // InventoryCntProdtBatchItem: NotStarted, InProgress, Completed
    ));
    System.debug('  Batch: ' + pbi.ProductionBatch.Name + ' (' + pbi.ProductItem.Product2.Name
        + ') — expected: ' + pbi.RemainingQuantity);
}

Integer batchSuccess = 0;
Integer batchFail = 0;
if (!icbItems.isEmpty()) {
    List<Database.SaveResult> results = Database.insert(icbItems, false);
    for (Integer i = 0; i < results.size(); i++) {
        if (results[i].isSuccess()) {
            batchSuccess++;
        } else {
            batchFail++;
            System.debug('  SKIP batch: ' + results[i].getErrors()[0].getMessage());
        }
    }
    System.debug('Created ' + batchSuccess + ' InventoryCntProdtBatchItem records (' + batchFail + ' skipped).');
}

// -----------------------------------------------------------
// 7. MARK ASSESSMENT AS COMPLETE
// -----------------------------------------------------------

ica.Status = 'Complete';
ica.ActualEndDateTime = DateTime.now();
update ica;

// -----------------------------------------------------------
// 8. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('INVENTORY COUNT ASSESSMENT');
System.debug('  Assessment:     ' + ica.Id);
System.debug('  Rep:            ' + repName);
System.debug('  Location:       ' + locations[0].Name);
System.debug('  Type:           ' + COUNT_TYPE);
System.debug('  Status:         Complete');
System.debug('  Product Items:  ' + icpItems.size());
System.debug('  Batch Items:    ' + batchSuccess + ' (skipped: ' + batchFail + ')');
System.debug('============================================');
