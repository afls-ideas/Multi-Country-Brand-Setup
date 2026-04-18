// ============================================================
// create-sample-marketable-products.apex
// Creates sample-level LifeSciMarketableProduct records
// (Type = Product) under country sub-brand marketable products.
// These are required for the Samples panel during Visit
// Engagement — see README-08 query #9.
//
// Naming convention: "{Brand} {dosage} ({CC})"
// e.g., "Immunexis 10mg (GB)", "Cordim 5mg (FR)"
//
// Processes all countries. Idempotent — safe to re-run.
// ============================================================

List<String> countries = new List<String>{'US', 'GB', 'FR', 'IT', 'ES', 'DE'};

// Dosage display name overrides (Product2 dosage → display dosage)
// e.g., "25mg" Product2 records display as "15mg" in the hierarchy
Map<String, Map<String, String>> dosageDisplay = new Map<String, Map<String, String>>{
    'IMMUNEXIS' => new Map<String, String>{ '10mg' => '10mg', '25mg' => '15mg' },
    'CORDIM' => new Map<String, String>{ '5mg' => '5mg', '20mg' => '20mg' }
};

// -----------------------------------------------------------
// 1. LOOK UP COUNTRY SUB-BRAND MARKETABLE PRODUCTS (parents)
// -----------------------------------------------------------

Map<String, Id> subBrandIdByKey = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, Country__c
    FROM LifeSciMarketableProduct
    WHERE Country__c IN :countries AND Type = 'Brand' AND IsActive = true
]) {
    // Key: "Immunexis-GB", "Cordim-FR", etc.
    String brandName = mkt.Name.substringBefore(' ');
    subBrandIdByKey.put(brandName + '-' + mkt.Country__c, mkt.Id);
}
System.debug('Found ' + subBrandIdByKey.size() + ' country sub-brand parents.');

// -----------------------------------------------------------
// 2. FIND SAMPLE PRODUCT2 RECORDS
// -----------------------------------------------------------

List<Product2> sampleProducts = [
    SELECT Id, Name, ProductCode, Country__c
    FROM Product2
    WHERE Family = 'Sample' AND IsActive = true AND Country__c IN :countries
    ORDER BY Name
];
System.debug('Found ' + sampleProducts.size() + ' sample Product2 records.');

// -----------------------------------------------------------
// 3. CHECK EXISTING (idempotency by ProductId)
// -----------------------------------------------------------

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
System.debug('Already exist: ' + existingProductIds.size());

// -----------------------------------------------------------
// 4. CREATE SAMPLE MARKETABLE PRODUCTS
// -----------------------------------------------------------

List<LifeSciMarketableProduct> toInsert = new List<LifeSciMarketableProduct>();

for (Product2 p : sampleProducts) {
    if (existingProductIds.contains(p.Id)) {
        System.debug('SKIP (exists): ' + p.Name);
        continue;
    }

    // Parse ProductCode: "CORDIM-GB-5mg-SMPL" → brand=CORDIM, cc=GB, dosage=5mg
    String[] parts = p.ProductCode.split('-');
    String brandCode = parts[0];                    // CORDIM
    String cc = parts[1];                           // GB
    String rawDosage = parts[2];                    // 5mg

    // Look up display dosage
    String displayDosage = rawDosage;
    if (dosageDisplay.containsKey(brandCode) && dosageDisplay.get(brandCode).containsKey(rawDosage)) {
        displayDosage = dosageDisplay.get(brandCode).get(rawDosage);
    }

    // Brand display name: "CORDIM" → "Cordim", "IMMUNEXIS" → "Immunexis"
    String brandName = brandCode.substring(0, 1) + brandCode.substring(1).toLowerCase();

    // Build name: "Cordim 5mg (GB)"
    String displayName = brandName + ' ' + displayDosage + ' (' + cc + ')';

    // Find parent sub-brand
    Id parentId = subBrandIdByKey.get(brandName + '-' + cc);
    if (parentId == null) {
        System.debug('ERROR: No parent sub-brand for ' + brandName + ' ' + cc);
        continue;
    }

    toInsert.add(new LifeSciMarketableProduct(
        Name = displayName,
        Type = 'Product',
        ProductId = p.Id,
        ParentProductId = parentId,
        ParentBrandProductId = parentId,
        DistributionMethod = 'DropAndShip',
        IsActive = true
    ));
    System.debug('CREATE: ' + displayName + ' → parent: ' + brandName + ' ' + cc);
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Inserted ' + toInsert.size() + ' sample marketable product records.');
} else {
    System.debug('All sample marketable products already exist. Nothing to insert.');
}

// -----------------------------------------------------------
// 5. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('SAMPLE MARKETABLE PRODUCTS');
System.debug('  Existing (skipped): ' + existingProductIds.size());
System.debug('  Created:            ' + toInsert.size());
System.debug('============================================');
