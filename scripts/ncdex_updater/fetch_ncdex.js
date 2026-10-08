const path = require('path');
const fs = require('fs');
const axios = require('axios');
const cheerio = require('cheerio');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// 1. Firebase Credentials Setup
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

if (getApps().length === 0) {
  initializeApp({
    credential: cert(serviceAccount),
    projectId: 'mandi-market-view'
  });
}

const db = getFirestore();

// Commodities to match with exchange display names
const WATCH_ITEMS = [
  { match: 'guar gum', symbol: 'GUARGUM5' },
  { match: 'guar seed', symbol: 'GUARSEED10' },
  { match: 'jeera', symbol: 'JEERAUNJHA' },
  { match: 'turmeric', symbol: 'TMCFGRNZM' },
  { match: 'dhaniya', symbol: 'DHANIYA' },
  { match: 'chana', symbol: 'CHANA' },
  { match: 'castor', symbol: 'CASTOR' },
  { match: 'cotton seed', symbol: 'COK2' },
  { match: 'isabgol', symbol: 'ISABGOL' },
  { match: 'kapas', symbol: 'KAPAS' },
];

async function fetchAccurateNcdexRates() {
  console.log(`[${new Date().toLocaleTimeString('en-IN', { timeZone: 'Asia/Kolkata' })} IST] ⏳ Fetching live exchange quotes...`);
  const finalRates = [];
  const seen = new Set();

  try {
    const res = await axios.get('https://www.ncdex.com/market-watch/live_quotes', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Referer': 'https://www.ncdex.com/',
      },
      timeout: 15000
    });

    const $ = cheerio.load(res.data);

    // Parse live futures table rows
    $('table tbody tr, table tr').each((_, row) => {
      const cols = $(row).find('td').map((_, el) =>$(el).text().trim()).get();
      if (cols.length >= 7) {
        const prodName = cols[0].toLowerCase();
        const expiry = cols[1].toUpperCase().replace(/\s+/g, '-');
        
        // Find price and change
        const ltpRaw = cols[4] || cols[3] || cols[2] || '';
        const ltp = parseFloat(ltpRaw.replace(/,/g, ''));
        const changeRaw = cols[6] || cols[5] || '0';
        const change = parseFloat(changeRaw.replace(/,/g, '').replace(/%/g, ''));

        for (const item of WATCH_ITEMS) {
          if (prodName.includes(item.match)) {
            const key = `${item.symbol}_${expiry}`;
            if (!seen.has(key) && !isNaN(ltp) && ltp > 0) {
              finalRates.push({
                symbol: item.symbol,
                expiry: expiry,
                ltp: ltp,
                change: isNaN(change) ? 0 : change
              });
              seen.add(key);
            }
          }
        }
      }
    });
  } catch (err) {
    console.warn("⚠️ Live page query warning:", err.message);
  }

  // Push to secondary Firestore only when valid rates exist
  if (finalRates.length > 0) {
    try {
      await db.collection('market_watch').doc('live_summary').set({
        rates: finalRates,
        updatedAt: FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`✅ Updated ${finalRates.length} genuine contracts in mandi-market-view!`);
    } catch (dbErr) {
      console.error("❌ Firestore update failed:", dbErr.message);
    }
  } else {
    console.log("ℹ️ Market closed or table refreshing. Existing rates preserved.");
  }
}

// Check if currently within NCDEX hours: 09:00 AM to 05:00 PM IST (Mon-Fri)
function isMarketHours() {
  const istDate = new Date(new Date().toLocaleString('en-US', { timeZone: 'Asia/Kolkata' }));
  const day = istDate.getDay();
  if (day === 0 || day === 6) return false; // Weekend closed
  const hour = istDate.getHours();
  return hour >= 9 && hour < 17;
}

async function startFiveMinSync() {
  // 1. Initial immediate execution
  await fetchAccurateNcdexRates();

  // If triggered by cron or outside trade hours, run once and exit
  if (!isMarketHours()) {
    console.log("ℹ️ Market trading hours closed. Single sync complete.");
    process.exit(0);
  }

  // If running inside active session, loop every 5 minutes (300,000 ms) for 50 minutes per runner job
  console.log("🚀 Starting 5-minute continuous sync loop for active trading hours...");
  let count = 0;
  const maxLoops = 10; // 10 iterations * 5 min = ~50 mins (runner limit friendly)

  const interval = setInterval(async () => {
    count++;
    if (count >= maxLoops || !isMarketHours()) {
      clearInterval(interval);
      console.log("🏁 Cycle ended. Yielding for next scheduled window.");
      process.exit(0);
    }
    await fetchAccurateNcdexRates();
  }, 5 * 60 * 1000);
}

startFiveMinSync();

