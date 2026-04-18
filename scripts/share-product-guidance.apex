// ============================================================
// share-product-guidance.apex
// Creates ProductGuidanceShare records so country reps can
// see ProductGuidance messages/objectives during visits.
//
// ProductGuidance has Private OWD, so records are only visible
// to the owner unless explicitly shared. This script shares
// each record with all users assigned to territories in the
// matching country.
//
// Idempotent — checks for existing shares before inserting.
// ============================================================

// -----------------------------------------------------------
// 1. BUILD COUNTRY → USER MAP FROM TERRITORY ASSIGNMENTS
// -----------------------------------------------------------

Map<String, Set<Id>> usersByCountry = new Map<String, Set<Id>>();
for (String cc : new List<String>{'US', 'GB', 'FR', 'DE', 'ES', 'IT'}) {
    usersByCountry.put(cc, new Set<Id>());
}

for (UserTerritory2Association uta : [
    SELECT UserId, Territory2.Name
    FROM UserTerritory2Association
]) {
    String tName = uta.Territory2.Name;

    if (tName.startsWith('GB-')) {
        usersByCountry.get('GB').add(uta.UserId);
    } else if (tName.startsWith('FR-')) {
        usersByCountry.get('FR').add(uta.UserId);
    } else if (tName.startsWith('DE-')) {
        usersByCountry.get('DE').add(uta.UserId);
    } else if (tName.startsWith('ES-')) {
        usersByCountry.get('ES').add(uta.UserId);
    } else if (tName.startsWith('IT-')) {
        usersByCountry.get('IT').add(uta.UserId);
    } else {
        usersByCountry.get('US').add(uta.UserId);
    }
}

for (String cc : usersByCountry.keySet()) {
    System.debug(cc + ' reps: ' + usersByCountry.get(cc).size() + ' → ' + usersByCountry.get(cc));
}

// -----------------------------------------------------------
// 2. LOAD OUR PRODUCTGUIDANCE RECORDS
// -----------------------------------------------------------

List<ProductGuidance> allGuidance = [
    SELECT Id, Name, OwnerId
    FROM ProductGuidance
    WHERE Name LIKE 'Cordim%' OR Name LIKE 'Immunexis%'
];
System.debug('Found ' + allGuidance.size() + ' ProductGuidance records to share.');

// Map country code → guidance record IDs
Map<String, List<Id>> guidanceByCountry = new Map<String, List<Id>>();
for (String cc : usersByCountry.keySet()) {
    guidanceByCountry.put(cc, new List<Id>());
}

for (ProductGuidance pg : allGuidance) {
    String[] parts = pg.Name.split(' ');
    if (parts.size() >= 2) {
        String cc = parts[1];
        if (guidanceByCountry.containsKey(cc)) {
            guidanceByCountry.get(cc).add(pg.Id);
        }
    }
}

// -----------------------------------------------------------
// 3. CHECK EXISTING SHARES (idempotency)
// -----------------------------------------------------------

Set<Id> allGuidanceIds = new Set<Id>();
for (ProductGuidance pg : allGuidance) {
    allGuidanceIds.add(pg.Id);
}

Set<String> existingShareKeys = new Set<String>();
for (ProductGuidanceShare pgs : [
    SELECT ParentId, UserOrGroupId
    FROM ProductGuidanceShare
    WHERE ParentId IN :allGuidanceIds AND RowCause = 'Manual'
]) {
    existingShareKeys.add(pgs.ParentId + '-' + pgs.UserOrGroupId);
}
System.debug('Existing manual shares: ' + existingShareKeys.size());

// -----------------------------------------------------------
// 4. CREATE SHARE RECORDS (one at a time to identify failures)
// -----------------------------------------------------------

Integer successCount = 0;
Integer skipCount = 0;
Integer failCount = 0;

for (String cc : guidanceByCountry.keySet()) {
    List<Id> guidanceIds = guidanceByCountry.get(cc);
    Set<Id> userIds = usersByCountry.get(cc);

    if (userIds.isEmpty()) {
        System.debug('No reps for ' + cc + ' — skipping.');
        continue;
    }

    List<ProductGuidanceShare> batch = new List<ProductGuidanceShare>();

    for (Id pgId : guidanceIds) {
        for (Id userId : userIds) {
            String key = pgId + '-' + userId;
            if (existingShareKeys.contains(key)) {
                skipCount++;
                continue;
            }

            batch.add(new ProductGuidanceShare(
                ParentId = pgId,
                UserOrGroupId = userId,
                AccessLevel = 'Read',
                RowCause = 'Manual'
            ));
        }
    }

    if (!batch.isEmpty()) {
        // Use Database.insert with allOrNone=false to handle partial failures
        List<Database.SaveResult> results = Database.insert(batch, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                failCount++;
                System.debug('FAIL: ' + cc + ' share → '
                    + batch[i].UserOrGroupId + ': '
                    + results[i].getErrors()[0].getMessage());
            }
        }
    }
}

// -----------------------------------------------------------
// 5. SUMMARY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('PRODUCT GUIDANCE SHARING');
for (String cc : guidanceByCountry.keySet()) {
    System.debug('  ' + cc + ': ' + guidanceByCountry.get(cc).size()
        + ' records → ' + usersByCountry.get(cc).size() + ' reps');
}
System.debug('  Shares created:     ' + successCount);
System.debug('  Existing (skipped): ' + skipCount);
System.debug('  Failed:             ' + failCount);
System.debug('============================================');
