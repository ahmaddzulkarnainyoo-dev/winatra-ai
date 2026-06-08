// add_fields.js
const admin = require('firebase-admin');

// Ganti dengan path ke file service account key dari Firebase
// Cara mendapatkannya: Firebase Console → Project Settings → Service Accounts → Generate New Private Key
const serviceAccount = require('./path-to-your-service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function addMissingFields() {
  const usersRef = db.collection('users');
  const snapshot = await usersRef.get();
  
  let count = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};
    
    if (data.dailyCount === undefined) {
      updates.dailyCount = 0;
    }
    if (data.lastCountDate === undefined) {
      updates.lastCountDate = admin.firestore.FieldValue.serverTimestamp();
    }
    if (data.isPremium === undefined) {
      updates.isPremium = false;
    }
    if (data.premiumUntil === undefined) {
      updates.premiumUntil = null;
    }
    
    if (Object.keys(updates).length > 0) {
      await doc.ref.update(updates);
      count++;
      console.log(`Updated user ${doc.id}: ${JSON.stringify(updates)}`);
    }
  }
  console.log(`Selesai. ${count} users updated.`);
}

addMissingFields().catch(console.error);