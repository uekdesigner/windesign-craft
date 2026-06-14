# Yan Panel Alt Ölçü Senaryoları

`shape_dimension_painter.dart` · `_drawWidthSystem` metodu  
Sabitler: `kBase = 15px` · `kStep = 20px`

---

## Temel kural

Referans nokta her zaman **`panelBotPx`** — panelin alt kenarı piksel konumu.  
`panelBotPx = mainTopPx + attach.height * scale`

Formül:
```
collision  = hasMainInnerV && |panelBotPx - mainBotPx| < kStep
baseOff    = collision ? kBase + kStep : kBase
panelWidthY = panelBotPx + (hasInnerV ? baseOff + kStep : baseOff)
```

---

## Aynı Yükseklik (panel == ana şekil)

`panelBotPx ≈ mainBotPx` — çakışma riski yüksek.

| Durum | Segment çizgisi | Toplam genişlik çizgisi |
|---|---|---|
| İç V yok · main V yok | — | `panelBotPx + 15` |
| İç V yok · main V var | — | `panelBotPx + 35` ⚠ çakışma |
| İç V var · main V yok | `panelBotPx + 15` | `panelBotPx + 35` |
| İç V var · main V var | `panelBotPx + 15` ⚠ çakışma | `panelBotPx + 35` ⚠ çakışma | Burası

---

## Farklı Yükseklik — Panel Daha Kısa

`panelBotPx` ana şekil alt kenarının **üstünde** → `|panelBotPx - mainBotPx| >= kStep` → çakışma yok.

| Durum | Segment çizgisi | Toplam genişlik çizgisi |
|---|---|---|
| İç V yok | — | `panelBotPx + 15` |
| İç V var · main V yok | `panelBotPx + 15` | `panelBotPx + 35` |
| İç V var · main V var | `panelBotPx + 15` | `panelBotPx + 35` |

---

## Farklı Yükseklik — Panel Daha Uzun

`panelBotPx` ana şekil alt kenarının **altında** → çakışma yok.

| Durum | Segment çizgisi | Toplam genişlik çizgisi |
|---|---|---|
| İç V yok | — | `panelBotPx + 15` |
| İç V var (main V durumundan bağımsız) | `panelBotPx + 15` | `panelBotPx + 35` |

---

## Özet

| Durum | Segment | Toplam |
|---|---|---|
| Aynı yük · iç V yok · main V yok | — | +15 |
| Aynı yük · iç V yok · main V var | — | **+35 ⚠** |
| Aynı yük · iç V var · main V yok | +15 | +35 |
| Aynı yük · iç V var · main V var | **+35 ⚠** | **+55 ⚠** |
| Farklı yük · iç V yok | — | +15 |
| Farklı yük · iç V var | +15 | +35 |

---

## Notlar

**⚠ Çakışma:** Sadece aynı yükseklikte panel + ana şekilde iç dikey çizgi var durumunda oluşur.  
`panelBotPx ≈ mainBotPx` olduğundan fark `kStep`'ten küçük → `baseOff` bir adım artar.

**Sağ + Sol panel birlikte:** Her panel kendi `panelBotPx` referansını kullanır, bağımsız hesaplanır. Aynı senaryolar her iki panel için ayrı ayrı geçerlidir.

**Segment çizgisi:** `_drawSidePanelInnerWidths` ile çizilir, yalnızca `hasInnerV == true` olduğunda.  
**Toplam genişlik çizgisi:** `_drawWDimLine` ile çizilir, her zaman gösterilir.
