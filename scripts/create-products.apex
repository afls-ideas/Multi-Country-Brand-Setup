// ============================================================
// Multi-Country Brand Product Hierarchy — Idempotent Script
// ============================================================
// Creates Brand → Sub-Brand → Sample records using ProductCode
// as the unique key. Safe to re-run — existing records are
// updated in place, new records are inserted.
//
// Hierarchy is expressed via ProductCode convention:
//   Brand:     IMMUNEXIS
//   Sub-Brand: IMMUNEXIS-US
//   Sample:    IMMUNEXIS-US-10mg-SMPL
//
// If Product Hierarchy (ParentId) is enabled in your org,
// uncomment the ParentId lines below to link records.
//
// To modify the hierarchy, edit data/products.json and update
// the data structures below to match, then re-run this script.
// ============================================================

// -----------------------------------------------------------
// 1. DATA DEFINITION — mirrors data/products.json
// -----------------------------------------------------------

List<Map<String, String>> brandDefs = new List<Map<String, String>>{
    new Map<String, String>{
        'name' => 'Immunexis',
        'productCode' => 'IMMUNEXIS',
        'description' => 'Immunexis - Global Brand'
    },
    new Map<String, String>{
        'name' => 'Cordim',
        'productCode' => 'CORDIM',
        'description' => 'Cordim - Global Brand'
    }
};

List<String> countries = new List<String>{'US', 'GB', 'FR', 'IT', 'ES', 'DE'};

Map<String, List<String>> sampleDosages = new Map<String, List<String>>{
    'IMMUNEXIS' => new List<String>{'10mg', '25mg'},
    'CORDIM' => new List<String>{'5mg', '20mg'}
};

// -----------------------------------------------------------
// HELPER: Query existing products by ProductCode for idempotency
// -----------------------------------------------------------

Map<String, Product2> existingByCode = new Map<String, Product2>();
for (Product2 p : [
    SELECT Id, ProductCode, Name, Family, IsActive, Country__c, Description
    FROM Product2
    WHERE ProductCode LIKE 'IMMUNEXIS%' OR ProductCode LIKE 'CORDIM%'
]) {
    existingByCode.put(p.ProductCode, p);
}
System.debug('Found ' + existingByCode.size() + ' existing product records.');

// -----------------------------------------------------------
// 2. BRANDS (Level 1)
// -----------------------------------------------------------

List<Product2> brandsToInsert = new List<Product2>();
List<Product2> brandsToUpdate = new List<Product2>();

for (Map<String, String> def : brandDefs) {
    String code = def.get('productCode');
    Product2 existing = existingByCode.get(code);

    if (existing != null) {
        existing.Name = def.get('name');
        existing.Family = 'Brand';
        existing.IsActive = true;
        existing.Description = def.get('description');
        brandsToUpdate.add(existing);
    } else {
        brandsToInsert.add(new Product2(
            Name = def.get('name'),
            ProductCode = code,
            Family = 'Brand',
            IsActive = true,
            Description = def.get('description')
        ));
    }
}

if (!brandsToInsert.isEmpty()) insert brandsToInsert;
if (!brandsToUpdate.isEmpty()) update brandsToUpdate;

// Build lookup: ProductCode → Id (from both inserted and updated)
Map<String, Id> brandIdByCode = new Map<String, Id>();
for (Product2 b : brandsToInsert) { brandIdByCode.put(b.ProductCode, b.Id); }
for (Product2 b : brandsToUpdate) { brandIdByCode.put(b.ProductCode, b.Id); }

System.debug('=== BRANDS ===');
System.debug('  Inserted: ' + brandsToInsert.size() + '  Updated: ' + brandsToUpdate.size());
for (String code : brandIdByCode.keySet()) {
    System.debug('  ' + code + ' → ' + brandIdByCode.get(code));
}

// -----------------------------------------------------------
// 3. SUB-BRANDS (Level 2)
// -----------------------------------------------------------

List<Product2> subBrandsToInsert = new List<Product2>();
List<Product2> subBrandsToUpdate = new List<Product2>();

for (Map<String, String> def : brandDefs) {
    String brandName = def.get('name');
    String brandCode = def.get('productCode');
    // Id parentId = brandIdByCode.get(brandCode); // Uncomment if Product Hierarchy is enabled

    for (String country : countries) {
        String code = brandCode + '-' + country;
        Product2 existing = existingByCode.get(code);

        if (existing != null) {
            existing.Name = brandName + ' ' + country;
            existing.Family = 'Sub-Brand';
            existing.IsActive = true;
            // existing.ParentId = parentId; // Uncomment if Product Hierarchy is enabled
            existing.Country__c = country;
            existing.Description = brandName + ' - ' + country + ' market variant';
            subBrandsToUpdate.add(existing);
        } else {
            subBrandsToInsert.add(new Product2(
                Name = brandName + ' ' + country,
                ProductCode = code,
                Family = 'Sub-Brand',
                IsActive = true,
                // ParentId = parentId, // Uncomment if Product Hierarchy is enabled
                Country__c = country,
                Description = brandName + ' - ' + country + ' market variant'
            ));
        }
    }
}

