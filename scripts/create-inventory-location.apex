// ============================================================
// create-inventory-location.apex
// Sets up an inventory Location + Address for a rep.
//
// Each rep can only have ONE inventory location (platform
// validation). If a location already exists, this script
// updates its name and address. If none exists, it creates one.
//
// This is a prerequisite before running:
//   - create-sample-inventory.apex
//   - create-sample-production-batches.apex
//
// Idempotent — safe to re-run.
// ============================================================

// ---- CONFIGURABLE ----
String TERRITORY_DEV_NAME = 'GB_FSR_001_London';

// Inventory storage address
String ADDR_STREET     = '42 Harley Street';
String ADDR_CITY       = 'London';
String ADDR_STATE      = '';  // UK addresses don't use State
String ADDR_POSTCODE   = 'W1G 9PR';
String ADDR_COUNTRY    = 'United Kingdom';
// ----------------------

// -----------------------------------------------------------
// 1. LOOK UP THE REP
// -----------------------------------------------------------

List<Territory2> territories = [
    SELECT Id, Name FROM Territory2
    WHERE DeveloperName = :TERRITORY_DEV_NAME LIMIT 1
];
if (territories.isEmpty()) {
    System.debug('ERROR: Territory not found: ' + TERRITORY_DEV_NAME);
    return;
}

List<UserTerritory2Association> utas = [
    SELECT UserId, User.Name, User.Username
    FROM UserTerritory2Association
    WHERE Territory2Id = :territories[0].Id LIMIT 1
];
if (utas.isEmpty()) {
    System.debug('ERROR: No user assigned to territory ' + territories[0].Name);
    return;
}
Id repUserId = utas[0].UserId;
String repName = utas[0].User.Name;
System.debug('Rep: ' + repName + ' (' + utas[0].User.Username + ')');

// -----------------------------------------------------------
// 2. CREATE OR UPDATE INVENTORY LOCATION
// -----------------------------------------------------------

String locationName = repName + ' Inventory';

List<Schema.Location> existingLocations = [
    SELECT Id, Name, IsInventoryLocation
    FROM Location
    WHERE PrimaryUserId = :repUserId AND IsInventoryLocation = true
    LIMIT 1
];

Schema.Location loc;
Boolean created = false;

if (!existingLocations.isEmpty()) {
    // Update existing location name
    loc = existingLocations[0];
    loc.Name = locationName;
    update loc;
    System.debug('Updated existing location: ' + loc.Name + ' (' + loc.Id + ')');
} else {
    // Create new location
    loc = new Schema.Location(
        Name = locationName,
        LocationType = 'User Inventory',
        PrimaryUserId = repUserId,
        IsInventoryLocation = true
    );
    insert loc;
    created = true;
    System.debug('Created Location: ' + locationName + ' (' + loc.Id + ')');
}

// -----------------------------------------------------------
// 3. CREATE OR UPDATE ADDRESS
// -----------------------------------------------------------

List<Schema.Address> existingAddresses = [
    SELECT Id, Street, City, State, PostalCode, Country
    FROM Address
    WHERE ParentId = :loc.Id
    LIMIT 1
];

if (!existingAddresses.isEmpty()) {
    Schema.Address addr = existingAddresses[0];
    addr.Street = ADDR_STREET;
    addr.City = ADDR_CITY;
    addr.State = ADDR_STATE;
    addr.PostalCode = ADDR_POSTCODE;
    addr.Country = ADDR_COUNTRY;
    update addr;
    System.debug('Updated Address: ' + ADDR_STREET + ', ' + ADDR_CITY + ' ' + ADDR_POSTCODE);
} else {
    Schema.Address addr = new Schema.Address(
        ParentId = loc.Id,
        Street = ADDR_STREET,
        City = ADDR_CITY,
        State = ADDR_STATE,
        PostalCode = ADDR_POSTCODE,
        Country = ADDR_COUNTRY,
        AddressType = 'Mailing'
    );
    insert addr;
    System.debug('Created Address: ' + ADDR_STREET + ', ' + ADDR_CITY + ' ' + ADDR_POSTCODE);
}

// -----------------------------------------------------------
// 4. VERIFY
// -----------------------------------------------------------

System.debug('============================================');
System.debug('INVENTORY LOCATION');
System.debug('  Rep:     ' + repName);
System.debug('  Name:    ' + locationName);
System.debug('  Id:      ' + loc.Id);
System.debug('  Address: ' + ADDR_STREET + ', ' + ADDR_CITY + ' ' + ADDR_POSTCODE + ', ' + ADDR_COUNTRY);
if (created) {
    System.debug('  Status:  NEW — run create-sample-inventory.apex next');
} else {
    System.debug('  Status:  UPDATED — existing inventory items remain');
}
System.debug('============================================');
