// ============================================================
// Sample Production Batches — Idempotent Script
// ============================================================
// Creates ProductionBatch (lot/batch) records AND links them
// to the rep's inventory via ProductBatchItem. Both are needed
// for the "Production Batch ID" picker to appear during
// Visit Engagement on mobile.
//
//   ProductionBatch  — the lot (expiry, product)
//        ↓
//   ProductBatchItem — junction to the rep's ProductItem
//        ↓
//   ProductItem      — the rep's physical inventory
//
// Creates 2 batches per sample product with staggered expiry
// dates. Safe to re-run — checks for existing records.
// ============================================================

// ---- CONFIGURABLE ----
String COUNTRY_CODE    = 'GB';  // Country filter
Decimal REMAINING_QTY  = 500;   // Remaining qty per batch item
// ----------------------

// -----------------------------------------------------------
// 1. FIND SAMPLE PRODUCTS
// -----------------------------------------------------------

List<Product2> sampleProducts = [
    SELECT Id, Name
    FROM Product2
    WHERE Family = 'Sample' AND Country__c = :COUNTRY_CODE
    ORDER BY Name
];
System.debug('Found ' + sampleProducts.size() + ' sample products for ' + COUNTRY_CODE + '.');

if (sampleProducts.isEmpty()) {
    System.debug('ERROR: No sample products found. Run create-products.apex first.');
    return;
}

Set<Id> productIds = new Set<Id>();
for (Product2 p : sampleProducts) { productIds.add(p.Id); }

// -----------------------------------------------------------
// 2. CREATE PRODUCTION BATCHES
// -----------------------------------------------------------

Map<Id, Integer> existingCountByProduct = new Map<Id, Integer>();
for (AggregateResult ar : [
    SELECT ProductId, COUNT(Id) cnt
    FROM ProductionBatch
    WHERE ProductId IN :productIds
    GROUP BY ProductId
]) {
    existingCountByProduct.put((Id) ar.get('ProductId'), (Integer) ar.get('cnt'));
}

List<ProductionBatch> batchesToInsert = new List<ProductionBatch>();

for (Product2 p : sampleProducts) {
    Integer existingCount = existingCountByProduct.get(p.Id);
    if (existingCount != null && existingCount >= 2) {
        System.debug('  [SKIP] ' + p.Name + ' — already has ' + existingCount + ' batches');
        continue;
    }

    // Batch 1: expires in 1 year
    batchesToInsert.add(new ProductionBatch(
        ProductId = p.Id,
        IsActive = true,
        BatchCreatedDate = DateTime.now().addDays(-30),
        ExpirationDate = DateTime.now().addMonths(12),
        QuantityUnitOfMeasure = 'Each'
    ));

    // Batch 2: expires in 2 years
    batchesToInsert.add(new ProductionBatch(
        ProductId = p.Id,
        IsActive = true,
        BatchCreatedDate = DateTime.now().addDays(-15),
        ExpirationDate = DateTime.now().addMonths(24),
        QuantityUnitOfMeasure = 'Each'
    ));

    System.debug('  [CREATE] 2 batches for ' + p.Name);
}

if (!batchesToInsert.isEmpty()) {
    insert batchesToInsert;
}
System.debug('Created ' + batchesToInsert.size() + ' ProductionBatch records.');

// -----------------------------------------------------------
// 3. LINK BATCHES TO REP INVENTORY (ProductBatchItem)
// -----------------------------------------------------------

// Get all batches for these products (including pre-existing)
List<ProductionBatch> allBatches = [
    SELECT Id, Name, ProductId, Product.Name
    FROM ProductionBatch
    WHERE ProductId IN :productIds AND IsActive = true
    ORDER BY Product.Name
];

// Get ProductItems (rep inventory) by Product2Id
Map<Id, Id> itemByProduct2Id = new Map<Id, Id>();
for (ProductItem pi : [
    SELECT Id, Product2Id
    FROM ProductItem
    WHERE Product2Id IN :productIds
]) {
    itemByProduct2Id.put(pi.Product2Id, pi.Id);
}

// Check existing ProductBatchItems
Set<String> existingKeys = new Set<String>();
for (ProductBatchItem pbi : [
    SELECT ProductionBatchId, ProductItemId
    FROM ProductBatchItem
    WHERE ProductionBatchId IN (SELECT Id FROM ProductionBatch WHERE ProductId IN :productIds)
]) {
    existingKeys.add(pbi.ProductionBatchId + '-' + pbi.ProductItemId);
}

List<ProductBatchItem> itemsToInsert = new List<ProductBatchItem>();
for (ProductionBatch pb : allBatches) {
    Id productItemId = itemByProduct2Id.get(pb.ProductId);
    if (productItemId == null) {
        System.debug('  [SKIP] ' + pb.Name + ' — no ProductItem for ' + pb.Product.Name);
        continue;
    }

    String key = pb.Id + '-' + productItemId;
    if (existingKeys.contains(key)) {
        System.debug('  [EXISTS] ' + pb.Name + ' → ProductItem');
        continue;
    }

    itemsToInsert.add(new ProductBatchItem(
        ProductionBatchId = pb.Id,
        ProductItemId = productItemId,
        RemainingQuantity = REMAINING_QTY,
        IsActive = true
    ));
    System.debug('  [CREATE] ' + pb.Name + ' → ' + pb.Product.Name + ' (qty: ' + REMAINING_QTY + ')');
}

if (!itemsToInsert.isEmpty()) {
    insert itemsToInsert;
}
System.debug('Created ' + itemsToInsert.size() + ' ProductBatchItem records.');

// -----------------------------------------------------------
// 4. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('PRODUCTION BATCHES SUMMARY');
System.debug('  ProductionBatch created:  ' + batchesToInsert.size());
System.debug('  ProductBatchItem created: ' + itemsToInsert.size());
System.debug('============================================');

for (ProductionBatch pb : allBatches) {
    System.debug('  ' + pb.Name + ' | ' + pb.Product.Name + ' | Active');
}
