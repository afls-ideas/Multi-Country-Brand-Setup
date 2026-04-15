// ============================================================
// Cleanup: Delete all products created by create-products.apex
// ============================================================
// Deletes in reverse hierarchy order: Samples → Sub-Brands → Brands
// Uses ProductCode patterns to target only records from this project.
// ============================================================

// Delete Samples (Level 3)
List<Product2> samples = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE Family = 'Sample'
    AND (ProductCode LIKE 'IMMUNEXIS-%-SMPL' OR ProductCode LIKE 'CORDIM-%-SMPL')
];
System.debug('Deleting ' + samples.size() + ' samples...');
delete samples;

// Delete Sub-Brands (Level 2)
List<Product2> subBrands = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE Family = 'Sub-Brand'
    AND (ProductCode LIKE 'IMMUNEXIS-%' OR ProductCode LIKE 'CORDIM-%')
];
System.debug('Deleting ' + subBrands.size() + ' sub-brands...');
delete subBrands;

// Delete Brands (Level 1)
List<Product2> brands = [
    SELECT Id, Name, ProductCode
    FROM Product2
    WHERE Family = 'Brand'
    AND ProductCode IN ('IMMUNEXIS', 'CORDIM')
];
System.debug('Deleting ' + brands.size() + ' brands...');
delete brands;

System.debug('Cleanup complete.');
