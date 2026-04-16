// ============================================================
// Provider Account Territory Info — Idempotent Script
// ============================================================
// Creates ProviderAcctTerritoryInfo (PATI) records to make
// accounts visible to reps in their territory. Without these,
// accounts won't appear in OMCC lists, My Accounts, or any
// view that filters by:
//
//   Id IN (SELECT AccountId FROM ProviderAcctTerritoryInfo
//          WHERE IsAvailableOffline = true
//          AND Territory2.Name = '{USER.TERRITORY}')
//
// This script also creates the ObjectTerritory2Association
// records (account-territory assignments) as a prerequisite.
//
// CONFIGURABLE: Change TERRITORY_DEV_NAME and ACCOUNT_LIMIT
// below to target a different territory or number of accounts.
//
// Safe to re-run — checks for existing records before insert.
// ============================================================

// -----------------------------------------------------------
// 1. CONFIGURATION — CHANGE THESE VALUES
// -----------------------------------------------------------

String TERRITORY_DEV_NAME = 'GB_FSR_001_London';
Integer ACCOUNT_LIMIT = 50;

// -----------------------------------------------------------
// 2. LOOK UP TERRITORY
// -----------------------------------------------------------

List<Territory2> territories = [
    SELECT Id, Name, DeveloperName
    FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME
    LIMIT 1
];

if (territories.isEmpty()) {
    System.debug('ERROR: Territory ' + TERRITORY_DEV_NAME + ' not found.');
    return;
}
Territory2 territory = territories[0];
System.debug('Territory: ' + territory.Name + ' (' + territory.Id + ')');

// -----------------------------------------------------------
// 2b. LOOK UP TERRITORY OWNER (REP ASSIGNED TO TERRITORY)
// -----------------------------------------------------------
// PATI records must be owned by the rep assigned to the territory,
// otherwise sharing rules prevent the rep from seeing them.

List<UserTerritory2Association> uta = [
    SELECT UserId
    FROM UserTerritory2Association
    WHERE Territory2Id = :territory.Id
    LIMIT 1
];
Id territoryOwnerId = uta.isEmpty() ? UserInfo.getUserId() : uta[0].UserId;
System.debug('PATI OwnerId: ' + territoryOwnerId);

// -----------------------------------------------------------
// 3. FIND PERSON ACCOUNTS NOT YET IN THIS TERRITORY
// -----------------------------------------------------------

// Get accounts already assigned to this territory
Set<Id> existingAccountIds = new Set<Id>();
for (ObjectTerritory2Association ota : [
    SELECT ObjectId
    FROM ObjectTerritory2Association
    WHERE Territory2Id = :territory.Id
]) {
    existingAccountIds.add(ota.ObjectId);
}
System.debug('Accounts already in territory: ' + existingAccountIds.size());

// Pick person accounts not yet assigned (ordered by Name for consistency)
List<Account> accounts = [
    SELECT Id, Name
    FROM Account
    WHERE IsPersonAccount = true
    AND Id NOT IN :existingAccountIds
    ORDER BY Name
    LIMIT :ACCOUNT_LIMIT
];
System.debug('Accounts to assign: ' + accounts.size());

if (accounts.isEmpty()) {
    System.debug('No new accounts to assign. Done.');
    return;
}

// -----------------------------------------------------------
// 4. CREATE OBJECT-TERRITORY ASSOCIATIONS
// -----------------------------------------------------------

List<ObjectTerritory2Association> otaToInsert = new List<ObjectTerritory2Association>();
for (Account acct : accounts) {
    otaToInsert.add(new ObjectTerritory2Association(
        ObjectId = acct.Id,
        Territory2Id = territory.Id,
        AssociationCause = 'Territory2Manual'
    ));
}
insert otaToInsert;
System.debug('Created ' + otaToInsert.size() + ' ObjectTerritory2Association records.');

// -----------------------------------------------------------
// 5. CREATE PROVIDER ACCOUNT TERRITORY INFO RECORDS
// -----------------------------------------------------------

// Check for existing PATI records for these accounts + territory
Set<Id> accountIds = new Set<Id>();
for (Account acct : accounts) {
    accountIds.add(acct.Id);
}

Set<Id> existingPatiAccountIds = new Set<Id>();
for (ProviderAcctTerritoryInfo pati : [
    SELECT AccountId
    FROM ProviderAcctTerritoryInfo
    WHERE AccountId IN :accountIds
    AND Territory2Id = :territory.Id
]) {
    existingPatiAccountIds.add(pati.AccountId);
}

List<ProviderAcctTerritoryInfo> patiToInsert = new List<ProviderAcctTerritoryInfo>();
for (Account acct : accounts) {
    if (existingPatiAccountIds.contains(acct.Id)) {
        System.debug('  [EXISTS] PATI for ' + acct.Name);
        continue;
    }
    patiToInsert.add(new ProviderAcctTerritoryInfo(
        AccountId = acct.Id,
        Territory2Id = territory.Id,
        OwnerId = territoryOwnerId,
        IsActive = true,
        IsAvailableOffline = true,
        IsTargetedAccount = true
    ));
}

if (!patiToInsert.isEmpty()) {
    insert patiToInsert;
}

// -----------------------------------------------------------
// 6. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('PROVIDER ACCOUNT TERRITORY INFO');
System.debug('  Territory:    ' + territory.Name);
System.debug('  OTA created:  ' + otaToInsert.size());
System.debug('  PATI created: ' + patiToInsert.size());
System.debug('  PATI existed: ' + existingPatiAccountIds.size());
System.debug('============================================');

for (ProviderAcctTerritoryInfo p : patiToInsert) {
    System.debug('  [NEW] Account: ' + p.AccountId + ' → Territory: ' + territory.Name);
}
