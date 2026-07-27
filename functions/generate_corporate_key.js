/**
 * generate_corporate_key.js
 *
 * Kurumsal lisans anahtarı üretme scripti (yerel bilgisayarınızda çalıştırılır).
 * Cloud Functions'ı hiç çağırmadan, doğrudan Firestore'a admin yetkisiyle yazar.
 *
 * KULLANIM:
 *   node generate_corporate_key.js <seats> [durationDays]
 *
 * ÖRNEK:
 *   node generate_corporate_key.js 5        → 5 koltuklu, 365 gün geçerli anahtar
 *   node generate_corporate_key.js 10 180    → 10 koltuklu, 180 gün geçerli anahtar
 *
 * GEREKSİNİM:
 *   1. Firebase Console → Project Settings → Service Accounts → "Generate new private key"
 *      ile bir JSON dosyası indirin.
 *   2. O dosyayı bu scriptle aynı klasöre koyup adını "serviceAccountKey.json" yapın.
 *   3. npm install firebase-admin  (eğer functions klasöründe zaten yüklüyse, bu scripti
 *      functions klasörünün İÇİNE koyup oradan çalıştırabilirsiniz, ayrıca kurmanıza gerek kalmaz)
 */

const admin = require("firebase-admin");
const path = require("path");

const serviceAccountPath = path.join(__dirname, "serviceAccountKey.json");

let serviceAccount;
try {
  serviceAccount = require(serviceAccountPath);
} catch (e) {
  console.error("\nHATA: serviceAccountKey.json bulunamadı.");
  console.error(
    "Firebase Console > Project Settings > Service Accounts > 'Generate new private key' ile indirip"
  );
  console.error(
    `bu scriptle aynı klasöre "serviceAccountKey.json" adıyla koyun: ${__dirname}\n`
  );
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── Argümanlar ──────────────────────────────────────────────────────────────
const args = process.argv.slice(2);
const seats = parseInt(args[0], 10);
const durationDays = args[1] ? parseInt(args[1], 10) : 365;
const appId = "windesign_craft";

if (!Number.isInteger(seats) || seats < 1) {
  console.error("\nHATA: Geçerli bir koltuk (seats) sayısı girin.");
  console.error("Kullanım: node generate_corporate_key.js <seats> [durationDays]");
  console.error("Örnek:    node generate_corporate_key.js 5\n");
  process.exit(1);
}

// ── Anahtar üretimi (Cloud Functions'daki generateLicenseKey ile aynı format) ──
function generateKey() {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const seg = () =>
    Array.from({ length: 4 }, () => chars[Math.floor(Math.random() * chars.length)]).join("");
  return `WDC-${seg()}-${seg()}-${seg()}`;
}

async function main() {
  const key = generateKey();

  await db.collection("licenseKeys").doc(key).set({
    appId: appId,
    tier: "corporate",
    durationDays: durationDays,
    seats: seats,
    used: false,
    usedBy: null,
    usedAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log("\n✅ Kurumsal lisans anahtarı oluşturuldu!\n");
  console.log(`   Anahtar     : ${key}`);
  console.log(`   Koltuk      : ${seats}`);
  console.log(`   Geçerlilik  : ${durationDays} gün`);
  console.log(`   Uygulama    : ${appId}\n`);
  console.log("Bu anahtarı firma sahibine iletin — uygulamada Ayarlar > Lisans >");
  console.log('"Kurumsal Lisansım Var" ekranından firma adı + bu anahtarla aktifleştirebilir.\n');

  process.exit(0);
}

main().catch((err) => {
  console.error("\nHATA:", err.message);
  process.exit(1);
});
