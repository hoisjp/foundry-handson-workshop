using './main.bicep'

param prefix = 'fdyws'
param location = 'eastus2'
param searchLocation = 'centralus'

// Replace with real object IDs before deployment.
param participantsGroupObjectId = '00000000-0000-0000-0000-000000000000'
param instructorPrincipalId = '00000000-0000-0000-0000-000000000000'
param instructorPrincipalType = 'User'

// Switch to 'sharedProject' if participants cannot create their own projects in the rehearsal.
param participantAccessMode = 'ownProject'

// One project per participant plus a few spares. Use [] for sharedProject mode.
param participantProjectNames = [
  'proj-01'
  'proj-02'
  'proj-03'
]
