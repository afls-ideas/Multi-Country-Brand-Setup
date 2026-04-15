// ============================================================
// Multi-Country Marketable Products — Idempotent Script
// ============================================================
// Creates LifeSciMarketableProduct records for each country-
// level Sub-Brand. Links to the corresponding Product2 record
// and parents under the existing Brand marketable product.
//
// Safe to re-run — uses ProductCode as the unique key.
// ============================================================

// -----------------------------------------------------------
// 1. DATA DEFINITION
// -----------------------------------------------------------

List<String> brandCodes = new List<String>{'IMMUNEXIS', 'CORDIM'};
Map<String, String> brandNames = new Map<String, String>{
    'IMMUNEXIS' => 'Immunexis',
    'CORDIM' => 'Cordim'
};
List<String> countries = new List<String>{'US', 'GB', 'FR', 'IT', 'ES', 'DE'};

// -----------------------------------------------------------
// 2. LOOK UP EXISTING BRAND MARKETABLE PRODUCTS
// -----------------------------------------------------------

Map<String, Id> brandMktIdByName = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name
    FROM LifeSciMarketableProduct
    WHERE Type = 'Brand'
    AND Name IN ('Immunexis', 'Cordim')
]) {
    brandMktIdByName.put(mkt.Name, mkt.Id);
}
System.debug('Found brand marketable products: ' + brandMktIdByName);

// -----------------------------------------------------------
// 3. LOOK UP PRODUCT2 SUB-BRAND RECORDS (for ProductId link)
// -----------------------------------------------------------

Map<String, Id> product2IdByCode = new Map<String, Id>();
for (Product2 p : [
    SELECT Id, ProductCode
    FROM Product2
    WHERE Family = 'Sub-Brand'
    AND (ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%')
]) {
    product2IdByCode.put(p.ProductCode, p.Id);
}
System.debug('Found ' + product2IdByCode.size() + ' Product2 sub-brand records.');

// -----------------------------------------------------------
// 4. QUERY EXISTING MARKETABLE PRODUCTS FOR IDEMPOTENCY
// -----------------------------------------------------------

Map<String, LifeSciMarketableProduct> existingByCode = new Map<String, LifeSciMarketableProduct>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, ProductCode, ProductId, Country__c, Type, IsActive, ParentBrandProductId
    FROM LifeSciMarketableProduct
    WHERE ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%'
]) {
    if (mkt.ProductCode != null) {
        existingByCode.put(mkt.ProductCode, mkt);
    }
}
System.debug('Found ' + existingByCode.size() + ' existing marketable product records with codes.');

// -----------------------------------------------------------
// 5. CREATE / UPDATE SUB-BRAND MARKETABLE PRODUCTS
// -----------------------------------------------------------

List<LifeSciMarketableProduct> toInsert = new List<LifeSciMarketableProduct>();
List<LifeSciMarketableProduct> toUpdate = new List<LifeSciMarketableProduct>();

for (String brandCode : brandCodes) {
    String brandName = brandNames.get(brandCode);
    Id parentBrandMktId = brandMktIdByName.get(brandName);

    for (String country : countries) {
        String code = brandCode + '-' + country;
        Id product2Id = product2IdByCode.get(code);
        LifeSciMarketableProduct existing = existingByCode.get(code);

        if (existing != null) {
            existing.Name = brandName + ' ' + country;
            existing.Type = 'Product';
            existing.IsActive = true;
            existing.ProductId = product2Id;
            existing.ParentBrandProductId = parentBrandMktId;
            existing.Country__c = country;
            existing.Description = brandName + ' - ' + country + ' marketable product';
            toUpdate.add(existing);
        } else {
            toInsert.add(new LifeSciMarketableProduct(
                Name = brandName + ' ' + country,
                ProductCode = code,
                Type = 'Product',
                IsActive = true,
                ProductId = product2Id,
                ParentBrandProductId = parentBrandMktId,
                Country__c = country,
                Description = brandName + ' - ' + country + ' marketable product'
            ));
        }
    }
}

if (!toInsert.isEmpty()) insert toInsert;
if (!toUpdate.isEmpty()) update toUpdate;

// -----------------------------------------------------------
// 6. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('MARKETABLE PRODUCTS');
System.debug('  Inserted: ' + toInsert.size());
System.debug('  Updated:  ' + toUpdate.size());
System.debug('  Total:    ' + (toInsert.size() + toUpdate.size()));
System.debug('============================================');

for (LifeSciMarketableProduct m : toInsert) {
    System.debug('  [NEW] ' + m.Name + ' [' + m.Country__c + '] → Product2: ' + m.ProductId + ' → Brand: ' + m.ParentBrandProductId);
}
for (LifeSciMarketableProduct m : toUpdate) {
    System.debug('  [UPD] ' + m.Name + ' [' + m.Country__c + '] → Product2: ' + m.ProductId + ' → Brand: ' + m.ParentBrandProductId);
}
