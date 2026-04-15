// ============================================================
// Multi-Country Territory Hierarchy — Idempotent Script
// ============================================================
// Creates GLOBAL → Country → City (FSR) territories using
// DeveloperName as the unique key. Safe to re-run — existing
// records are updated in place, new records are inserted.
//
// Uses the existing active Territory2Model and Territory2Type.
//
// To modify the hierarchy, edit data/territories.json and
// update the data structures below to match, then re-run.
// ============================================================

// -----------------------------------------------------------
// 1. DATA DEFINITION — mirrors data/territories.json
// -----------------------------------------------------------

// Country code → list of maps with seq, city, developerSuffix
Map<String, String> countryNames = new Map<String, String>{
    'US' => 'US-COUNTRY',
    'GB' => 'GB-COUNTRY',
    'FR' => 'FR-COUNTRY',
    'IT' => 'IT-COUNTRY',
    'ES' => 'ES-COUNTRY',
    'DE' => 'DE-COUNTRY'
};

Map<String, String> countryDevNames = new Map<String, String>{
    'US' => 'US_COUNTRY',
    'GB' => 'GB_COUNTRY',
    'FR' => 'FR_COUNTRY',
    'IT' => 'IT_COUNTRY',
    'ES' => 'ES_COUNTRY',
    'DE' => 'DE_COUNTRY'
};

// Cities per country: each entry is {seq, city, devSuffix}
Map<String, List<Map<String, String>>> citiesByCountry = new Map<String, List<Map<String, String>>>{
    'US' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'New York', 'devSuffix' => 'NewYork'},
        new Map<String, String>{'seq' => '002', 'city' => 'Los Angeles', 'devSuffix' => 'LosAngeles'},
        new Map<String, String>{'seq' => '003', 'city' => 'Chicago', 'devSuffix' => 'Chicago'}
    },
    'GB' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'London', 'devSuffix' => 'London'},
        new Map<String, String>{'seq' => '002', 'city' => 'Manchester', 'devSuffix' => 'Manchester'},
        new Map<String, String>{'seq' => '003', 'city' => 'Birmingham', 'devSuffix' => 'Birmingham'}
    },
    'FR' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'Paris', 'devSuffix' => 'Paris'},
        new Map<String, String>{'seq' => '002', 'city' => 'Lyon', 'devSuffix' => 'Lyon'},
        new Map<String, String>{'seq' => '003', 'city' => 'Marseille', 'devSuffix' => 'Marseille'}
    },
    'IT' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'Rome', 'devSuffix' => 'Rome'},
        new Map<String, String>{'seq' => '002', 'city' => 'Milan', 'devSuffix' => 'Milan'},
        new Map<String, String>{'seq' => '003', 'city' => 'Naples', 'devSuffix' => 'Naples'}
    },
    'ES' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'Madrid', 'devSuffix' => 'Madrid'},
        new Map<String, String>{'seq' => '002', 'city' => 'Barcelona', 'devSuffix' => 'Barcelona'},
        new Map<String, String>{'seq' => '003', 'city' => 'Valencia', 'devSuffix' => 'Valencia'}
    },
    'DE' => new List<Map<String, String>>{
        new Map<String, String>{'seq' => '001', 'city' => 'Berlin', 'devSuffix' => 'Berlin'},
        new Map<String, String>{'seq' => '002', 'city' => 'Munich', 'devSuffix' => 'Munich'},
        new Map<String, String>{'seq' => '003', 'city' => 'Frankfurt', 'devSuffix' => 'Frankfurt'}
    }
};

List<String> countryCodes = new List<String>{'US', 'GB', 'FR', 'IT', 'ES', 'DE'};

// -----------------------------------------------------------
// 2. LOOK UP MODEL AND TYPE
// -----------------------------------------------------------

Territory2Model model = [
    SELECT Id, Name FROM Territory2Model
    WHERE State = 'Active' LIMIT 1
];
System.debug('Using model: ' + model.Name + ' (' + model.Id + ')');

Territory2Type tType = [
    SELECT Id, MasterLabel FROM Territory2Type LIMIT 1
];
System.debug('Using type: ' + tType.MasterLabel + ' (' + tType.Id + ')');

// -----------------------------------------------------------
// 3. QUERY EXISTING TERRITORIES FOR IDEMPOTENCY
// -----------------------------------------------------------

Map<String, Territory2> existingByDevName = new Map<String, Territory2>();
for (Territory2 t : [
    SELECT Id, Name, DeveloperName, ParentTerritory2Id
    FROM Territory2
    WHERE Territory2ModelId = :model.Id
]) {
    existingByDevName.put(t.DeveloperName, t);
}
System.debug('Found ' + existingByDevName.size() + ' existing territories in model.');

// -----------------------------------------------------------
// 4. GLOBAL (Level 1) — top-level parent
// -----------------------------------------------------------

Territory2 globalTerr;
Territory2 existingGlobal = existingByDevName.get('GLOBAL');

