# Firestore Indexes Setup

## Problem
The activity participants page uses `collectionGroup` queries which require composite indexes in Firestore.

## Solution

### Option 1: Deploy Indexes via Firebase CLI (Recommended)

1. Make sure you have Firebase CLI installed:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Deploy the indexes:
   ```bash
   cd admin-main
   firebase deploy --only firestore:indexes
   ```

### Option 2: Create Indexes Manually in Firebase Console

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project: `giftardo-43381`
3. Navigate to Firestore Database → Indexes
4. Click "Create Index"
5. Create the following indexes:

#### Index 1: quiz_attempts
- Collection ID: `quiz_attempts` (Collection Group)
- Fields to index:
  - `activityId` (Ascending)

#### Index 2: survey_attempts
- Collection ID: `survey_attempts` (Collection Group)
- Fields to index:
  - `activityId` (Ascending)

#### Index 3: poll_attempts
- Collection ID: `poll_attempts` (Collection Group)
- Fields to index:
  - `activityId` (Ascending)

#### Index 4: youtube_attempts
- Collection ID: `youtube_attempts` (Collection Group)
- Fields to index:
  - `activityId` (Ascending)

### Option 3: Use the Direct Link

Click this link to create the indexes automatically:
https://console.firebase.google.com/v1/r/project/giftardo-43381/firestore/indexes?create_exemption=Clxwcm9qZWN0cy9naWZ0YXJkby00MzM4MS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvcXVpel9hdHRlbXB0cy9maWVsZHMvYWN0aXZpdHlJZBACGg4KCmFjdGl2aXR5SWQQAQ

## Note
Indexes may take a few minutes to build. The app will show a helpful error message if indexes are not ready yet.


