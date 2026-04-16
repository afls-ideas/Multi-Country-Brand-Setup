// ============================================================
// Sample Territory-Product Alignment — Idempotent Script
// ============================================================
// Creates ProductTerritoryAvailability records to align each
// sample-level LifeSciMarketableProduct (Type = 'Product') to
// its matching country Territory2.
//
// Uses "Territory and Subordinates Inclusion" at the COUNTRY
// territory so the batch job expands PTDAs down to all child
// (FSR) territories. Aligning directly to a leaf territory
// with "Territory Inclusion" does NOT create PTDAs.
//
// Safe to re-run — checks for existing alignment before insert.
//
// IMPORTANT: After running this script, go to Admin Console >
// Product > Product Alignment Jobs and run "Publish Draft
// Product Territory Alignments Batch Job" to create the
// ProductTerrDtlAvailability (PTDA) records.
// ============================================================

// ---- CONFIGURABLE ----
List<String> COUNTRY_CODES = new List<String>{'GB'};  // Add more: 'US', 'FR', etc.
// ----------------------

// -----------------------------------------------------------
// 1. LOOK UP COUNTRY TERRITORIES
// -----------------------------------------------------------

Map<String, String> countryTerritoryDevNames = new Map<String, String>{
    'US' => 'US_COUNTRY',
    'GB' => 'GB_COUNTRY',
    'FR' => 'FR_COUNTRY',
    'IT' => 'IT_COUNTRY',
    'ES' => 'ES_COUNTRY',
    'DE' => 'DE_COUNTRY'
};

Set<String> targetDevNames = new Set<String>();
for (String cc : COUNTRY_CODES) {
    targetDevNames.add(countryTerritoryDevNames.get(cc));
}

Map<String, Id> territoryIdByDevName = new Map<String, Id>();
for (Territory2 t : [
    SELECT Id, DeveloperName
    FROM Territory2
    WHERE DeveloperName IN :targetDevNames
]) {
    territoryIdByDevName.put(t.DeveloperName, t.Id);
}
System.debug('Found ' + territoryIdByDevName.size() + ' country territories.');

// -----------------------------------------------------------
// 2. LOOK UP SAMPLE-LEVEL MARKETABLE PRODUCTS
// -----------------------------------------------------------

List<LifeSciMarketableProduct> sampleMkts = [
    SELECT Id, Name, Country__c
    FROM LifeSciMarketableProduct
    WHERE Type = 'Product'
    AND Country__c IN :COUNTRY_CODES
    ORDER BY Name
];
System.debug('Found ' + sampleMkts.size() + ' sample marketable products.');

// -----------------------------------------------------------
// 3. QUERY EXISTING ALIGNMENTS FOR IDEMPOTENCY
// -----------------------------------------------------------

Set<Id> sampleMktIds = new Set<Id>();
for (LifeSciMarketableProduct m : sampleMkts) {
    sampleMktIds.add(m.Id);
}

Set<String> existingKeys = new Set<String>();
for (ProductTerritoryAvailability pta : [
    SELECT ProductId, TerritoryId
    FROM ProductTerritoryAvailability
    WHERE ProductId IN :sampleMktIds
    AND TerritoryId IN :territoryIdByDevName.values()
]) {
    existingKeys.add(pta.ProductId + '-' + pta.TerritoryId);
}
System.debug('Found ' + existingKeys.size() + ' existing alignments.');

// -----------------------------------------------------------
// 4. CREATE ALIGNMENTS
// -----------------------------------------------------------

List<ProductTerritoryAvailability> toInsert = new List<ProductTerritoryAvailability>();

for (LifeSciMarketableProduct m : sampleMkts) {
    String devName = countryTerritoryDevNames.get(m.Country__c);
    Id territoryId = territoryIdByDevName.get(devName);

    if (territoryId == null) {
        System.debug('  [SKIP] ' + m.Name + ' — no territory for country ' + m.Country__c);
        continue;
    }

    String key = m.Id + '-' + territoryId;
    if (existingKeys.contains(key)) {
        System.debug('  [EXISTS] ' + m.Name + ' → ' + devName);
        continue;
    }

    toInsert.add(new ProductTerritoryAvailability(
        ProductId = m.Id,
        TerritoryId = territoryId,
        AlignmentType = 'Territory and Subordinates Inclusion',
        Purpose = 'Visit',
        Status = 'Draft',
        UsageType = 'LifeSciences'
    ));
    System.debug('  [CREATE] ' + m.Name + ' → ' + devName + ' (Territory and Subordinates Inclusion)');
}

if (!toInsert.isEmpty()) {
    insert toInsert;
    // Records are left as Draft — run the "Publish Draft Product Territory
    // Alignments Batch Job" in Admin Console > Product > Product Alignment Jobs
    // to activate them and create PTDAs in subordinate territories.
}

// -----------------------------------------------------------
// 5. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('SAMPLE TERRITORY-PRODUCT ALIGNMENTS');
System.debug('  Created:  ' + toInsert.size());
System.debug('  Existing: ' + existingKeys.size());
System.debug('  Total:    ' + (toInsert.size() + existingKeys.size()));
System.debug('============================================');
System.debug('');
System.debug('NEXT STEP: Run the alignment batch job from');
System.debug('Admin Console > Product > Product Alignment Jobs');
