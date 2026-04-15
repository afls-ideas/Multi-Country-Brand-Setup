// ============================================================
// Territory-Product Alignment — Idempotent Script
// ============================================================
// Creates ProductTerritoryAvailability records to align each
// country-level LifeSciMarketableProduct to its matching
// country Territory2.
//
// Uses "Territory and Subordinates Inclusion" so each product
// is available in the country territory AND all city (FSR)
// territories underneath.
//
// Safe to re-run — checks for existing alignment before insert.
//
// IMPORTANT: After running this script, go to Setup > Product
// Alignment Jobs and run "Publish Draft Product Territory
// Alignments Batch Job" to activate the records and expand
// them into subordinate territories.
//
// To modify, edit data/territories.json and re-run.
// ============================================================

// -----------------------------------------------------------
// 1. DATA DEFINITION
// -----------------------------------------------------------

// Map country code → territory DeveloperName
Map<String, String> countryTerritoryDevNames = new Map<String, String>{
    'US' => 'US_COUNTRY',
    'GB' => 'GB_COUNTRY',
    'FR' => 'FR_COUNTRY',
    'IT' => 'IT_COUNTRY',
    'ES' => 'ES_COUNTRY',
    'DE' => 'DE_COUNTRY'
};

List<String> countryCodes = new List<String>{'US', 'GB', 'FR', 'IT', 'ES', 'DE'};

// -----------------------------------------------------------
// 2. LOOK UP COUNTRY TERRITORIES
// -----------------------------------------------------------

Map<String, Id> territoryIdByDevName = new Map<String, Id>();
for (Territory2 t : [
    SELECT Id, DeveloperName
    FROM Territory2
    WHERE DeveloperName IN ('US_COUNTRY', 'GB_COUNTRY', 'FR_COUNTRY',
                            'IT_COUNTRY', 'ES_COUNTRY', 'DE_COUNTRY')
]) {
    territoryIdByDevName.put(t.DeveloperName, t.Id);
}
System.debug('Found ' + territoryIdByDevName.size() + ' country territories.');

// -----------------------------------------------------------
// 3. LOOK UP COUNTRY MARKETABLE PRODUCTS
// -----------------------------------------------------------

Map<String, Id> mktProductIdByCode = new Map<String, Id>();
for (LifeSciMarketableProduct mkt : [
    SELECT Id, ProductCode
    FROM LifeSciMarketableProduct
    WHERE ProductCode IN ('IMMUNEXIS-US', 'IMMUNEXIS-GB', 'IMMUNEXIS-FR',
                          'IMMUNEXIS-IT', 'IMMUNEXIS-ES', 'IMMUNEXIS-DE',
                          'CORDIM-US', 'CORDIM-GB', 'CORDIM-FR',
                          'CORDIM-IT', 'CORDIM-ES', 'CORDIM-DE')
]) {
    mktProductIdByCode.put(mkt.ProductCode, mkt.Id);
}
System.debug('Found ' + mktProductIdByCode.size() + ' country marketable products.');

// -----------------------------------------------------------
// 4. QUERY EXISTING ALIGNMENTS FOR IDEMPOTENCY
// -----------------------------------------------------------

Set<String> existingKeys = new Set<String>();
for (ProductTerritoryAvailability pta : [
    SELECT ProductId, TerritoryId
    FROM ProductTerritoryAvailability
    WHERE ProductId IN :mktProductIdByCode.values()
    AND TerritoryId IN :territoryIdByDevName.values()
]) {
    existingKeys.add(pta.ProductId + '-' + pta.TerritoryId);
}
System.debug('Found ' + existingKeys.size() + ' existing alignments.');

// -----------------------------------------------------------
// 5. CREATE ALIGNMENTS
// -----------------------------------------------------------

List<String> brandCodes = new List<String>{'IMMUNEXIS', 'CORDIM'};
List<ProductTerritoryAvailability> toInsert = new List<ProductTerritoryAvailability>();

for (String brandCode : brandCodes) {
    for (String country : countryCodes) {
        String productCode = brandCode + '-' + country;
        String territoryDevName = countryTerritoryDevNames.get(country);

        Id productId = mktProductIdByCode.get(productCode);
        Id territoryId = territoryIdByDevName.get(territoryDevName);

        if (productId == null || territoryId == null) {
            System.debug('  [SKIP] ' + productCode + ' — missing product or territory');
            continue;
        }

        String key = productId + '-' + territoryId;
        if (existingKeys.contains(key)) {
            System.debug('  [EXISTS] ' + productCode + ' → ' + territoryDevName);
            continue;
        }

        toInsert.add(new ProductTerritoryAvailability(
            ProductId = productId,
            TerritoryId = territoryId,
            AlignmentType = 'Territory and Subordinates Inclusion',
            Purpose = 'Visit',
            Status = 'Draft',
            UsageType = 'LifeSciences'
        ));
    }
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    // Records are left as Draft — run the "Publish Draft Product Territory
    // Alignments Batch Job" in Setup > Product Alignment Jobs to activate
    // them and expand into subordinate territories.
}

// -----------------------------------------------------------
// 6. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('TERRITORY-PRODUCT ALIGNMENTS');
System.debug('  Created:  ' + toInsert.size());
System.debug('  Existing: ' + existingKeys.size());
System.debug('  Total:    ' + (toInsert.size() + existingKeys.size()));
System.debug('============================================');

for (ProductTerritoryAvailability pta : toInsert) {
    System.debug('  [NEW] Product: ' + pta.ProductId + ' → Territory: ' + pta.TerritoryId);
}
