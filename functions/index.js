const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onMessagePublished } = require("firebase-functions/v2/pubsub");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { google } = require("googleapis");

initializeApp();
const db = getFirestore();

// Deneme süresi: 12 gün
const TRIAL_DAYS = 12;

// Kayıtlı uygulama ID'leri
const VALID_APPS = ["windesign_craft"];

// Admin e-postaları
const ADMIN_EMAILS = ["muratalper81@gmail.com"];

// Google Play Billing
const ANDROID_PACKAGE_NAME = "com.uekdesigner.windesigncraft";
const PLAY_BILLING_TOPIC = "play-billing-notifications";

/**
 * Android Publisher API istemcisi (Cloud Functions'ın çalıştığı servis
 * hesabının kimliğiyle — Play Console'da bu hesaba izin verilmiş olmalı).
 */
async function getAndroidPublisher() {
    const auth = new google.auth.GoogleAuth({
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const authClient = await auth.getClient();
    return google.androidpublisher({ version: "v3", auth: authClient });
}

/**
 * basePlanId'den tier ismini çıkarır.
 */
function tierFromBasePlanId(basePlanId) {
    return basePlanId === "yillik" ? "yearly" : "monthly";
}

/**
 * Uygulama ID'sini doğrula
 */
function validateAppId(appId) {
    console.log("validateAppId çağrıldı, appId:", appId, "type:", typeof appId);
    if (!appId || typeof appId !== "string" || !VALID_APPS.includes(appId)) {
        throw new HttpsError("invalid-argument", "Geçersiz appId: " + appId);
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
        orgId: data.orgId ?? null,
        orgRole: data.orgRole ?? null,
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

        // Kurumsal lisans: organizasyon durumuna bak
        if (data.orgId) {
            const orgSnap = await db.collection("organizations").doc(data.orgId).get();

            if (orgSnap.exists) {
                const orgData = orgSnap.data();
                const expiresMs = orgData.licenseExpiresAt?.toMillis
                    ? orgData.licenseExpiresAt.toMillis()
                    : 0;

                if (Date.now() > expiresMs) {
                    await ref.update({
                        status: "locked",
                        tier: "expired",
                        updatedAt: FieldValue.serverTimestamp(),
                    });
                    return licenseStatus({ ...data, status: "locked", tier: "expired" });
                }

                return licenseStatus({ ...data, status: "active", tier: "corporate" });
            } else {
                await ref.update({
                    status: "locked",
                    tier: "expired",
                    orgId: FieldValue.delete(),
                    orgRole: FieldValue.delete(),
                    updatedAt: FieldValue.serverTimestamp(),
                });
                return licenseStatus({ ...data, status: "locked", tier: "expired" });
            }
        }

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

        if (keyData.tier === "corporate") {
            throw new HttpsError("permission-denied", "use_redeemCorporateKey");
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
 * redeemCorporateKey
 * Firma sahibi kurumsal anahtarı girer, organizations/{orgId} oluşturulur.
 * Parametre: { appId: "windesign_craft", key: "WDC-XXXX-XXXX-XXXX", orgName: "Firma Adı" }
 */
exports.redeemCorporateKey = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const key = request.data?.key;
    if (!key || typeof key !== "string" || key.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Lisans anahtarı gerekli.");
    }

    const orgName = request.data?.orgName;
    if (!orgName || typeof orgName !== "string" || orgName.trim().length === 0) {
        throw new HttpsError("invalid-argument", "Firma adı gerekli.");
    }

    const email = request.auth.token.email || null;
    const trimmedKey = key.trim().toUpperCase();
    const keyRef = db.collection("licenseKeys").doc(trimmedKey);
    const licRef = licenseRef(uid, appId);
    const orgRef = db.collection("organizations").doc();

    return await db.runTransaction(async (tx) => {
        const keySnap = await tx.get(keyRef);

        if (!keySnap.exists) {
            throw new HttpsError("not-found", "invalid_key");
        }

        const keyData = keySnap.data();

        if (keyData.appId && keyData.appId !== appId) {
            throw new HttpsError("permission-denied", "wrong_app");
        }

        if (keyData.tier !== "corporate") {
            throw new HttpsError("permission-denied", "not_corporate_key");
        }

        if (keyData.used === true) {
            throw new HttpsError("permission-denied", "key_already_used");
        }

        const now = Timestamp.now();
        const days = keyData.durationDays || 365;
        const expiresAt = Timestamp.fromMillis(
            now.toMillis() + days * 24 * 60 * 60 * 1000
        );
        const seats = keyData.seats || 1;

        tx.update(keyRef, {
            used: true,
            usedBy: uid,
            usedAt: FieldValue.serverTimestamp(),
        });

        tx.set(orgRef, {
            appId: appId,
            ownerUid: uid,
            name: orgName.trim(),
            seats: seats,
            seatsUsed: 1,
            licenseExpiresAt: expiresAt,
            members: {
                [uid]: {
                    email: email,
                    addedAt: FieldValue.serverTimestamp(),
                    role: "owner",
                },
            },
            createdAt: FieldValue.serverTimestamp(),
        });

        tx.set(
            licRef,
            {
                status: "active",
                tier: "corporate",
                orgId: orgRef.id,
                orgRole: "owner",
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return {
            success: true,
            orgId: orgRef.id,
            seats: seats,
            expiresAt: expiresAt.toMillis(),
        };
    });
});

/**
 * inviteEmployee
 * Sadece org owner'ı çağırabilir. Koltuk doluysa reddeder.
 * Parametre: { appId, orgId, employeeEmail }
 */
exports.inviteEmployee = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const orgId = request.data?.orgId;
    if (!orgId) throw new HttpsError("invalid-argument", "orgId gerekli.");

    const employeeEmail = request.data?.employeeEmail;
    if (!employeeEmail || typeof employeeEmail !== "string") {
        throw new HttpsError("invalid-argument", "employeeEmail gerekli.");
    }
    const normalizedEmail = employeeEmail.trim().toLowerCase();

    const orgRef = db.collection("organizations").doc(orgId);

    return await db.runTransaction(async (tx) => {
        const orgSnap = await tx.get(orgRef);
        if (!orgSnap.exists) throw new HttpsError("not-found", "org_not_found");

        const orgData = orgSnap.data();

        if (orgData.ownerUid !== uid) {
            throw new HttpsError("permission-denied", "not_org_owner");
        }

        const seatsUsed = orgData.seatsUsed ?? 0;
        if (seatsUsed >= orgData.seats) {
            throw new HttpsError("permission-denied", "seats_full");
        }

        const inviteRef = orgRef.collection("invites").doc(normalizedEmail);
        const inviteSnap = await tx.get(inviteRef);
        if (inviteSnap.exists && inviteSnap.data().status === "pending") {
            throw new HttpsError("already-exists", "already_invited");
        }

        tx.set(inviteRef, {
            email: normalizedEmail,
            invitedAt: FieldValue.serverTimestamp(),
            status: "pending",
        });

        return { success: true, email: normalizedEmail };
    });
});

/**
 * acceptInvite
 * Kullanıcı kendi bekleyen davetini kabul eder (kendi e-postasına gelen davet).
 * Parametre: { appId, orgId }
 */
exports.acceptInvite = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const orgId = request.data?.orgId;
    if (!orgId) throw new HttpsError("invalid-argument", "orgId gerekli.");

    const email = (request.auth.token.email || "").toLowerCase();
    if (!email) throw new HttpsError("failed-precondition", "no_email");

    const orgRef = db.collection("organizations").doc(orgId);
    const inviteRef = orgRef.collection("invites").doc(email);
    const licRef = licenseRef(uid, appId);

    return await db.runTransaction(async (tx) => {
        const inviteSnap = await tx.get(inviteRef);
        if (!inviteSnap.exists || inviteSnap.data().status !== "pending") {
            throw new HttpsError("not-found", "no_pending_invite");
        }

        const orgSnap = await tx.get(orgRef);
        if (!orgSnap.exists) throw new HttpsError("not-found", "org_not_found");
        const orgData = orgSnap.data();

        const seatsUsed = orgData.seatsUsed ?? 0;
        if (seatsUsed >= orgData.seats) {
            throw new HttpsError("permission-denied", "seats_full");
        }

        tx.update(orgRef, {
            seatsUsed: seatsUsed + 1,
            [`members.${uid}`]: {
                email: email,
                addedAt: FieldValue.serverTimestamp(),
                role: "member",
            },
        });

        tx.update(inviteRef, {
            status: "accepted",
            acceptedBy: uid,
            acceptedAt: FieldValue.serverTimestamp(),
        });

        tx.set(
            licRef,
            {
                status: "active",
                tier: "corporate",
                orgId: orgId,
                orgRole: "member",
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return { success: true, orgId: orgId };
    });
});

/**
 * removeEmployee
 * Sadece org owner'ı çağırabilir. Üyeyi çıkarır, o kullanıcı anında kilitlenir.
 * Parametre: { appId, orgId, employeeUid }
 */
exports.removeEmployee = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const orgId = request.data?.orgId;
    const employeeUid = request.data?.employeeUid;
    if (!orgId || !employeeUid) {
        throw new HttpsError("invalid-argument", "orgId ve employeeUid gerekli.");
    }

    const orgRef = db.collection("organizations").doc(orgId);
    const employeeLicRef = licenseRef(employeeUid, appId);

    return await db.runTransaction(async (tx) => {
        const orgSnap = await tx.get(orgRef);
        if (!orgSnap.exists) throw new HttpsError("not-found", "org_not_found");
        const orgData = orgSnap.data();

        if (orgData.ownerUid !== uid) {
            throw new HttpsError("permission-denied", "not_org_owner");
        }

        if (employeeUid === orgData.ownerUid) {
            throw new HttpsError("permission-denied", "cannot_remove_owner");
        }

        if (!orgData.members || !orgData.members[employeeUid]) {
            throw new HttpsError("not-found", "member_not_found");
        }

        const seatsUsed = orgData.seatsUsed ?? 1;

        tx.update(orgRef, {
            seatsUsed: Math.max(0, seatsUsed - 1),
            [`members.${employeeUid}`]: FieldValue.delete(),
        });

        tx.set(
            employeeLicRef,
            {
                status: "locked",
                tier: "expired",
                orgId: FieldValue.delete(),
                orgRole: FieldValue.delete(),
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        return { success: true };
    });
});

/**
 * findMyInvites
 * Kullanıcının kendi e-postasına gelen bekleyen davetleri bulur.
 * Parametre: { appId: "windesign_craft" }
 */
exports.findMyInvites = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const email = (request.auth.token.email || "").toLowerCase();
    if (!email) return { invites: [] };

    const invitesSnap = await db
        .collectionGroup("invites")
        .where("email", "==", email)
        .where("status", "==", "pending")
        .get();

    const invites = [];
    for (const doc of invitesSnap.docs) {
        const orgRef = doc.ref.parent.parent;
        if (!orgRef) continue;
        const orgSnap = await orgRef.get();
        if (!orgSnap.exists) continue;
        const orgData = orgSnap.data();
        if (orgData.appId && orgData.appId !== appId) continue;

        invites.push({
            orgId: orgRef.id,
            orgName: orgData.name || "Bilinmeyen Firma",
            invitedAt: doc.data().invitedAt?.toMillis?.() ?? null,
        });
    }

    return { invites };
});

/**
 * verifyPurchase
 * Flutter tarafında satın alma tamamlanınca çağrılır. Google Play'e sorup
 * gerçekliğini doğrular, lisansı aktive eder.
 * Parametre: { appId, productId: "pro_lisans", purchaseToken }
 */
exports.verifyPurchase = onCall(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Giriş yapılmamış.");

    const appId = request.data?.appId;
    validateAppId(appId);

    const purchaseToken = request.data?.purchaseToken;
    const productId = request.data?.productId;

    if (!purchaseToken || typeof purchaseToken !== "string") {
        throw new HttpsError("invalid-argument", "purchaseToken gerekli.");
    }
    if (!productId || typeof productId !== "string") {
        throw new HttpsError("invalid-argument", "productId gerekli.");
    }

    const publisher = await getAndroidPublisher();

    let sub;
    try {
        const res = await publisher.purchases.subscriptionsv2.get({
            packageName: ANDROID_PACKAGE_NAME,
            token: purchaseToken,
        });
        sub = res.data;
    } catch (err) {
        console.error("verifyPurchase: Play API hatası:", err.message);
        throw new HttpsError("internal", "purchase_verification_failed");
    }

    const lineItem = (sub.lineItems || [])[0];
    if (!lineItem) {
        throw new HttpsError("failed-precondition", "no_line_item");
    }

    const basePlanId = lineItem.offerDetails?.basePlanId || "";
    const tier = tierFromBasePlanId(basePlanId);
    const expiryMs = lineItem.expiryTime ? new Date(lineItem.expiryTime).getTime() : 0;
    const autoRenewing = lineItem.autoRenewingPlan?.autoRenewEnabled ?? false;

    const activeStates = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"];
    const isActive = activeStates.includes(sub.subscriptionState) && Date.now() < expiryMs;

    // Satın almayı onaylıyoruz (acknowledge) — bu yapılmazsa Google 3 gün
    // içinde otomatik iade eder. Zaten onaylıysa hata verir, sessizce yutuyoruz.
    try {
        await publisher.purchases.subscriptions.acknowledge({
            packageName: ANDROID_PACKAGE_NAME,
            subscriptionId: productId,
            token: purchaseToken,
            requestBody: {},
        });
    } catch (ackErr) {
        console.log("verifyPurchase: acknowledge atlandı (muhtemelen zaten onaylı):", ackErr.message);
    }

    // purchaseToken -> uid eşleştirmesi (RTDN bildirimleri bunu kullanacak)
    await db.collection("purchaseTokens").doc(purchaseToken).set({
        uid: uid,
        appId: appId,
        productId: productId,
        updatedAt: FieldValue.serverTimestamp(),
    });

    await licenseRef(uid, appId).set(
        {
            status: isActive ? "active" : "locked",
            tier: isActive ? tier : "expired",
            licenseExpiresAt: Timestamp.fromMillis(expiryMs || Date.now()),
            billingSource: "play_billing",
            purchaseToken: purchaseToken,
            autoRenewing: autoRenewing,
            updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
    );

    return {
        success: true,
        active: isActive,
        tier: tier,
        expiresAt: expiryMs,
    };
});

/**
 * onPlayBillingNotification
 * Google Play'in Pub/Sub üzerinden gönderdiği gerçek zamanlı abonelik
 * bildirimlerini (yenilendi, iptal edildi, süresi doldu vb.) işler.
 */
exports.onPlayBillingNotification = onMessagePublished(
    PLAY_BILLING_TOPIC,
    async (event) => {
        const json = event.data.message.json;
        const notif = json?.subscriptionNotification;

        if (!notif) {
            console.log("RTDN: subscriptionNotification yok, atlanıyor.", JSON.stringify(json));
            return;
        }

        const purchaseToken = notif.purchaseToken;
        const tokenSnap = await db.collection("purchaseTokens").doc(purchaseToken).get();

        if (!tokenSnap.exists) {
            console.log("RTDN: bilinmeyen purchaseToken, atlanıyor:", purchaseToken);
            return;
        }

        const { uid, appId } = tokenSnap.data();

        const publisher = await getAndroidPublisher();
        let sub;
        try {
            const res = await publisher.purchases.subscriptionsv2.get({
                packageName: ANDROID_PACKAGE_NAME,
                token: purchaseToken,
            });
            sub = res.data;
        } catch (err) {
            console.error("RTDN: Play API sorgu hatası:", err.message);
            return;
        }

        const lineItem = (sub.lineItems || [])[0];
        const basePlanId = lineItem?.offerDetails?.basePlanId || "";
        const tier = tierFromBasePlanId(basePlanId);
        const expiryMs = lineItem?.expiryTime ? new Date(lineItem.expiryTime).getTime() : 0;
        const autoRenewing = lineItem?.autoRenewingPlan?.autoRenewEnabled ?? false;

        const activeStates = ["SUBSCRIPTION_STATE_ACTIVE", "SUBSCRIPTION_STATE_IN_GRACE_PERIOD"];
        const isActive = activeStates.includes(sub.subscriptionState) && Date.now() < expiryMs;

        await licenseRef(uid, appId).set(
            {
                status: isActive ? "active" : "locked",
                tier: isActive ? tier : "expired",
                licenseExpiresAt: Timestamp.fromMillis(expiryMs || Date.now()),
                billingSource: "play_billing",
                autoRenewing: autoRenewing,
                updatedAt: FieldValue.serverTimestamp(),
            },
            { merge: true }
        );

        console.log(
            `RTDN işlendi: uid=${uid}, notifType=${notif.notificationType}, state=${sub.subscriptionState}`
        );
    }
);

/**
 * generateLicenseKey
 * Sadece admin kullanır.
 * Parametre: { appId: "windesign_craft", tier: "monthly" | "yearly" | "corporate", seats?: number }
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
    if (!tier || !["monthly", "yearly", "corporate"].includes(tier)) {
        throw new HttpsError("invalid-argument", "tier 'monthly', 'yearly' veya 'corporate' olmalı.");
    }

    let seats = 1;
    if (tier === "corporate") {
        seats = request.data?.seats;
        if (!Number.isInteger(seats) || seats < 1) {
            throw new HttpsError("invalid-argument", "corporate tier için geçerli bir 'seats' sayısı gerekli.");
        }
    }

    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
    const seg = () =>
        Array.from(
            { length: 4 },
            () => chars[Math.floor(Math.random() * chars.length)]
        ).join("");
    const key = `WDC-${seg()}-${seg()}-${seg()}`;

    const durationDays = tier === "yearly" ? 365 : tier === "corporate" ? 365 : 30;

    await db.collection("licenseKeys").doc(key).set({
        appId: appId,
        tier: tier,
        durationDays: durationDays,
        seats: seats,
        used: false,
        usedBy: null,
        usedAt: null,
        createdAt: FieldValue.serverTimestamp(),
    });

    return { key: key, tier: tier, durationDays: durationDays, seats: seats, appId: appId };
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