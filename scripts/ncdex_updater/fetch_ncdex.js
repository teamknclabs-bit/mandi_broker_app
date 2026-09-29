const axios = require('axios');
const cheerio = require('cheerio');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Initialize Firebase Admin SDK
let serviceAccount;

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  // Read from GitHub Actions secret
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  // Read from local development file
  const localKeyPath = path.join(__dirname, 'serviceAccountKey.json');
  if (fs.existsSync(localKeyPath)) {
    serviceAccount = require(localKeyPath);
  } else {
    console.error('No service account credentials found!');
    process.exit(1);
  }
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// Helper to safely parse exchange table strings to numbers
function parseNum(str) {
  if (!str) return 0;
  const cleaned = str.replace(/,/g, '').trim();
  const num = parseFloat(cleaned);
  return isNaN(num) ? 0 : num;
}

async function syncNcdexRates() {
  try {
    console.log('Fetching live table from NCDEX...');

    // NCDEX official Live Quotes public page
    const url = 'https://www.ncdex.com/market-watch/live_quotes';
    const response = await axios.get(url, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      },
      timeout: 15000
    });

    const $ = cheerio.load(response.data);
    const batch = db.batch();
    let recordsUpdated = 0;

    // Scan table rows on NCDEX live quotes table
    $('table tbody tr').each((index, element) => {
      const tds = $(element).find('td');
      if (tds.length >= 10) {
        const symbolRaw = $(tds[0]).text().trim(); // e.g. "Guar seed", "Jeera"
        const expiryRaw = $(tds[1]).text().trim(); // e.g. "16-Oct-2026"
        const open = parseNum($(tds[2]).text());
        
        // Split Low, LTP, High column
        const midText = $(tds[3]).text().trim().split(/\s+/);
        const low = parseNum(midText[0]);
        const ltp = parseNum(midText[1]);
        const high = parseNum(midText[2]);

        const prevClose = parseNum($(tds[4]).text());
        const change = parseNum($(tds[5]).text());
        const bid = parseNum($(tds[10]).text());
        const ask = parseNum($(tds[11]).text());

        // Map names to terminal symbols
        let symbol = symbolRaw.toUpperCase().replace(/\s+/g, '');
        if (symbol.includes('GUARSEED')) symbol = 'GUARSEED10';
        if (symbol.includes('JEERA')) symbol = 'JEERAUNJHA';

        const docId = `${symbol}_${expiryRaw.replace(/-/g, '').toUpperCase()}`;
        const docRef = db.collection('market_watch').doc(docId);

        batch.set(docRef, {
          symbol: symbol,
          expiry: expiryRaw.replace(/-/g, '').toUpperCase(),
          exchange: 'NCDEX',
          ltp: ltp || prevClose,
          change: change,
          high: high || ltp,
          low: low || ltp,
          open: open,
          prevClose: prevClose,
          bid: bid || ltp,
          ask: ask || (ltp > 0 ? ltp + 5 : 0),
          lastUpdated: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        recordsUpdated++;
      }
    });

    if (recordsUpdated > 0) {
      await batch.commit();
      console.log(`Success! Updated ${recordsUpdated} commodities in Firestore.`);
    } else {
      console.log('No table rows detected. Using initial seed values.');
      _seedDefaultContracts(batch);
      await batch.commit();
      console.log('Seeded default market watch contracts.');
    }
  } catch (error) {
    console.error('Error updating NCDEX Bhav:', error.message);
  }
}

// Fallback seed data matching live trading contracts
function _seedDefaultContracts(batch) {
  const seedItems = [
    { id: 'GUARSEED10_16OCT2026', symbol: 'GUARSEED10', expiry: '16OCT2026', exchange: 'NCDEX', ltp: 6728, change: -92, high: 6795, low: 6548, open: 6775, prevClose: 6820, bid: 6728, ask: 6734 },
    { id: 'GUARSEED10_20NOV2026', symbol: 'GUARSEED10', expiry: '20NOV2026', exchange: 'NCDEX', ltp: 6795, change: -98, high: 6870, low: 6782, open: 6855, prevClose: 6893, bid: 6795, ask: 6797 },
    { id: 'JEERAUNJHA_19OCT2026', symbol: 'JEERAUNJHA', expiry: '19OCT2026', exchange: 'NCDEX', ltp: 22015, change: -295, high: 22375, low: 21925, open: 22325, prevClose: 22310, bid: 22005, ask: 22050 },
    { id: 'JEERAUNJHA_20NOV2026', symbol: 'JEERAUNJHA', expiry: '20NOV2026', exchange: 'NCDEX', ltp: 22430, change: -315, high: 22795, low: 22350, open: 22795, prevClose: 22745, bid: 22400, ask: 22525 },
    { id: 'ISABGOL_19OCT2026', symbol: 'ISABGOL', expiry: '19OCT2026', exchange: 'NCDEX', ltp: 14650, change: 0, high: 14650, low: 14650, open: 14650, prevClose: 14650, bid: 14600, ask: 14700 },
    { id: 'CRUDEOIL_19OCT2026', symbol: 'CRUDEOIL', expiry: '19OCT2026', exchange: 'MCX', ltp: 5940, change: 45, high: 5980, low: 5890, open: 5900, prevClose: 5895, bid: 5938, ask: 5941 },
    { id: 'MUSTARD_JAIPUR', symbol: 'MUSTARD SPOT', expiry: 'JAIPUR', exchange: 'OTHERS', ltp: 5750, change: 30, high: 5800, low: 5710, open: 5720, prevClose: 5720, bid: 5745, ask: 5755 }
  ];

  for (const item of seedItems) {
    const docRef = db.collection('market_watch').doc(item.id);
    batch.set(docRef, { ...item, lastUpdated: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
}
