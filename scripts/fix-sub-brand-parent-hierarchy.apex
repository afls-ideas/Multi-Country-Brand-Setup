// ============================================================
// Fix Sub-Brand Parent Hierarchy (LifeSciMarketableProduct)
// ============================================================
// Sets ParentProductId on country-specific marketable products
// so they nest under their parent Brand in the Product Hierarchy UI.
// Also fixes sample dosage records under country sub-brands.
// ============================================================

// 1. Find Brand-level marketable products by Name (they have no ProductCode)
Map<String, Id> brandMktIdByName = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, ParentProductId
    FROM LifeSciMarketableProduct
    WHERE Type = 'Brand'
    AND Name IN ('Immunexis', 'Cordim')
    AND ParentProductId != null
]) {
    brandMktIdByName.put(mkt.Name, mkt.Id);
    System.debug('Brand parent: ' + mkt.Name + ' → ' + mkt.Id);
}

if (brandMktIdByName.isEmpty()) {
    System.debug('ERROR: No brand-level marketable products found!');
    return;
}

// 2. Fix country sub-brands → parent should be the Brand
List<LifeSciMarketableProduct> toUpdate = new List<LifeSciMarketableProduct>();

for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, ProductCode, ParentProductId
    FROM LifeSciMarketableProduct
    WHERE ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%'
]) {
    String brandName = mkt.Name.substringBefore(' ');
    Id parentId = brandMktIdByName.get(brandName);

    if (parentId != null && mkt.ParentProductId != parentId) {
        mkt.ParentProductId = parentId;
        toUpdate.add(mkt);
        System.debug('  Fix sub-brand: ' + mkt.Name + ' → ParentProductId: ' + parentId);
    } else {
        System.debug('  OK: ' + mkt.Name + ' (ParentProductId=' + mkt.ParentProductId + ')');
    }
}

if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Updated ' + toUpdate.size() + ' country sub-brand records.');
}

// 3. Fix sample/dosage records under country sub-brands
//    e.g. "Cordim GB 5mg" and "Cordim GB 20mg" should parent under "Cordim GB"
Map<String, Id> subBrandIdByName = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name
    FROM LifeSciMarketableProduct
    WHERE ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%'
]) {
    subBrandIdByName.put(mkt.Name, mkt.Id);
}

List<LifeSciMarketableProduct> samplesToUpdate = new List<LifeSciMarketableProduct>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, Name, ParentProductId
    FROM LifeSciMarketableProduct
    WHERE (Name LIKE 'Cordim GB %mg' OR Name LIKE 'Cordim DE %mg' OR Name LIKE 'Cordim FR %mg'
        OR Name LIKE 'Cordim IT %mg' OR Name LIKE 'Cordim ES %mg' OR Name LIKE 'Cordim US %mg'
        OR Name LIKE 'Immunexis GB %mg' OR Name LIKE 'Immunexis DE %mg' OR Name LIKE 'Immunexis FR %mg'
        OR Name LIKE 'Immunexis IT %mg' OR Name LIKE 'Immunexis ES %mg' OR Name LIKE 'Immunexis US %mg')
    AND ParentProductId = null
]) {
    // Extract sub-brand name: "Cordim GB 5mg" → "Cordim GB"
    // Find the last space before the dosage
    String subBrandName = mkt.Name.substringBeforeLast(' ');
    Id parentId = subBrandIdByName.get(subBrandName);

    if (parentId != null) {
        mkt.ParentProductId = parentId;
        samplesToUpdate.add(mkt);
        System.debug('  Fix sample: ' + mkt.Name + ' → ParentProductId: ' + parentId + ' (' + subBrandName + ')');
    }
}

if (!samplesToUpdate.isEmpty()) {
    update samplesToUpdate;
    System.debug('Updated ' + samplesToUpdate.size() + ' sample records.');
}

System.debug('============================================');
System.debug('Sub-brands fixed: ' + toUpdate.size());
System.debug('Samples fixed:    ' + samplesToUpdate.size());
System.debug('Total fixed:      ' + (toUpdate.size() + samplesToUpdate.size()));
System.debug('============================================');
