const path = require('path');
const fs = require('fs');
const puppeteer = require('puppeteer');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

let serviceAccount;
const keyPath = path.join(__dirname, 'serviceAccountKey.json');

if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else if (fs.existsSync(keyPath)) {
  serviceAccount = require(keyPath);
} else {
  console.error("No service account credentials found!");
  process.exit(1);
}

if (getApps().length === 0) {
  initializeApp({ credential: cert(serviceAccount) });
}

const db = getFirestore();

const TARGET_SYMBOLS = [
  { match: 'guar seed', symbol: 'GUARSEED10' },
  { match: 'isabgol', symbol: 'ISABGOL' },
  { match: 'jeera mini', symbol: 'JEERAMINI' },
  { match: 'jeera', symbol: 'JEERAUNJHA' },
  { match: 'kapas', symbol: 'KAPAS' },
  { match: 'guar gum', symbol: 'GUARGUM5' },
  { match: 'dhaniya', symbol: 'DHANIYA' },
  { match: 'turmeric', symbol: 'TMCFGRNZM' },
  { match: 'castor', symbol: 'CASTOR' }
];

const cleanNum = (str) => {
  if (!str) return 0;
  const num = parseFloat(String(str).replace(/,/g, '').trim());
  return isNaN(num) ? 0 : num;
};

async function cleanupOldDocuments() {
  const snapshot = await db.collection('market_watch').get();
  const batch = db.batch();
  let deleted = 0;

  snapshot.forEach(doc => {
    // Delete individual old commodity docs, keeping only live_summary
    if (doc.id !== 'live_summary') {
      batch.delete(doc.ref);
      deleted++;
    }
  });

  if (deleted > 0) {
    await batch.commit();
    console.log(`Cleaned up ${deleted} old documents from Firestore.`);
  }
}

async function startConsolidatedSync() {
  await cleanupOldDocuments();

  console.log("Launching scraper for minimal terminal view...");
  const browser = await puppeteer.launch({
    headless: "new",
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage', '--disable-gpu']
  });

  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36');

  try {
    await page.goto('https://www.ncdex.com/market-watch/live_quotes', {
      waitUntil: 'networkidle2',
      timeout: 60000
    });

    await page.waitForSelector('table', { timeout: 30000 }).catch(() => null);

    const rows = await page.evaluate(() => {
      return Array.from(document.querySelectorAll('table tbody tr, table tr'))
        .map(r => Array.from(r.querySelectorAll('td')).map(td => td.innerText.trim()))
        .filter(c => c.length >= 7);
    });

    const contracts = [];

    for (const cols of rows) {
      const rawName = cols[0];
      const expiry = cols[1];
      const matched = TARGET_SYMBOLS.find(t => rawName.toLowerCase().includes(t.match));

      if (matched && expiry) {
        const ltpParts = cols[3].split(/\s+/).filter(Boolean);
        const ltp = cleanNum(ltpParts.length >= 3 ? ltpParts[1] : ltpParts[0]);
        const change = cleanNum(cols[5]);

        // Storing ONLY the 4 terminal fields
        contracts.push({
          symbol: matched.symbol,
          expiry: expiry.toUpperCase(),
          ltp: ltp,
          change: change
        });
      }
    }

    if (contracts.length > 0) {
      await db.collection('market_watch').doc('live_summary').set({
        rates: contracts,
        lastUpdated: FieldValue.serverTimestamp()
      });
      console.log(`Stored ${contracts.length} contracts with minimal fields in 'market_watch/live_summary'.`);
    }
  } catch (err) {
    console.error("Execution error:", err.message);
  } finally {
    await browser.close();
  }
}

startConsolidatedSync();