if (existingGlobal != null) {
    existingGlobal.Name = 'GLOBAL';
    existingGlobal.AccountAccessLevel = 'Edit';
    update existingGlobal;
    globalTerr = existingGlobal;
    System.debug('[UPD] GLOBAL → ' + globalTerr.Id);
} else {
    globalTerr = new Territory2(
        Name = 'GLOBAL',
        DeveloperName = 'GLOBAL',
        AccountAccessLevel = 'Edit',
        Territory2ModelId = model.Id,
        Territory2TypeId = tType.Id
    );
    insert globalTerr;
    System.debug('[NEW] GLOBAL → ' + globalTerr.Id);
}

// -----------------------------------------------------------
// 5. COUNTRIES (Level 2) — parent = GLOBAL
// -----------------------------------------------------------

List<Territory2> countriesToInsert = new List<Territory2>();
List<Territory2> countriesToUpdate = new List<Territory2>();

for (String code : countryCodes) {
    String devName = countryDevNames.get(code);
    String name = countryNames.get(code);
    Territory2 existing = existingByDevName.get(devName);

    if (existing != null) {
        existing.Name = name;
        existing.ParentTerritory2Id = globalTerr.Id;
        existing.AccountAccessLevel = 'Edit';
        countriesToUpdate.add(existing);
    } else {
        countriesToInsert.add(new Territory2(
            Name = name,
            DeveloperName = devName,
            AccountAccessLevel = 'Edit',
            Territory2ModelId = model.Id,
            Territory2TypeId = tType.Id,
            ParentTerritory2Id = globalTerr.Id
        ));
    }
}

if (!countriesToInsert.isEmpty()) insert countriesToInsert;
if (!countriesToUpdate.isEmpty()) update countriesToUpdate;

// Build lookup: DeveloperName → Id
Map<String, Id> countryIdByDevName = new Map<String, Id>();
for (Territory2 t : countriesToInsert) { countryIdByDevName.put(t.DeveloperName, t.Id); }
for (Territory2 t : countriesToUpdate) { countryIdByDevName.put(t.DeveloperName, t.Id); }

System.debug('=== COUNTRIES ===');
System.debug('  Inserted: ' + countriesToInsert.size() + '  Updated: ' + countriesToUpdate.size());

// -----------------------------------------------------------
// 6. CITIES / FSR (Level 3) — parent = Country
// -----------------------------------------------------------

List<Territory2> citiesToInsert = new List<Territory2>();
List<Territory2> citiesToUpdate = new List<Territory2>();

for (String code : countryCodes) {
    String countryDevName = countryDevNames.get(code);
    Id parentId = countryIdByDevName.get(countryDevName);
    List<Map<String, String>> cities = citiesByCountry.get(code);

    for (Map<String, String> cityDef : cities) {
        String seq = cityDef.get('seq');
        String city = cityDef.get('city');
        String devSuffix = cityDef.get('devSuffix');

        String name = code + '-FSR-' + seq + '-' + city;
        String devName = code + '_FSR_' + seq + '_' + devSuffix;

        Territory2 existing = existingByDevName.get(devName);

        if (existing != null) {
            existing.Name = name;
            existing.ParentTerritory2Id = parentId;
            existing.AccountAccessLevel = 'Edit';
            citiesToUpdate.add(existing);
        } else {
            citiesToInsert.add(new Territory2(
                Name = name,
                DeveloperName = devName,
                AccountAccessLevel = 'Edit',
                Territory2ModelId = model.Id,
                Territory2TypeId = tType.Id,
                ParentTerritory2Id = parentId
            ));
        }
    }
}

if (!citiesToInsert.isEmpty()) insert citiesToInsert;
if (!citiesToUpdate.isEmpty()) update citiesToUpdate;

System.debug('=== CITIES (FSR) ===');
System.debug('  Inserted: ' + citiesToInsert.size() + '  Updated: ' + citiesToUpdate.size());
for (Territory2 t : citiesToInsert) {
    System.debug('  [NEW] ' + t.Name + ' → Parent: ' + t.ParentTerritory2Id);
}
for (Territory2 t : citiesToUpdate) {
    System.debug('  [UPD] ' + t.Name + ' → Parent: ' + t.ParentTerritory2Id);
}

// -----------------------------------------------------------
// 7. SUMMARY
// -----------------------------------------------------------

Integer totalInserted = (existingGlobal == null ? 1 : 0) + countriesToInsert.size() + citiesToInsert.size();
Integer totalUpdated = (existingGlobal != null ? 1 : 0) + countriesToUpdate.size() + citiesToUpdate.size();

System.debug('============================================');
System.debug('GLOBAL:      1');
System.debug('COUNTRIES:   ' + (countriesToInsert.size() + countriesToUpdate.size()));
System.debug('CITIES:      ' + (citiesToInsert.size() + citiesToUpdate.size()));
System.debug('--------------------------------------------');
System.debug('INSERTED:    ' + totalInserted);
System.debug('UPDATED:     ' + totalUpdated);
System.debug('GRAND TOTAL: ' + (totalInserted + totalUpdated));
System.debug('============================================');
