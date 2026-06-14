const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

// Deneme süresi: 12 gün
const TRIAL_DAYS = 12;

// Kayıtlı uygulama ID'leri
const VALID_APPS = ["windesign_craft"];

// Admin e-postaları
const ADMIN_EMAILS = ["muratalper81@gmail.com"];

/**
 * Uygulama ID'sini doğrula
 */
function validateAppId(appId) {
    if (!appId || typeof appId !== "string" || !VALID_APPS.includes(appId)) {
        throw new HttpsError("invalid-argument", "Geçersiz appId.");
    }
}

/**
 * Lisans doküman referansı: licenses/{uid}/apps/{appId}
 */
function licenseRef(uid, appId) {
    return db.collection("licenses").doc(uid).collection("apps").doc(appId);
}

/**
 * Deneme süresi dolmuş mu?
 */
function isTrialExpired(data) {
    if (data.status === "active") return false;
    const ends = data.trialEndsAt;
    if (!ends) return false;
    const endsMs = ends.toMillis ? ends.toMillis() : 0;
    return Date.now() > endsMs;
}

/**
 * Uygulamaya dönecek sade lisans durumu
 */
function licenseStatus(data) {
    const trialEndsMs = data.trialEndsAt?.toMillis
        ? data.trialEndsAt.toMillis()
        : data.trialEndsAt?._seconds
            ? data.trialEndsAt._seconds * 1000
            : null;

    const licenseExpiresMs = data.licenseExpiresAt?.toMillis
        ? data.licenseExpiresAt.toMillis()
        : data.licenseExpiresAt?._seconds
            ? data.licenseExpiresAt._seconds * 1000
            : null;

    return {
        status: data.status,
        tier: data.tier,
        trialEndsAt: trialEndsMs,
        licenseExpiresAt: licenseExpiresMs,
        projectCount: data.projectCount ?? 0,
        pdfProjects: data.pdfProjects ?? [],
    };
}

/**
 * ensureLicense
 * Uygulama açılışta (giriş yaptıktan sonra) bir kez çağırır.
 * Parametre: { appId: "windesign_craft" }
 */
exports.ensureLicense = onCall({ enforceAppCheck: false }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const email = request.auth.token.email || null;
    const ref = licenseRef(uid, appId);
    const snap = await ref.get();

    if (snap.exists) {
        const data = snap.data();

        // Lisanslı ama süresi dolmuş mu?
        if (data.status === "active" && data.licenseExpiresAt) {
            const expiresMs = data.licenseExpiresAt.toMillis
                ? data.licenseExpiresAt.toMillis()
                : 0;
            if (Date.now() > expiresMs) {
                await ref.update({
                    status: "locked",
                    tier: "expired",
                    updatedAt: FieldValue.serverTimestamp(),
                });
                return licenseStatus({ ...data, status: "locked", tier: "expired" });
            }
        }

        return licenseStatus(data);
    }

    // İlk giriş → denemeyi başlat
    const now = Timestamp.now();
    const trialEnds = Timestamp.fromMillis(
        now.toMillis() + TRIAL_DAYS * 24 * 60 * 60 * 1000
    );

    const data = {
        email: email,
        status: "trial",
        tier: "trial",
        trialStartedAt: now,
        trialEndsAt: trialEnds,
        projectCount: 0,
        pdfProjects: [],
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
    };

    await ref.set(data);
    return licenseStatus(data);
});

/**
 * createProject
 * Yeni proje oluşturmadan ÖNCE çağırılır.
 * Parametre: { appId: "windesign_craft" }
 */
exports.createProject = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const ref = licenseRef(uid, appId);

    return await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new HttpsError("not-found", "Lisans bulunamadı.");

        const data = snap.data();

        if (data.status === "active") {
            return { allowed: true, reason: "licensed" };
        }

        if (data.status === "locked" || isTrialExpired(data)) {
            if (data.status !== "locked") {
                tx.update(ref, {
                    status: "locked",
                    updatedAt: FieldValue.serverTimestamp(),
                });
            }
            throw new HttpsError("permission-denied", "trial_expired");
        }

        const count = data.projectCount ?? 0;
        if (count >= 2) {
            throw new HttpsError("permission-denied", "project_limit");
        }

        tx.update(ref, {
            projectCount: count + 1,
            updatedAt: FieldValue.serverTimestamp(),
        });

        return { allowed: true, reason: "trial", projectCount: count + 1 };
    });
});

/**
 * generatePdf
 * PDF üretmeden ÖNCE çağırılır.
 * Parametre: { appId: "windesign_craft", projectId: "..." }
 */
exports.generatePdf = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const projectId = request.data?.projectId;
    if (!projectId || typeof projectId !== "string") {
        throw new HttpsError("invalid-argument", "projectId gerekli.");
    }

    const ref = licenseRef(uid, appId);

    return await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) throw new HttpsError("not-found", "Lisans bulunamadı.");

        const data = snap.data();

        if (data.status === "active") {
            return { allowed: true, reason: "licensed" };
        }

        if (data.status === "locked" || isTrialExpired(data)) {
            if (data.status !== "locked") {
                tx.update(ref, {
                    status: "locked",
                    updatedAt: FieldValue.serverTimestamp(),
                });
            }
            throw new HttpsError("permission-denied", "trial_expired");
        }

        const pdfProjects = data.pdfProjects ?? [];
        if (pdfProjects.includes(projectId)) {
            throw new HttpsError("permission-denied", "pdf_already_used");
        }

        tx.update(ref, {
            pdfProjects: FieldValue.arrayUnion(projectId),
            updatedAt: FieldValue.serverTimestamp(),
        });

        return { allowed: true, reason: "trial" };
    });
});

