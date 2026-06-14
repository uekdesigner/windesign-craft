# Ölçü Sistemi Senaryoları

## Sabitler

| Sabit   | Değer | Açıklama            |
|---------|-------|---------------------|
| _kBase  | 15 px | İlk ölçü çizgisi    |
| _kStep  | 20 px | Sonraki her katman   |

Referans noktaları:
- **leftRef** = leftmostPx (sol panel varsa panelin sol kenarı, yoksa ana şeklin sol kenarı)
- **rightRef** = rightmostPx (sağ panel varsa panelin sağ kenarı, yoksa ana şeklin sağ kenarı)
- **botPx** = mainBottomPx, **topPx** = mainTopPx
- Sol tarafta leftRef'den **sola** (−), sağ tarafta rightRef'den **sağa** (+) ölçülür.

---

## A. SOL TARAF YÜKSEKLİK ÖLÇÜ SİSTEMİ

### Senaryo 1 — Sol panel yok (leftAttach == null)

| Alt | Ana İç H | Sol | Sağ | Offset |
|-----|----------|-----|-----|--------|
| 1a  | Yok      | mainExt | — | SOL @15 |
| 1b  | Var      | mainInnerH | — | SOL @15 |
|     |          | mainExt | — | SOL @35 |

---

### Senaryo 2 — Sol panel var, AYNI yükseklik (leftSameHeight)

**Sağ panel YOKSA → ana ölçüler sağa taşınır:**

| Alt | Ana İç H | Sol İç H | SOL taraf | SAĞ taraf |
|-----|----------|----------|-----------|-----------|
| 2a  | Yok      | Yok      | leftExt @15 | — |
| 2b  | Var      | Yok      | leftExt @15 | mainInnerH @15 |
| 2c  | Var      | Var      | leftInnerH @15, leftExt @35 | mainInnerH @15 |
| 2d  | Yok      | Var      | leftInnerH @15, leftExt @35 | — |

**Sağ panel VARSA → hepsi solda (orijinal davranış):**

| Alt | Ana İç H | Sol İç H | SOL taraf |
|-----|----------|----------|-----------|
| 2a  | Yok      | Yok      | leftExt @15 |
| 2b  | Var      | Yok      | mainInnerH @15, leftExt @35 |
| 2c  | Var      | Var      | mainInnerH @15, leftInnerH @35, leftExt @55 |
| 2d  | Yok      | Var      | leftInnerH @15, leftExt @35 |

---

### Senaryo 3 — Sol panel var, FARKLI yükseklik (!leftSameHeight)

**Sağ panel YOKSA → ana ölçüler sağa taşınır:**

| Alt | Ana İç H | Sol İç H | SOL taraf | SAĞ taraf |
|-----|----------|----------|-----------|-----------|
| 3a  | Yok      | Yok      | leftExt @15 | mainExt @15 |
| 3b  | Var      | Yok      | leftExt @15 | mainInnerH @15, mainExt @35 |
| 3c  | Var      | Var      | leftInnerH @15, leftExt @35 | mainInnerH @15, mainExt @35 |
| 3d  | Yok      | Var      | leftInnerH @15, leftExt @35 | mainExt @15 |

**Sağ panel VARSA → panel en yakın, ana en dışta, hepsi solda:**

| Alt | Ana İç H | Sol İç H | SOL taraf |
|-----|----------|----------|-----------|
| 3a  | Yok      | Yok      | leftExt @15, mainExt @35 |
| 3b  | Var      | Yok      | mainInnerH @15, mainExt @35, leftExt @55,|
| 3c  | Var      | Var      | mainInnerH @15, mainExt @35, leftInnerH @55, leftExt @75,|
| 3d  | Yok      | Var      | mainExt @15, leftInnerH @35, leftExt @55,|

---

## B. SAĞ TARAF YÜKSEKLİK ÖLÇÜ SİSTEMİ

### Senaryo 4 — Sağ panel yok

| Durum | SAĞ taraf |
|-------|-----------|
| Sol panel de yok | — (ölçü sadece solda) |
| Sol panel var | mainExt ve/veya mainInnerH sağa taşınır (yukarı bkz.) |

### Senaryo 5 — Sağ panel var, AYNI yükseklik

| Alt | Sağ İç H | SAĞ taraf |
|-----|----------|-----------|
| 5a  | Yok      | — (ana yükseklik sol tarafta) |
| 5b  | Var      | rightInnerH @15, rightExt @35 |

### Senaryo 6 — Sağ panel var, FARKLI yükseklik

| Alt | Sağ İç H | SAĞ taraf |
|-----|----------|-----------|
| 6a  | Yok      | rightExt @15 |
| 6b  | Var      | rightInnerH @15, rightExt @35 |

---

## C. ALT GENİŞLİK ÖLÇÜ SİSTEMİ

### Senaryo 7 — Ana şekil genişliği

| Alt | Ana İç V | Çizilen Ölçüler | Y Pozisyonu |
|-----|----------|-----------------|-------------|
| 7a  | Yok      | mainWidth | botPx + 15 |
| 7b  | Var      | iç segmentler | botPx + 15 |
|     |          | mainWidth | botPx + 35 |

### Senaryo 8 — Panel genişlikleri

| Durum | Y Pozisyonu |
|-------|-------------|
| Normal (panel alt ≠ ana alt) | panelBotPx + 15 |
| Çakışma (panel alt ≈ ana alt VE ana iç V var) | panelBotPx + 35 |

panelBotPx = mainTopPx + attach.height × scale

---

## D. İÇ ÇİZGİ ETİKETLERİ

**Ana şekil** (_drawInternalLineDimensions): Her çizginin üzerinde boyut etiketi.
- Yatay çizgi → genişlik mm, Dikey çizgi → yükseklik mm

**Yan panel** (quadrilateral_painter → _drawSidePanelRects): Segment ölçüleri panel kenarında.
- Yükseklik: sol panel → panelRect.left − 15, sağ panel → panelRect.right + 15
- Genişlik: panelRect.bottom + 15
- Sadece iç bölüm varsa gösterilir (segment sayısı > 1)

---

## E. ÖLÇÜ METOD HARİTASI

| Metod | Ne çizer | Nerede |
|-------|----------|--------|
| _drawHDimLine | Dikey leader + tick + etiket | Yükseklik (sol/sağ) |
| _drawWDimLine | Yatay çizgi + tick + etiket | Genişlik (alt) |
| _drawMainInnerHeights | Ana şekil iç H segmentleri | Sol veya sağ (textOnLeft) |
| _drawSidePanelInnerHeights | Yan panel iç H segmentleri | Sol veya sağ |
| drawLineLabel | Sadece metin etiketi | İç çizgi boyutları |
| drawEdgeLabel | Kenar ortasında etiket | Çapraz kenar ölçüleri |
