// ============================================================
// check-guidance-sharing.apex
// Investigates ProductGuidance sharing to understand why
// records don't appear in Visit Engagement for reps.
// ============================================================

// 1. Find all users assigned to territories (likely reps)
System.debug('============================================');
System.debug('TERRITORY-ASSIGNED USERS');
System.debug('============================================');
for (UserTerritory2Association uta : [
    SELECT Id, UserId, User.Name, User.Username, User.UserRoleId, User.UserRole.Name,
           Territory2Id, Territory2.Name
    FROM UserTerritory2Association
    ORDER BY Territory2.Name
]) {
    System.debug(uta.Territory2.Name + ' → ' + uta.User.Name
        + ' (' + uta.UserId + ') Role: ' + uta.User.UserRole.Name);
}

// 2. Our GB records
System.debug('============================================');
System.debug('OUR GB RECORDS');
System.debug('============================================');
List<ProductGuidance> gbRecords = [
    SELECT Id, Name, OwnerId, Owner.Name
    FROM ProductGuidance
    WHERE Name LIKE 'Immunexis GB%' OR Name LIKE 'Cordim GB%'
];
Set<Id> gbIds = new Set<Id>();
for (ProductGuidance pg : gbRecords) {
    gbIds.add(pg.Id);
    System.debug(pg.Name + ' | Owner: ' + pg.Owner.Name + ' (' + pg.OwnerId + ')');
}

// 3. Check sharing on our GB records
System.debug('============================================');
System.debug('SHARING ON OUR GB RECORDS');
System.debug('============================================');
for (ProductGuidanceShare pgs : [
    SELECT Id, ParentId, Parent.Name, UserOrGroupId, AccessLevel, RowCause
    FROM ProductGuidanceShare
    WHERE ParentId IN :gbIds
]) {
    System.debug(pgs.Parent.Name + ' → UserOrGroup: ' + pgs.UserOrGroupId
        + ' | Access: ' + pgs.AccessLevel + ' | Cause: ' + pgs.RowCause);
}

// 4. Check the working demo messages
System.debug('============================================');
System.debug('ALL NON-PROJECT GUIDANCE RECORDS');
System.debug('============================================');
List<ProductGuidance> demoRecords = [
    SELECT Id, Name, OwnerId, Owner.Name, ProductReferenceRecordId
    FROM ProductGuidance
    WHERE (NOT Name LIKE 'Cordim%') AND (NOT Name LIKE 'Immunexis%')
    LIMIT 10
];
Set<Id> demoIds = new Set<Id>();
for (ProductGuidance pg : demoRecords) {
    demoIds.add(pg.Id);
    System.debug(pg.Name + ' | Owner: ' + pg.Owner.Name + ' (' + pg.OwnerId + ')');
}

// 5. Check sharing on demo records
System.debug('============================================');
System.debug('SHARING ON DEMO RECORDS');
System.debug('============================================');
if (!demoIds.isEmpty()) {
    for (ProductGuidanceShare pgs : [
        SELECT Id, ParentId, Parent.Name, UserOrGroupId, AccessLevel, RowCause
        FROM ProductGuidanceShare
        WHERE ParentId IN :demoIds
    ]) {
        System.debug(pgs.Parent.Name + ' → UserOrGroup: ' + pgs.UserOrGroupId
            + ' | Access: ' + pgs.AccessLevel + ' | Cause: ' + pgs.RowCause);
    }
}

// 6. Roles
System.debug('============================================');
System.debug('ROLE HIERARCHY');
System.debug('============================================');
for (UserRole ur : [
    SELECT Id, Name, ParentRoleId FROM UserRole ORDER BY Name
]) {
    System.debug(ur.Name + ' (' + ur.Id + ') → Parent: ' + ur.ParentRoleId);
}