if (!subBrandsToInsert.isEmpty()) insert subBrandsToInsert;
if (!subBrandsToUpdate.isEmpty()) update subBrandsToUpdate;

// Build lookup: ProductCode → Id
Map<String, Id> subBrandIdByCode = new Map<String, Id>();
for (Product2 sb : subBrandsToInsert) { subBrandIdByCode.put(sb.ProductCode, sb.Id); }
for (Product2 sb : subBrandsToUpdate) { subBrandIdByCode.put(sb.ProductCode, sb.Id); }

System.debug('=== SUB-BRANDS ===');
System.debug('  Inserted: ' + subBrandsToInsert.size() + '  Updated: ' + subBrandsToUpdate.size());
for (Product2 sb : subBrandsToInsert) {
    System.debug('  [NEW] ' + sb.Name + ' [' + sb.Country__c + '] (' + sb.ProductCode + ')');
}
for (Product2 sb : subBrandsToUpdate) {
    System.debug('  [UPD] ' + sb.Name + ' [' + sb.Country__c + '] (' + sb.ProductCode + ')');
}

// -----------------------------------------------------------
// 4. SAMPLES (Level 3)
// -----------------------------------------------------------

List<Product2> samplesToInsert = new List<Product2>();
List<Product2> samplesToUpdate = new List<Product2>();

for (Map<String, String> def : brandDefs) {
    String brandName = def.get('name');
    String brandCode = def.get('productCode');
    List<String> dosages = sampleDosages.get(brandCode);

    for (String country : countries) {
        // String subBrandCode = brandCode + '-' + country; // Uncomment if Product Hierarchy is enabled
        // Id parentId = subBrandIdByCode.get(subBrandCode); // Uncomment if Product Hierarchy is enabled

        for (String dosage : dosages) {
            String code = brandCode + '-' + country + '-' + dosage + '-SMPL';
            Product2 existing = existingByCode.get(code);

            if (existing != null) {
                existing.Name = brandName + ' ' + country + ' ' + dosage + ' Sample';
                existing.Family = 'Sample';
                existing.IsActive = true;
                // existing.ParentId = parentId; // Uncomment if Product Hierarchy is enabled
                existing.Country__c = country;
                existing.Description = brandName + ' ' + dosage + ' sample for ' + country + ' market';
                samplesToUpdate.add(existing);
            } else {
                samplesToInsert.add(new Product2(
                    Name = brandName + ' ' + country + ' ' + dosage + ' Sample',
                    ProductCode = code,
                    Family = 'Sample',
                    IsActive = true,
                    // ParentId = parentId, // Uncomment if Product Hierarchy is enabled
                    Country__c = country,
                    Description = brandName + ' ' + dosage + ' sample for ' + country + ' market'
                ));
            }
        }
    }
}

if (!samplesToInsert.isEmpty()) insert samplesToInsert;
if (!samplesToUpdate.isEmpty()) update samplesToUpdate;

System.debug('=== SAMPLES ===');
System.debug('  Inserted: ' + samplesToInsert.size() + '  Updated: ' + samplesToUpdate.size());
for (Product2 s : samplesToInsert) {
    System.debug('  [NEW] ' + s.Name + ' [' + s.Country__c + '] (' + s.ProductCode + ')');
}
for (Product2 s : samplesToUpdate) {
    System.debug('  [UPD] ' + s.Name + ' [' + s.Country__c + '] (' + s.ProductCode + ')');
}

// -----------------------------------------------------------
// 5. SUMMARY
// -----------------------------------------------------------

Integer totalInserted = brandsToInsert.size() + subBrandsToInsert.size() + samplesToInsert.size();
Integer totalUpdated = brandsToUpdate.size() + subBrandsToUpdate.size() + samplesToUpdate.size();

System.debug('============================================');
System.debug('BRANDS:      ' + (brandsToInsert.size() + brandsToUpdate.size()));
System.debug('SUB-BRANDS:  ' + (subBrandsToInsert.size() + subBrandsToUpdate.size()));
System.debug('SAMPLES:     ' + (samplesToInsert.size() + samplesToUpdate.size()));
System.debug('--------------------------------------------');
System.debug('INSERTED:    ' + totalInserted);
System.debug('UPDATED:     ' + totalUpdated);
System.debug('GRAND TOTAL: ' + (totalInserted + totalUpdated));
System.debug('============================================');
