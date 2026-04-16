// ============================================================
// Multi-Country Marketable Products — Idempotent Script
// ============================================================
// Creates LifeSciMarketableProduct records for each country-
// level Sub-Brand and parents them under the existing Brand
// marketable product.
//
// IMPORTANT: These records use Type = 'Brand' (not 'Product')
// so they appear in the Product Details section during Visit
// Engagement. The platform filters detailable products by
// Type IN ('Brand','Indication','TherapeuticArea','BrandIndication').
// Type = 'Brand' requires ProductId to be null.
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
// 3. QUERY EXISTING MARKETABLE PRODUCTS FOR IDEMPOTENCY
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
// 4. CREATE / UPDATE COUNTRY-BRAND MARKETABLE PRODUCTS
// -----------------------------------------------------------

List<LifeSciMarketableProduct> toInsert = new List<LifeSciMarketableProduct>();
List<LifeSciMarketableProduct> toUpdate = new List<LifeSciMarketableProduct>();

for (String brandCode : brandCodes) {
    String brandName = brandNames.get(brandCode);
    Id parentBrandMktId = brandMktIdByName.get(brandName);

    for (String country : countries) {
        String code = brandCode + '-' + country;
        LifeSciMarketableProduct existing = existingByCode.get(code);

        if (existing != null) {
            existing.Name = brandName + ' ' + country;
            existing.Type = 'Brand';
            existing.IsActive = true;
            existing.ProductId = null;
            existing.ParentBrandProductId = parentBrandMktId;
            existing.Country__c = country;
            existing.Description = brandName + ' - ' + country + ' marketable product';
            toUpdate.add(existing);
        } else {
            toInsert.add(new LifeSciMarketableProduct(
                Name = brandName + ' ' + country,
                ProductCode = code,
                Type = 'Brand',
                IsActive = true,
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
// 5. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('MARKETABLE PRODUCTS');
System.debug('  Inserted: ' + toInsert.size());
System.debug('  Updated:  ' + toUpdate.size());
System.debug('  Total:    ' + (toInsert.size() + toUpdate.size()));
System.debug('============================================');

for (LifeSciMarketableProduct m : toInsert) {
    System.debug('  [NEW] ' + m.Name + ' [' + m.Country__c + '] Type: ' + m.Type + ' → Parent Brand: ' + m.ParentBrandProductId);
}
for (LifeSciMarketableProduct m : toUpdate) {
    System.debug('  [UPD] ' + m.Name + ' [' + m.Country__c + '] Type: ' + m.Type + ' → Parent Brand: ' + m.ParentBrandProductId);
}
