# Olist e-ticarət layihəsi: 1-ci həftə (Excel və SQL)

**Sektor:** e-ticarət
**Əsas sual:** Hansı müştərilər bizi tərk edir və gəlirin çoxu kimdən gəlir?
**Dataset:** Brazilian E-Commerce Public Dataset by Olist (Kaggle), 9 cədvəl, 2016-2018

## Qovluq quruluşu

| Fayl | Nə edir |
|---|---|
| `sql/01_load.sql` | 9 CSV-ni `raw` sxeminə yükləyir (hamısı TEXT, xam data toxunulmaz) |
| `sql/02_clean.sql` | `clean` sxemini qurur: tiplər, təkrarlar, boş xanalar, məntiqsiz qeydlər, açarlar, `cleaning_log` |
| `sql/03_analysis.sql` | 10 biznes sualı (JOIN, GROUP BY, window funksiyaları, CTE) |
| `er/er_diagram.md`, `er/olist.dbml` | ER diaqram (Mermaid və dbdiagram.io) |
| `docs/column_dictionary.csv` | Hər sütunun mənası, tipi və problemi |
| `excel/04_excel_export.py` | Əvvəl/sonra Excel faylını yaradır (`olist_before_after.xlsx`) |

## İşlətmə sırası (Colab və ya lokal PostgreSQL)

```bash
cd /content/olist                                   # CSV faylları olan qovluq
export PGPASSWORD=postgres
psql -h localhost -U postgres -d postgres -f /content/olist_project/sql/01_load.sql
psql -h localhost -U postgres -d postgres -f /content/olist_project/sql/02_clean.sql
psql -h localhost -U postgres -d postgres -f /content/olist_project/sql/03_analysis.sql
python /content/olist_project/excel/04_excel_export.py
```

`01_load.sql` CSV-ləri relativ yolla oxuyur, ona görə `psql` CSV qovluğunda işlədilməlidir.

## Əsas qərarlar

1. **Xam data toxunulmazdır.** `raw` sxemi dəyişmir, təmizlənmiş versiya `clean` sxemindədir.
2. **Təkrarlar silinir** (`DISTINCT ON` açar üzrə). Rəylərdə sifariş başına son rəy qalır, çünki bəzi sifarişlərin bir neçə rəyi var və JOIN sətirləri artırar.
3. **Boş xanalar doldurulmur.** Məsələn çatdırılma tarixi ləğv olunmuş sifarişdə boş olmalıdır. Yalnız məhsul kateqoriyası `unknown` kimi işarələnir.
4. **Məntiqsiz qeydlər silinmir, bayraqlanır** (`a_*` sütunları və `has_anomaly`). Analizdə lazım olanda çıxarılır (Q8, Q9).
5. **Müştəri = `customer_unique_id`.** `customer_id` hər sifarişdə yenidən yaranır.
6. **"Tərk edən" müştəri** = yalnız 1 sifariş verib və təkrar almayıb. Dataset hazır `churn` sütunu vermir.
7. **Gəlir** = `price` cəmi. Daşıma haqqı daxil deyil. `canceled` və `unavailable` sifarişlər sayılmır.

