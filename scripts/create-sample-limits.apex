// ============================================================
// create-sample-limits.apex
// Creates ProviderSampleLimit records linking accounts in a
// territory to marketable products with a sample limit template.
// Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';   // Target territory (DeveloperName)
String COUNTRY_CODE       = 'GB';                   // Country filter for marketable products
String TEMPLATE_DEV_NAME  = 'lsc4ce_GenericTemplate'; // Sample limit template DeveloperName
// ----------------------

// Step 1: Look up the target territory
List<Territory2> territories = [
    SELECT Id, Name
    FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME
    LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}
Territory2 territory = territories[0];
System.debug('Found territory: ' + territory.Name);

// Step 2: Look up the sample limit template
List<ProviderSampleLimitTemplate> templates = [
    SELECT Id, MasterLabel, IsActive, RuleCondition
    FROM ProviderSampleLimitTemplate
    WHERE DeveloperName = :TEMPLATE_DEV_NAME AND IsActive = true
    LIMIT 1
];
if (templates.isEmpty()) {
    System.debug('ERROR: Active sample limit template not found: ' + TEMPLATE_DEV_NAME);
    return;
}
ProviderSampleLimitTemplate template = templates[0];
System.debug('Using template: ' + template.MasterLabel);

// Step 3: Find country-level marketable products (Type = 'Brand')
List<LifeSciMarketableProduct> mktProducts = [
    SELECT Id, Name, Country__c
    FROM LifeSciMarketableProduct
    WHERE Country__c = :COUNTRY_CODE AND IsActive = true AND Type = 'Brand'
    ORDER BY Name
];
if (mktProducts.isEmpty()) {
    System.debug('ERROR: No active Brand marketable products found for country: ' + COUNTRY_CODE);
    return;
}
System.debug('Found ' + mktProducts.size() + ' marketable products for ' + COUNTRY_CODE);

// Step 4: Find accounts in the territory via ProviderAcctTerritoryInfo
List<ProviderAcctTerritoryInfo> patiRecords = [
    SELECT AccountId, Account.Name
    FROM ProviderAcctTerritoryInfo
    WHERE Territory2Id = :territory.Id AND IsActive = true
    ORDER BY Account.Name
];
if (patiRecords.isEmpty()) {
    System.debug('ERROR: No accounts found in territory ' + territory.Name + '. Run create-provider-territory-info.apex first.');
    return;
}
System.debug('Found ' + patiRecords.size() + ' accounts in territory.');

Set<Id> accountIds = new Set<Id>();
for (ProviderAcctTerritoryInfo pati : patiRecords) {
    accountIds.add(pati.AccountId);
}

// Step 5: Check for existing limits (idempotency)
Set<Id> mktProductIds = new Set<Id>();
for (LifeSciMarketableProduct mp : mktProducts) {
    mktProductIds.add(mp.Id);
}
Set<String> existingKeys = new Set<String>();
for (ProviderSampleLimit existing : [
    SELECT AccountId, ProductId
    FROM ProviderSampleLimit
    WHERE AccountId IN :accountIds AND ProductId IN :mktProductIds
]) {
    existingKeys.add(existing.AccountId + '_' + existing.ProductId);
}

// Step 6: Create ProviderSampleLimit records
List<ProviderSampleLimit> toInsert = new List<ProviderSampleLimit>();

for (Id acctId : accountIds) {
    for (LifeSciMarketableProduct mp : mktProducts) {
        String key = acctId + '_' + mp.Id;
        if (!existingKeys.contains(key)) {
            toInsert.add(new ProviderSampleLimit(
                AccountId = acctId,
                ProductId = mp.Id,
                PrvdSampleLimitTemplateId = template.Id,
                PrvdSampleLmtTemplateName = template.MasterLabel,
                Rule = template.RuleCondition
            ));
        }
    }
}

if (toInsert.isEmpty()) {
    System.debug('All sample limits already exist. Nothing to insert.');
} else {
    // Insert in batches (DML row limit)
    Integer batchSize = 200;
    Integer inserted = 0;
    for (Integer i = 0; i < toInsert.size(); i += batchSize) {
        Integer endIdx = Math.min(i + batchSize, toInsert.size());
        List<ProviderSampleLimit> batch = new List<ProviderSampleLimit>();
        for (Integer j = i; j < endIdx; j++) {
            batch.add(toInsert[j]);
        }
        insert batch;
        inserted += batch.size();
    }
    System.debug('Inserted ' + inserted + ' sample limit records.');
}

System.debug('=== DONE: Sample limits for ' + territory.Name + ' (' + accountIds.size() + ' accounts x ' + mktProducts.size() + ' products) ===');
