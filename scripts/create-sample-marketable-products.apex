// ============================================================
// create-sample-marketable-products.apex
// Creates sample-level LifeSciMarketableProduct records
// (Type = Product) under country Brand marketable products.
// These are required for the Samples panel during Visit
// Engagement — see README-08 query #9.
// Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String COUNTRY_CODE = 'GB';  // Country filter for sample products
// ----------------------

// Step 1: Find sample-level Product2 records for this country
List<Product2> sampleProducts = [
    SELECT Id, Name, ProductCode, Country__c, ParentProduct__c, ParentProduct__r.Name
    FROM Product2
    WHERE Family = 'Sample' AND Country__c = :COUNTRY_CODE AND IsActive = true
    ORDER BY Name
];
if (sampleProducts.isEmpty()) {
    System.debug('ERROR: No active sample products found for country: ' + COUNTRY_CODE);
    return;
}
System.debug('Found ' + sampleProducts.size() + ' sample products for ' + COUNTRY_CODE);

// Step 2: Find the country Brand marketable products (parents)
// These are the Type='Brand' records like "Immunexis GB", "Cordim GB"
List<LifeSciMarketableProduct> brandMkts = [
    SELECT Id, Name, Country__c
    FROM LifeSciMarketableProduct
    WHERE Country__c = :COUNTRY_CODE AND Type = 'Brand' AND IsActive = true
    ORDER BY Name
];
if (brandMkts.isEmpty()) {
    System.debug('ERROR: No active Brand marketable products found for country: ' + COUNTRY_CODE);
    return;
}

// Build a map: brand name prefix -> Brand marketable product Id
// e.g., "Cordim" -> Id of "Cordim GB", "Immunexis" -> Id of "Immunexis GB"
Map<String, Id> brandNameToMktId = new Map<String, Id>();
for (LifeSciMarketableProduct bm : brandMkts) {
    // Extract brand name by removing the country suffix
    String brandName = bm.Name.replace(' ' + COUNTRY_CODE, '');
    brandNameToMktId.put(brandName, bm.Id);
    System.debug('Brand marketable product: ' + bm.Name + ' -> ' + bm.Id);
}

// Step 3: Check for existing sample marketable products (idempotency)
Set<Id> sampleProduct2Ids = new Set<Id>();
for (Product2 p : sampleProducts) {
    sampleProduct2Ids.add(p.Id);
}
Set<Id> existingProductIds = new Set<Id>();
for (LifeSciMarketableProduct existing : [
    SELECT ProductId FROM LifeSciMarketableProduct
    WHERE Type = 'Product' AND ProductId IN :sampleProduct2Ids
]) {
    existingProductIds.add(existing.ProductId);
}

// Step 4: Create sample-level marketable products
List<LifeSciMarketableProduct> toInsert = new List<LifeSciMarketableProduct>();

for (Product2 p : sampleProducts) {
    if (existingProductIds.contains(p.Id)) {
        System.debug('SKIP (exists): ' + p.Name);
        continue;
    }

    // Determine which brand this sample belongs to
    // Sample names are like "Immunexis GB 10mg Sample" — extract the brand name
    String parentName = p.ParentProduct__r.Name; // e.g., "Immunexis GB"
    String brandName = parentName.replace(' ' + COUNTRY_CODE, ''); // e.g., "Immunexis"

    Id parentBrandMktId = brandNameToMktId.get(brandName);
    if (parentBrandMktId == null) {
        System.debug('ERROR: No Brand marketable product found for brand: ' + brandName);
        continue;
    }

    // Build a display name without "Sample" suffix
    // e.g., "Immunexis GB 10mg Sample" -> "Immunexis GB 10mg"
    String displayName = p.Name.replace(' Sample', '');

    toInsert.add(new LifeSciMarketableProduct(
        Name = displayName,
        Type = 'Product',
        ProductId = p.Id,
        ParentBrandProductId = parentBrandMktId,
        DistributionMethod = 'DropAndShip',
        IsActive = true
    ));
    System.debug('INSERT: ' + displayName + ' -> parent: ' + brandName + ' ' + COUNTRY_CODE);
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' sample marketable product records.');
} else {
    System.debug('All sample marketable products already exist. Nothing to insert.');
}

System.debug('=== DONE: Sample marketable products for ' + COUNTRY_CODE + ' ===');
