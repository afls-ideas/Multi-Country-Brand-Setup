// ============================================================
// create-inventory-count-discrepancy.apex
// Creates an Inventory Count Assessment where some products
// have discrepancies — the rep's actual count differs from
// the system's expected quantity.
//
// This demonstrates how the platform handles mismatches:
//   - Some products match (actual = expected)
//   - Some products are short (actual < expected)
//   - Some products are over (actual > expected)
//
// Creates:
//   InventoryCountAssessment — the assessment header
//   InventoryCountProductItem — one per ProductItem
//   InventoryCntProdtBatchItem — one per ProductBatchItem
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';
String COUNT_TYPE          = 'Periodic';   // Initial, Adhoc, Periodic, Audited
String COUNT_PURPOSE       = 'Accuracy';   // Audit, Verification, Reconciliation, Adjustment, Compliance, Accuracy

// Discrepancy settings: how much to adjust actual vs expected
// Positive = over count, Negative = short count, 0 = match
// Applied per product in alphabetical order
List<Integer> DISCREPANCIES = new List<Integer>{
    -5,     // 1st product: short by 5
     0,     // 2nd product: matches
     3,     // 3rd product: over by 3
    -10     // 4th product: short by 10
};
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
    System.debug('ERROR: No inventory location for rep.');
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
    System.debug('ERROR: No ProductItem records at this location.');
    return;
}
System.debug('Found ' + productItems.size() + ' product items.');

Set<Id> productItemIds = new Set<Id>();
for (ProductItem pi : productItems) {
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

// Build a map of ProductItemId -> list of batch items
Map<Id, List<ProductBatchItem>> batchesByProductItem = new Map<Id, List<ProductBatchItem>>();
for (ProductBatchItem pbi : batchItems) {
    if (!batchesByProductItem.containsKey(pbi.ProductItemId)) {
        batchesByProductItem.put(pbi.ProductItemId, new List<ProductBatchItem>());
    }
    batchesByProductItem.get(pbi.ProductItemId).add(pbi);
}

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
// 5. CREATE INVENTORY COUNT PRODUCT ITEMS (WITH DISCREPANCIES)
// -----------------------------------------------------------

List<InventoryCountProductItem> icpItems = new List<InventoryCountProductItem>();
Map<Id, Integer> discrepancyByProductItemId = new Map<Id, Integer>();

for (Integer i = 0; i < productItems.size(); i++) {
    ProductItem pi = productItems[i];

    // Get discrepancy for this product (cycle through list if more products than discrepancies)
    Integer discrepancy = 0;
    if (i < DISCREPANCIES.size()) {
        discrepancy = DISCREPANCIES[i];
    }

    Decimal expectedQty = pi.QuantityOnHand;
    Decimal actualQty = expectedQty + discrepancy;
    if (actualQty < 0) actualQty = 0;  // Can't have negative count

    discrepancyByProductItemId.put(pi.Id, discrepancy);

    String marker = '';
    if (discrepancy < 0) marker = ' *** SHORT by ' + Math.abs(discrepancy) + ' ***';
    else if (discrepancy > 0) marker = ' *** OVER by ' + discrepancy + ' ***';
    else marker = ' (matches)';

    String reasonType = null;
    if (discrepancy < 0) reasonType = 'Lost';
    else if (discrepancy > 0) reasonType = 'Overcount';

    InventoryCountProductItem icp = new InventoryCountProductItem(
        InventoryCountAssessmentId = ica.Id,
        ProductItemId = pi.Id,
        AssigneeId = repUserId,
        PlannedStartDateTime = DateTime.now(),
        PlannedEndDateTime = DateTime.now().addHours(1),
        ActualStartDateTime = DateTime.now(),
        ActualEndDateTime = DateTime.now(),
        ExpectedQuantity = expectedQty,
        ActualQuantity = actualQty,
        Status = 'Complete'
    );
    if (reasonType != null) {
        icp.DiscrepancyReasonType = reasonType;
    }
    icpItems.add(icp);
    System.debug('  ' + pi.Product2.Name + ': expected=' + expectedQty
        + ' actual=' + actualQty + marker);
}

insert icpItems;
System.debug('Created ' + icpItems.size() + ' InventoryCountProductItem records.');

// Map ProductItemId -> InventoryCountProductItem Id
Map<Id, Id> icpByProductItemId = new Map<Id, Id>();
for (InventoryCountProductItem icp : icpItems) {
    icpByProductItemId.put(icp.ProductItemId, icp.Id);
}

// -----------------------------------------------------------
// 6. CREATE INVENTORY COUNT BATCH ITEMS (WITH DISCREPANCIES)
// -----------------------------------------------------------

List<InventoryCntProdtBatchItem> icbItems = new List<InventoryCntProdtBatchItem>();

for (ProductBatchItem pbi : batchItems) {
    Id icpId = icpByProductItemId.get(pbi.ProductItemId);
    Integer discrepancy = discrepancyByProductItemId.get(pbi.ProductItemId);

    Decimal expectedQty = pbi.RemainingQuantity;
    Decimal actualQty = expectedQty;

    // Apply discrepancy to the first batch of each product only
    // (simulates finding the discrepancy in one specific lot)
    List<ProductBatchItem> siblings = batchesByProductItem.get(pbi.ProductItemId);
    if (siblings != null && !siblings.isEmpty() && siblings[0].Id == pbi.Id && discrepancy != 0) {
        actualQty = expectedQty + discrepancy;
        if (actualQty < 0) actualQty = 0;
    }

    String reasonType = null;
    if (actualQty < expectedQty) reasonType = 'Lost';
    else if (actualQty > expectedQty) reasonType = 'Overcount';

    InventoryCntProdtBatchItem icb = new InventoryCntProdtBatchItem(
        InventoryCountAssessmentId = ica.Id,
        ProductBatchItemId = pbi.Id,
        ProductId = pbi.ProductItem.Product2Id,
        InventoryCountProductItemId = icpId,
        AssigneeId = repUserId,
        ExpectedQuantity = expectedQty,
        ActualQuantity = actualQty,
        Status = 'Completed'
    );
    if (reasonType != null) {
        icb.DiscrepancyReasonType = reasonType;
    }
    icbItems.add(icb);

    String marker = (actualQty != expectedQty) ?
        ' *** DISCREPANCY: ' + (actualQty - expectedQty) + ' ***' : '';
    System.debug('  Batch: ' + pbi.ProductionBatch.Name + ' (' + pbi.ProductItem.Product2.Name
        + ') expected=' + expectedQty + ' actual=' + actualQty + marker);
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

Integer discrepancyCount = 0;
for (Integer d : DISCREPANCIES) {
    if (d != 0) discrepancyCount++;
}

System.debug('============================================');
System.debug('INVENTORY COUNT ASSESSMENT (WITH DISCREPANCIES)');
System.debug('  Assessment:     ' + ica.Id);
System.debug('  Rep:            ' + repName);
System.debug('  Location:       ' + locations[0].Name);
System.debug('  Type:           ' + COUNT_TYPE);
System.debug('  Status:         Complete');
System.debug('  Product Items:  ' + icpItems.size());
System.debug('  Batch Items:    ' + batchSuccess + ' (skipped: ' + batchFail + ')');
System.debug('  Discrepancies:  ' + discrepancyCount + ' products');
System.debug('============================================');
