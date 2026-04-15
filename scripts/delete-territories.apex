// ============================================================
// Cleanup: Delete territories created by create-territories.apex
// ============================================================
// Deletes in reverse hierarchy order: Cities → Countries → Global
// Uses DeveloperName patterns to target only records from this project.
// ============================================================

// Delete Cities / FSR (Level 3)
List<Territory2> cities = [
    SELECT Id, Name, DeveloperName
    FROM Territory2
    WHERE DeveloperName LIKE 'US_FSR_%'
    OR DeveloperName LIKE 'GB_FSR_%'
    OR DeveloperName LIKE 'FR_FSR_%'
    OR DeveloperName LIKE 'IT_FSR_%'
    OR DeveloperName LIKE 'ES_FSR_%'
    OR DeveloperName LIKE 'DE_FSR_%'
];
System.debug('Deleting ' + cities.size() + ' city territories...');
delete cities;

// Delete Countries (Level 2)
List<Territory2> countries = [
    SELECT Id, Name, DeveloperName
    FROM Territory2
    WHERE DeveloperName IN ('US_COUNTRY', 'GB_COUNTRY', 'FR_COUNTRY', 'IT_COUNTRY', 'ES_COUNTRY', 'DE_COUNTRY')
];
System.debug('Deleting ' + countries.size() + ' country territories...');
delete countries;

// Delete Global (Level 1)
List<Territory2> global_terr = [
    SELECT Id, Name, DeveloperName
    FROM Territory2
    WHERE DeveloperName = 'GLOBAL'
];
System.debug('Deleting ' + global_terr.size() + ' global territory...');
delete global_terr;

System.debug('Territory cleanup complete.');
