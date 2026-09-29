const path = require('path');
const fs = require('fs');
const puppeteer = require('puppeteer');
const { initializeApp, cert, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// Initialize Firebase Admin
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
  { match: 'guar seed', symbol: 'GUARSEED10', name: 'Guar Seed 10 MT' },
  { match: 'guar gum', symbol: 'GUARGUM5', name: 'Guar Gum Refined Splits' },
  { match: 'jeera', symbol: 'JEERAUNJHA', name: 'Jeera Unjha' },
  { match: 'dhaniya', symbol: 'DHANIYA', name: 'Coriander Badami' },
  { match: 'turmeric', symbol: 'TMCFGRNZM', name: 'Turmeric Farmer Polished' },
  { match: 'castor', symbol: 'CASTOR', name: 'Castor Seed' },
  { match: 'cocudakl', symbol: 'COCUDAKL', name: 'Cotton Seed Oilcake' }
];

const cleanNum = (str) => {
  if (!str) return 0;
  const num = parseFloat(String(str).replace(/,/g, '').trim());
  return isNaN(num) ? 0 : num;
};

async function scrapeLivePage(page) {
  return await page.evaluate(() => {
    const rows = Array.from(document.querySelectorAll('table tbody tr, table tr'));
    return rows.map(r => {
      const cells = Array.from(r.querySelectorAll('td')).map(td => td.innerText.trim());
      return cells;
    }).filter(c => c.length >= 7);
  });
}

async function startConsolidatedSync() {
  console.log("Launching headless browser for single-document market sync...");

  const browser = await puppeteer.launch({
    headless: "new",
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--no-first-run',
      '--no-zygote',
      '--disable-gpu'
    ]
  });

  const page = await browser.newPage();
  await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36');

  try {
    await page.goto('https://www.ncdex.com/market-watch/live_quotes', {
      waitUntil: 'networkidle2',
      timeout: 60000
    });

    await page.waitForSelector('table', { timeout: 30000 }).catch(() => null);

    const tableData = await scrapeLivePage(page);
    const contracts = [];

    for (const cols of tableData) {
      const rawName = cols[0];
      const expiry = cols[1];
      const matched = TARGET_SYMBOLS.find(t => rawName.toLowerCase().includes(t.match));

      if (matched && expiry) {
        const open = cleanNum(cols[2]);
        const ltpParts = cols[3].split(/\s+/).filter(Boolean);
        let low = 0, ltp = 0, high = 0;

        if (ltpParts.length >= 3) {
          low = cleanNum(ltpParts[0]);
          ltp = cleanNum(ltpParts[1]);
          high = cleanNum(ltpParts[2]);
        } else {
          ltp = cleanNum(ltpParts[0]);
        }

        const close = cleanNum(cols[4]);
        const change = cleanNum(cols[5]);
        const pctChange = cleanNum(cols[6]);
        const bid = cols.length > 10 ? cleanNum(cols[10]) || ltp : ltp;
        const ask = cols.length > 11 ? cleanNum(cols[11]) || ltp : ltp;

        contracts.push({
          symbol: matched.symbol,
          name: matched.name,
          expiry: expiry,
          ltp: ltp,
          open: open,
          high: high,
          low: low,
          close: close,
          change: change,
          pctChange: pctChange,
          bid: bid,
          ask: ask,
          exchange: 'NCDEX'
        });
      }
    }

    if (contracts.length > 0) {
      // 1 single write consumes only 1 Firestore write quota credit
      await db.collection('market_watch').doc('live_summary').set({
        rates: contracts,
        totalItems: contracts.length,
        lastUpdated: FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`Successfully synced all ${contracts.length} commodities into a single Firestore document!`);
    } else {
      console.warn("No matching commodities parsed from DOM table.");
    }

  } catch (err) {
    console.error("Scraper execution error:", err.message);
  } finally {
    await browser.close();
  }
}

startConsolidatedSync();
