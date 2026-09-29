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
  const num = parseFloat(str.replace(/,/g, '').trim());
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

async function startLiveSync() {
  console.log("Launching Headless Chromium to bypass Cloudflare guard...");

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

  console.log("Navigating to NCDEX Live Quotes terminal...");
  await page.goto('https://www.ncdex.com/market-watch/live_quotes', {
    waitUntil: 'networkidle2',
    timeout: 60000
  });

  // Wait for table to render past the loader
  await page.waitForSelector('table', { timeout: 30000 }).catch(() => null);

  // Run continuous loop (e.g. 50 iterations, 5 seconds apart = ~4.5 minutes per GitHub Actions run)
  const maxIterations = process.env.GITHUB_ACTIONS ? 45 : 3;

  for (let i = 0; i < maxIterations; i++) {
    const tableData = await scrapeLivePage(page);
    const batch = db.batch();
    let updatedCount = 0;

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

        const docId = `${matched.symbol}_${expiry.replace(/[^a-zA-Z0-9]/g, '').toUpperCase()}`;
        const docRef = db.collection('market_watch').doc(docId);

        batch.set(docRef, {
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
          exchange: 'NCDEX',
          lastUpdated: FieldValue.serverTimestamp()
        }, { merge: true });

        updatedCount++;
      }
    }

    if (updatedCount > 0) {
      await batch.commit();
      console.log(`[Tick ${i + 1}/${maxIterations}] Synced ${updatedCount} live contracts directly from exchange DOM.`);
    }

    // Wait 5 seconds before next tick
    await new Promise(r => setTimeout(r, 5000));
  }

  await browser.close();
}

startLiveSync().catch(err => {
  console.error("Scraper encountered an error:", err);
  process.exit(1);
});

