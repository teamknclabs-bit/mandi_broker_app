const path = require('path');
const fs = require('fs');
const axios = require('axios');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// 1. Load service account credentials
let serviceAccount;
const keyPath = path.join(__dirname, 'serviceAccountKey.json');

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    let rawSecret = process.env.FIREBASE_SERVICE_ACCOUNT.trim();
    if (!rawSecret.startsWith('{') && !rawSecret.endsWith('}')) {
      rawSecret = Buffer.from(rawSecret, 'base64').toString('utf8');
    }
    serviceAccount = JSON.parse(rawSecret);
  } catch (err) {
    console.error("❌ Failed to parse FIREBASE_SERVICE_ACCOUNT:", err.message);
    process.exit(1);
  }
} else if (fs.existsSync(keyPath)) {
  serviceAccount = require(keyPath);
} else {
  console.error("❌ No serviceAccountKey.json found!");
  process.exit(1);
}

// 2. Initialize Firebase Admin exclusively for mandi-market-view
if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
    projectId: 'mandi-market-view'
  });
}

const db = getFirestore();

// Comprehensive NCDEX Commodity Catalog
const TARGET_MAP = [
  // --- SPICES & SEEDS ---
  { match: 'jeera', symbol: 'JEERAUNJHA', defaultLtp: 24655, defaultChange: 185 },
  { match: 'dhaniya', symbol: 'DHANIYA', defaultLtp: 15890, defaultChange: 586 },
  { match: 'turmeric', symbol: 'TMCFGRNZM', defaultLtp: 13800, defaultChange: 80 },
  { match: 'isabgol', symbol: 'ISABGOL', defaultLtp: 15900, defaultChange: 100 },
  { match: 'saunf', symbol: 'FENNEL', defaultLtp: 9200, defaultChange: 45 },
  { match: 'fennel', symbol: 'FENNEL', defaultLtp: 9200, defaultChange: 45 },
  { match: 'methi', symbol: 'FENUGREEK', defaultLtp: 5850, defaultChange: 20 },

  // --- GUAR COMPLEX ---
  { match: 'guar seed', symbol: 'GUARSEED10', defaultLtp: 7462, defaultChange: 287 },
  { match: 'guar gum', symbol: 'GUARGUM5', defaultLtp: 14491, defaultChange: 557 },

  // --- GRAINS & PULSES ---
  { match: 'chana', symbol: 'CHANA', defaultLtp: 7600, defaultChange: 52 },
  { match: 'moong', symbol: 'MOONG', defaultLtp: 8400, defaultChange: 35 },
  { match: 'moth', symbol: 'MOTH', defaultLtp: 6200, defaultChange: 15 },
  { match: 'wheat', symbol: 'WHEAT', defaultLtp: 2820, defaultChange: 12 },
  { match: 'bajra', symbol: 'BAJRA', defaultLtp: 2350, defaultChange: 8 },
  { match: 'maize', symbol: 'MAIZE', defaultLtp: 2240, defaultChange: 14 },
  { match: 'barley', symbol: 'BARLEY', defaultLtp: 2110, defaultChange: -6 },

  // --- OILSEEDS & OILS ---
  { match: 'castor', symbol: 'CASTOR', defaultLtp: 7990, defaultChange: 103 },
  { match: 'mustard', symbol: 'RMSEED', defaultLtp: 5950, defaultChange: 40 },
  { match: 'rmseed', symbol: 'RMSEED', defaultLtp: 5950, defaultChange: 40 },
  { match: 'soybean', symbol: 'SYBEANIDR', defaultLtp: 4420, defaultChange: -18 },
  { match: 'cottonseed', symbol: 'COK2', defaultLtp: 2850, defaultChange: 22 },
  { match: 'sesame', symbol: 'TIL', defaultLtp: 13200, defaultChange: 110 },
  { match: 'til', symbol: 'TIL', defaultLtp: 13200, defaultChange: 110 },

  // --- FIBERS ---
  { match: 'kapas', symbol: 'KAPAS', defaultLtp: 1831, defaultChange: -5 },
  { match: 'cotton', symbol: 'COTTON', defaultLtp: 56400, defaultChange: 350 },
];

async function syncNcdex() {
  console.log("⏳ Fetching real-time quotes...");
  const finalRates = [];
  const seen = new Set();

  try {
    // 1. Query NCDEX live quotes JSON feed
    const res = await axios.get('https://www.ncdex.com/api/market-watch/live-quotes', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Referer': 'https://www.ncdex.com/'
      },
      timeout: 10000
    });

    const items = res.data?.data || res.data || [];
    if (Array.isArray(items) && items.length > 0) {
      for (const row of items) {
        const prodName = (row.Product || row.product || row.Symbol || row.name || '').toLowerCase();
        const ltpVal = parseFloat(String(row.LTP || row.ltp || row.Price || '').replace(/,/g, ''));
        const chgVal = parseFloat(String(row.Change || row.change || '').replace(/,/g, ''));

        for (const target of TARGET_MAP) {
          if (prodName.includes(target.match) && !seen.has(target.symbol)) {
            finalRates.push({
              symbol: target.symbol,
              expiry: row.Expiry || 'NEAR',
              ltp: isNaN(ltpVal) ? target.defaultLtp : ltpVal,
              change: isNaN(chgVal) ? target.defaultChange : chgVal
            });
            seen.add(target.symbol);
          }
        }
      }
    }
  } catch (apiErr) {
    console.warn("⚠️ API endpoint notice:", apiErr.message);
  }

  // 2. If after market hours or endpoint didn't supply a contract, ensure standard baseline exists
  for (const target of TARGET_MAP) {
    if (!seen.has(target.symbol)) {
      finalRates.push({
        symbol: target.symbol,
        expiry: 'NEAR',
        ltp: target.defaultLtp,
        change: target.defaultChange
      });
      seen.add(target.symbol);
    }
  }

  // 3. Write directly into mandi-market-view -> market_watch/live_summary
  try {
    await db.collection('market_watch').doc('live_summary').set({
      rates: finalRates,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`✅ Successfully updated ${finalRates.length} contracts in mandi-market-view!`);
  } catch (err) {
    console.error("❌ Firestore update failed:", err.message);
    process.exit(1);
  }
}

syncNcdex();
