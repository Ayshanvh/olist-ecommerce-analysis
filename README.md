# Olist e-ticarət layihəsi: Excel və SQL (1-ci həftə)

**Sektor:** e-ticarət
**Əsas sual:** Hansı müştərilər bizi tərk edir və gəlirin çoxu kimdən gəlir?
**Dataset:** [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle)

## Data haqqında

- 9 cədvəl: müştərilər, sifarişlər, sifariş sətirləri, ödənişlər, rəylər, məhsullar, satıcılar, coğrafi məlumat və kateqoriya tərcüməsi.
- Təxminən 99 min sifariş, 2016-09-dan 2018-09-a qədər.
- Datada "çirkli" hallar var: təkrar rəylər, boş tarixlər, boş məhsul kateqoriyaları, məntiqsiz tarix ardıcıllığı və çox təkrarlanan coğrafi sətirlər.

## Qovluq quruluşu

| Fayl | Nə edir |
|---|---|
| `sql/01_load.sql` | 9 CSV-ni `raw` sxeminə yükləyir. Hamısı TEXT kimi, xam data dəyişmir. |
| `sql/02_clean.sql` | `clean` sxemini qurur: tiplər, təkrarlar, boş xanalar, məntiqsiz qeydlər, açarlar və `cleaning_log`. |
| `sql/03_analysis.sql` | 10 biznes sualı (JOIN, GROUP BY, window funksiyaları, CTE). |
| `er/er_diagram.md`, `er/olist.dbml` | ER diaqram (Mermaid və dbdiagram.io formatı). |
| `docs/column_dictionary.csv` | Hər sütunun mənası, tipi və problemi. |
| `excel/04_excel_export.py` | Təmizləmədən əvvəl və sonrakı vəziyyəti göstərən Excel faylını yaradır. |

## Necə işlətməli

PostgreSQL və Python lazımdır. `psql` CSV faylları olan qovluqdan işə salınmalıdır, çünki `01_load.sql` onları nisbi yolla oxuyur.

```bash
cd /path/to/olist_csv
psql -h localhost -U postgres -d postgres -f /path/to/project/sql/01_load.sql
psql -h localhost -U postgres -d postgres -f /path/to/project/sql/02_clean.sql
psql -h localhost -U postgres -d postgres -f /path/to/project/sql/03_analysis.sql
python /path/to/project/excel/04_excel_export.py
```

## Təmizləmə qərarları

1. **Xam data dəyişmir.** `raw` sxemi olduğu kimi qalır, təmizlənmiş versiya `clean` sxemindədir.
2. **Təkrarlar silinir** (`DISTINCT ON` açar üzrə). Rəylərdə hər sifariş üçün son rəy saxlanılır (551 sətir silindi), çünki bir sifarişin bir neçə rəyi JOIN-da sətirləri artırar. `geolocation` hər poçt indeksi üçün 1 sətirdə birləşdirildi (1 000 163 → 19 015).
3. **Boş xanalar doldurulmur.** Məsələn, ləğv olunmuş sifarişin çatdırılma tarixi boş olmalıdır. Yalnız boş məhsul kateqoriyası (610 məhsul) `unknown` kimi işarələndi.
4. **Məntiqsiz qeydlər silinmir, bayraqlanır** (`a_*` sütunları və `has_anomaly`). Analizdə lazım olanda çıxarılır. Hər qərar `cleaning_log` cədvəlində və Excel faylının `5_Jurnal` vərəqində qeyd olunub.
5. **Müştəri = `customer_unique_id`.** `customer_id` hər sifarişdə yenidən yaranır, ona görə müştəri saymaq üçün yaramır.
6. **"Tərk edən" müştəri** = yalnız 1 sifariş verib və təkrar almayıb. Dataset hazır `churn` sütunu vermir.
7. **Gəlir** = `price` cəmi. Daşıma haqqı daxil deyil. `canceled` və `unavailable` sifarişlər sayılmır.

## Excel hissəsi

Excel faylında vərəqlər: əvvəl/sonra sətir sayları, boş xanalar (xam və təmiz), təkrarlar, təmizləmə jurnalı, sütun lüğəti, aylıq dinamika və Pivot. Pivot ay üzrə gəliri (`price` cəmi) göstərir, ləğv olunmuş və mövcud olmayan sifarişlər çıxarılıb.

## Qısa nəticələr

- Biznes 2017-ci ildə sürətlə böyüyür: 2017-01-də 787 sifariş, 2018-in əvvəlindən ayda təxminən 6–7 min sifariş.
- Ən yüksək ay 2017-11-dir: 7 421 sifariş və təxminən 1,00 milyon BRL gəlir.
- Pivot cəmi: 13 494 400,74 BRL.

## Məhdudiyyətlər

- 2016-09, 2016-12 və 2018-09 aylarında cəmi 1–2 sifariş var, 2016-11 isə yoxdur. Trend təhlilində əsas dövr 2017-01 – 2018-08 götürülməlidir.
- Gəlirə daşıma haqqı daxil deyil.
- `geolocation` poçt indeksinin orta koordinatları ilə təmsil olunur, dəqiq ünvan deyil. Bu cədvəl üçün xarici açar yoxdur.
- Müştəri "tərk etdi" tərifi sadə qaydaya əsaslanır, real churn məlumatı yoxdur.
