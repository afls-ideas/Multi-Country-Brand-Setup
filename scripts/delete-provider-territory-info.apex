// ============================================================
// Delete Provider Account Territory Info — Cleanup Script
// ============================================================
// Removes ProviderAcctTerritoryInfo and ObjectTerritory2Association
// records for a given territory. Run this before re-running the
// create script if you want a fresh start.
//
// CONFIGURABLE: Change TERRITORY_DEV_NAME to target a different
// territory.
// ============================================================

String TERRITORY_DEV_NAME = 'GB_FSR_001_London';

Territory2 territory = [
    SELECT Id, Name FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME
    LIMIT 1
];

// Delete PATI records first (they reference the OTA indirectly)
List<ProviderAcctTerritoryInfo> patiToDelete = [
    SELECT Id FROM ProviderAcctTerritoryInfo
    WHERE Territory2Id = :territory.Id
];
if (!patiToDelete.isEmpty()) {
    delete patiToDelete;
}

// Delete OTA records
List<ObjectTerritory2Association> otaToDelete = [
    SELECT Id FROM ObjectTerritory2Association
    WHERE Territory2Id = :territory.Id
];
if (!otaToDelete.isEmpty()) {
    delete otaToDelete;
}

System.debug('============================================');
System.debug('CLEANUP: ' + territory.Name);
System.debug('  PATI deleted: ' + patiToDelete.size());
System.debug('  OTA deleted:  ' + otaToDelete.size());
System.debug('============================================');