/**
 * redeemLicenseKey
 * Kullanıcı lisans anahtarı girer.
 * Parametre: { appId: "windesign_craft", key: "WDC-XXXX-XXXX-XXXX" }
 */
exports.redeemLicenseKey = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const key = request.data?.key;
    if (!key || typeof key !== "string" || key.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Lisans anahtarı gerekli.");
    }

    const trimmedKey = key.trim().toUpperCase();
    const keyRef = db.collection("licenseKeys").doc(trimmedKey);
    const licRef = licenseRef(uid, appId);

    return await db.runTransaction(async (tx) => {
        const keySnap = await tx.get(keyRef);

        if (!keySnap.exists) {
            throw new HttpsError("not-found", "invalid_key");
        }

        const keyData = keySnap.data();

        // Anahtar bu uygulama için mi?
        if (keyData.appId && keyData.appId !== appId) {
            throw new HttpsError("permission-denied", "wrong_app");
        }

        if (keyData.used === true) {
            throw new HttpsError("permission-denied", "key_already_used");
        }

        const now = Timestamp.now();
        const days = keyData.durationDays || (keyData.tier === "yearly" ? 365 : 30);
        const expiresAt = Timestamp.fromMillis(
            now.toMillis() + days * 24 * 60 * 60 * 1000
        );

        tx.update(keyRef, {
            used: true,
            usedBy: uid,
            usedAt: FieldValue.serverTimestamp(),
        });

        tx.set(
            licRef,
            {
                status: "active",
                tier: keyData.tier || "monthly",
                licenseExpiresAt: expiresAt,
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return {
            success: true,
            tier: keyData.tier || "monthly",
            expiresAt: expiresAt.toMillis(),
        };
    });
});

/**
 * generateLicenseKey
 * Sadece admin kullanır.
 * Parametre: { appId: "windesign_craft", tier: "monthly" | "yearly" }
 */
exports.generateLicenseKey = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const email = request.auth.token.email || "";
    if (!ADMIN_EMAILS.includes(email.toLowerCase())) {
        throw new HttpsError("permission-denied", "not_admin");
    }

    const appId = request.data?.appId;
    validateAppId(appId);

    const tier = request.data?.tier;
    if (!tier || !["monthly", "yearly"].includes(tier)) {
        throw new HttpsError("invalid-argument", "tier 'monthly' veya 'yearly' olmalı.");
    }

    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const seg = () =>
        Array.from(
            { length: 4 },
            () => chars[Math.floor(Math.random() * chars.length)]
        ).join("");
    const key = `WDC-${seg()}-${seg()}-${seg()}`;

    const durationDays = tier === "yearly" ? 365 : 30;

    await db.collection("licenseKeys").doc(key).set({
        appId: appId,
        tier: tier,
        durationDays: durationDays,
        used: false,
        usedBy: null,
        usedAt: null,
        createdAt: FieldValue.serverTimestamp(),
    });

    return { key: key, tier: tier, durationDays: durationDays, appId: appId };
});

/**
 * adminGetUsers
 * Admin paneli için: tüm kullanıcıları ve lisans durumlarını döner.
 * Parametre: { appId: "windesign_craft" }
 */
exports.adminGetUsers = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const email = request.auth.token.email || "";
    if (!ADMIN_EMAILS.includes(email.toLowerCase())) {
        throw new HttpsError("permission-denied", "not_admin");
    }

    const appId = request.data?.appId;
    validateAppId(appId);

    // collectionGroup ile tüm apps dokümanlarını tara
    const appsSnap = await db.collectionGroup("apps").get();

    const users = [];
    for (const doc of appsSnap.docs) {
        if (doc.id !== appId) continue;

        const parentUid = doc.ref.parent.parent.id;
        const data = doc.data();

        users.push({
            uid: parentUid,
            email: data.email ?? null,
            status: data.status ?? "unknown",
            tier: data.tier ?? "unknown",
            trialEndsAt: data.trialEndsAt?.toMillis?.() ?? null,
            licenseExpiresAt: data.licenseExpiresAt?.toMillis?.() ?? null,
            projectCount: data.projectCount ?? 0,
            createdAt: data.createdAt?.toMillis?.() ?? null,
        });
    }

    return { users };
});
/**
 * adminSetLicense
 * Admin paneli için: belirli kullanıcıya lisans atar veya iptal eder.
 * Parametre: { appId, uid, tier, durationDays } veya { appId, uid, action: "revoke" }
 */
exports.adminSetLicense = onCall(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const callerEmail = request.auth.token.email || "";
    if (!ADMIN_EMAILS.includes(callerEmail.toLowerCase())) {
        throw new HttpsError("permission-denied", "not_admin");
    }

    const appId = request.data?.appId;
    validateAppId(appId);

    const targetUid = request.data?.uid;
    if (!targetUid) throw new HttpsError("invalid-argument", "uid gerekli.");

    const action = request.data?.action;
    const ref = licenseRef(targetUid, appId);

    // İptal et
    if (action === "revoke") {
        await ref.set(
            {
                status: "locked",
                tier: "expired",
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );
        return { success: true, action: "revoked" };
    }

    // Lisans ata
    const tier = request.data?.tier;
    if (!tier || !["monthly", "yearly"].includes(tier)) {
        throw new HttpsError("invalid-argument", "tier 'monthly' veya 'yearly' olmalı.");
    }

    const durationDays = request.data?.durationDays ?? (tier === "yearly" ? 365 : 30);
    const now = Timestamp.now();
    const expiresAt = Timestamp.fromMillis(
        now.toMillis() + durationDays * 24 * 60 * 60 * 1000
    );

    await ref.set(
        {
            status: "active",
            tier: tier,
            licenseExpiresAt: expiresAt,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    return {
        success: true,
        action: "activated",
        tier: tier,
        expiresAt: expiresAt.toMillis(),
    };
});