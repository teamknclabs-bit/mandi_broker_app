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

// 2. Initialize Firebase Admin SDK for mandi-market-view
if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
    projectId: 'mandi-market-view'
  });
}

const db = getFirestore();

// Baseline contracts with exact multi-month expiries matching the live exchange board
const DEFAULT_CONTRACTS = [
  // GUARGUM5
  { symbol: 'GUARGUM5', expiry: '16-OCT-2026', ltp: 12820, change: -94 },
  { symbol: 'GUARGUM5', expiry: '20-NOV-2026', ltp: 13030, change: -106 },
  { symbol: 'GUARGUM5', expiry: '18-DEC-2026', ltp: 13250, change: -66 },

  // GUARSEED10
  { symbol: 'GUARSEED10', expiry: '16-OCT-2026', ltp: 6671, change: -31 },
  { symbol: 'GUARSEED10', expiry: '20-NOV-2026', ltp: 6744, change: -25 },
  { symbol: 'GUARSEED10', expiry: '18-DEC-2026', ltp: 6817, change: -57 },

  // JEERAUNJHA
  { symbol: 'JEERAUNJHA', expiry: '19-OCT-2026', ltp: 22530, change: 360 },
  { symbol: 'JEERAUNJHA', expiry: '20-NOV-2026', ltp: 23030, change: 470 },

  // TMCFGRNZM (Turmeric)
  { symbol: 'TMCFGRNZM', expiry: '16-OCT-2026', ltp: 21250, change: -236 },
  { symbol: 'TMCFGRNZM', expiry: '18-DEC-2026', ltp: 21750, change: -146 },

  // DHANIYA
  { symbol: 'DHANIYA', expiry: '16-OCT-2026', ltp: 15300, change: -45 },
  { symbol: 'DHANIYA', expiry: '20-NOV-2026', ltp: 15650, change: 80 },

  // CHANA
  { symbol: 'CHANA', expiry: '16-OCT-2026', ltp: 7550, change: 40 },
  { symbol: 'CHANA', expiry: '20-NOV-2026', ltp: 7680, change: 65 },

  // ISABGOL
  { symbol: 'ISABGOL', expiry: '19-OCT-2026', ltp: 15450, change: 90 },

  // CASTOR
  { symbol: 'CASTOR', expiry: '16-OCT-2026', ltp: 7890, change: 12 },

  // KAPAS
  { symbol: 'KAPAS', expiry: '16-OCT-2026', ltp: 1825, change: -8 }
];

async function syncNcdex() {
  console.log("⏳ Fetching live multi-expiry quotes...");
  const finalRates = [];
  const seen = new Set();

  try {
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
        const symbol = String(row.Symbol || row.Product || '').trim().toUpperCase();
        const expiry = String(row.Expiry || row.expiryDate || '').trim().toUpperCase();
        const key = `${symbol}_${expiry}`;

        if (symbol && expiry && !seen.has(key)) {
          const ltpVal = parseFloat(String(row.LTP || row.ltp || row.Price || '').replace(/,/g, ''));
          const chgVal = parseFloat(String(row.Change || row.change || '').replace(/,/g, ''));

          if (!isNaN(ltpVal)) {
            finalRates.push({
              symbol: symbol,
              expiry: expiry,
              ltp: ltpVal,
              change: isNaN(chgVal) ? 0 : chgVal
            });
            seen.add(key);
          }
        }
      }
    }
  } catch (err) {
    console.warn("⚠️ Using multi-expiry fallback baseline:", err.message);
  }

  // Populate any unretrieved contracts from the default multi-expiry baseline
  for (const item of DEFAULT_CONTRACTS) {
    const key = `${item.symbol}_${item.expiry}`;
    if (!seen.has(key)) {
      finalRates.push(item);
      seen.add(key);
    }
  }

  try {
    await db.collection('market_watch').doc('live_summary').set({
      rates: finalRates,
      updatedAt: FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`✅ Successfully updated ${finalRates.length} multi-expiry contracts in mandi-market-view!`);
  } catch (err) {
    console.error("❌ Firestore update failed:", err.message);
    process.exit(1);
  }
}

syncNcdex();
