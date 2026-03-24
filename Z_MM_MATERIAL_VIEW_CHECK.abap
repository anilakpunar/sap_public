*&---------------------------------------------------------------------*
*& Report Z_MM_MATERIAL_VIEW_CHECK
*&---------------------------------------------------------------------*
*& Malzeme Master Gorunum Kontrol Raporu
*& Malzemelerin hangi gorunumleri acilmis, hangilerinde eksik veri var
*& kontrol eder ve ALV formatinda listeler.
*&---------------------------------------------------------------------*
REPORT z_mm_material_view_check.

*----------------------------------------------------------------------*
* Tip Tanimlamalari
*----------------------------------------------------------------------*
TYPES: BEGIN OF ty_result,
         matnr        TYPE matnr,          " Malzeme numarasi
         maktx        TYPE maktx,          " Malzeme tanimi
         mtart        TYPE mtart,          " Malzeme turu
         matkl        TYPE matkl,          " Mal grubu
         ernam        TYPE ernam,          " Yaratan kullanici
         ersda        TYPE ersda,          " Yaratma tarihi
         bukrs        TYPE bukrs,          " Sirket kodu
         werks        TYPE werks_d,        " Uretim yeri
         lgort        TYPE lgort_d,        " Depo yeri
         " Gorunum durumu ve detaylari
         basic_view   TYPE icon_d,         " Temel veri gorunumu
         basic_detail TYPE string,         " Temel veri eksik detay
         class_view   TYPE icon_d,         " Siniflandirma gorunumu
         sales_view   TYPE icon_d,         " Satis gorunumu
         sales_detail TYPE string,         " Satis eksik detay
         purch_view   TYPE icon_d,         " Satin alma gorunumu
         purch_detail TYPE string,         " Satin alma eksik detay
         mrp_view     TYPE icon_d,         " MRP gorunumu
         mrp_detail   TYPE string,         " MRP eksik detay
         acct_view    TYPE icon_d,         " Muhasebe gorunumu
         acct_detail  TYPE string,         " Muhasebe eksik detay
         cost_view    TYPE icon_d,         " Maliyetlendirme gorunumu
         cost_detail  TYPE string,         " Maliyetlendirme eksik detay
         store_view   TYPE icon_d,         " Depolama gorunumu
         store_detail TYPE string,         " Depolama eksik detay
         qual_view    TYPE icon_d,         " Kalite yonetimi gorunumu
         qual_detail  TYPE string,         " Kalite eksik detay
         " Genel durum
         status       TYPE icon_d,         " Genel durum ikonu
         status_text  TYPE char40,         " Durum aciklamasi
       END OF ty_result.

*----------------------------------------------------------------------*
* Veri Tanimlamalari
*----------------------------------------------------------------------*
DATA: gt_result  TYPE TABLE OF ty_result,
      gs_result  TYPE ty_result,
      gt_mara    TYPE TABLE OF mara,
      gs_mara    TYPE mara,
      gt_makt    TYPE TABLE OF makt,
      gs_makt    TYPE makt,
      gt_marc    TYPE TABLE OF marc,
      gs_marc    TYPE marc,
      gt_mard    TYPE TABLE OF mard,
      gs_mard    TYPE mard,
      gt_mvke    TYPE TABLE OF mvke,
      gs_mvke    TYPE mvke,
      gt_mbew    TYPE TABLE OF mbew,
      gs_mbew    TYPE mbew,
      gt_qmat    TYPE TABLE OF qmat,
      gs_qmat    TYPE qmat,
      gt_t001k   TYPE TABLE OF t001k,
      gs_t001k   TYPE t001k.

* ALV degiskenleri
DATA: go_alv       TYPE REF TO cl_salv_table,
      go_columns   TYPE REF TO cl_salv_columns_table,
      go_column    TYPE REF TO cl_salv_column,
      go_functions TYPE REF TO cl_salv_functions_list,
      go_display   TYPE REF TO cl_salv_display_settings,
      go_sorts     TYPE REF TO cl_salv_sorts,
      go_layout    TYPE REF TO cl_salv_layout,
      ls_layout    TYPE salv_s_layout_key.

DATA: gv_detail TYPE string.

*----------------------------------------------------------------------*
* Secim Ekrani
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS: s_matnr FOR gs_mara-matnr,          " Malzeme no
                  s_mtart FOR gs_mara-mtart,           " Malzeme turu
                  s_matkl FOR gs_mara-matkl,           " Mal grubu
                  s_ersda FOR gs_mara-ersda,           " Yaratma tarihi
                  s_bukrs FOR gs_t001k-bukrs,          " Sirket kodu
                  s_werks FOR gs_marc-werks.            " Uretim yeri
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS: p_basic AS CHECKBOX DEFAULT 'X',  " Temel veri kontrolu
              p_sales AS CHECKBOX DEFAULT 'X',  " Satis kontrolu
              p_purch AS CHECKBOX DEFAULT 'X',  " Satin alma kontrolu
              p_mrp   AS CHECKBOX DEFAULT 'X',  " MRP kontrolu
              p_acct  AS CHECKBOX DEFAULT 'X',  " Muhasebe kontrolu
              p_cost  AS CHECKBOX DEFAULT 'X',  " Maliyetlendirme kontrolu
              p_store AS CHECKBOX DEFAULT 'X',  " Depolama kontrolu
              p_qual  AS CHECKBOX DEFAULT 'X'.  " Kalite yonetimi kontrolu
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-b03.
  PARAMETERS: p_miss AS CHECKBOX DEFAULT ' '.   " Sadece eksik gorunumleri goster
SELECTION-SCREEN END OF BLOCK b03.

*----------------------------------------------------------------------*
* Secim Ekrani Metinleri
*----------------------------------------------------------------------*
* TEXT-b01: Malzeme Secim Kriterleri
* TEXT-b02: Kontrol Edilecek Gorunumler
* TEXT-b03: Gosterim Secenekleri

*----------------------------------------------------------------------*
* Baslatma Olayi
*----------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM get_data.
  PERFORM check_views.
  PERFORM display_alv.

*&---------------------------------------------------------------------*
*& Form GET_DATA
*&---------------------------------------------------------------------*
*& Veritabanindan malzeme verilerini okur
*&---------------------------------------------------------------------*
FORM get_data.

  " Temel malzeme verileri (MARA)
  SELECT * FROM mara
    INTO TABLE gt_mara
    WHERE matnr IN s_matnr
      AND mtart IN s_mtart
      AND matkl IN s_matkl
      AND ersda IN s_ersda.

  IF gt_mara IS INITIAL.
    MESSAGE s001(00) WITH 'Secim kriterlerine uygun malzeme bulunamadi.'
      DISPLAY LIKE 'E'.
    LEAVE LIST-PROCESSING.
  ENDIF.

  " Malzeme tanimlari (MAKT)
  SELECT * FROM makt
    INTO TABLE gt_makt
    FOR ALL ENTRIES IN gt_mara
    WHERE matnr = gt_mara-matnr
      AND spras = sy-langu.

  " Uretim yeri - Sirket kodu eslesme tablosu (T001K)
  SELECT * FROM t001k
    INTO TABLE gt_t001k
    WHERE bukrs IN s_bukrs.

  " Uretim yeri verileri (MARC)
  IF gt_t001k IS NOT INITIAL AND s_bukrs IS NOT INITIAL.
    " Sirket kodu filtresi varsa sadece o sirketin uretim yerlerini al
    SELECT * FROM marc
      INTO TABLE gt_marc
      FOR ALL ENTRIES IN gt_mara
      WHERE matnr = gt_mara-matnr
        AND werks IN s_werks.
    " Sirket koduna ait olmayan uretim yerlerini cikar
    DATA: lt_marc_temp TYPE TABLE OF marc.
    LOOP AT gt_marc INTO gs_marc.
      READ TABLE gt_t001k INTO gs_t001k WITH KEY bwkey = gs_marc-werks.
      IF sy-subrc = 0.
        APPEND gs_marc TO lt_marc_temp.
      ENDIF.
    ENDLOOP.
    gt_marc = lt_marc_temp.
  ELSE.
    SELECT * FROM marc
      INTO TABLE gt_marc
      FOR ALL ENTRIES IN gt_mara
      WHERE matnr = gt_mara-matnr
        AND werks IN s_werks.
  ENDIF.

  " Depo yeri verileri (MARD)
  IF gt_marc IS NOT INITIAL.
    SELECT * FROM mard
      INTO TABLE gt_mard
      FOR ALL ENTRIES IN gt_marc
      WHERE matnr = gt_marc-matnr
        AND werks = gt_marc-werks.
  ENDIF.

  " Satis organizasyonu verileri (MVKE)
  SELECT * FROM mvke
    INTO TABLE gt_mvke
    FOR ALL ENTRIES IN gt_mara
    WHERE matnr = gt_mara-matnr.

  " Muhasebe verileri (MBEW)
  IF gt_marc IS NOT INITIAL.
    SELECT * FROM mbew
      INTO TABLE gt_mbew
      FOR ALL ENTRIES IN gt_marc
      WHERE matnr = gt_marc-matnr
        AND bwkey = gt_marc-werks.
  ENDIF.

  " Kalite yonetimi verileri (QMAT)
  IF gt_marc IS NOT INITIAL.
    SELECT * FROM qmat
      INTO TABLE gt_qmat
      FOR ALL ENTRIES IN gt_marc
      WHERE matnr = gt_marc-matnr
        AND werks = gt_marc-werks.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_VIEWS
*&---------------------------------------------------------------------*
*& Her malzeme icin gorunum kontrollerini yapar
*&---------------------------------------------------------------------*
FORM check_views.

  DATA: lv_has_missing TYPE abap_bool,
        lv_marc_found  TYPE abap_bool.

  LOOP AT gt_mara INTO gs_mara.

    " Bu malzemeye ait uretim yeri kayitlarini kontrol et
    lv_marc_found = abap_false.

    LOOP AT gt_marc INTO gs_marc WHERE matnr = gs_mara-matnr.

      lv_marc_found = abap_true.
      CLEAR: gs_result, gv_detail, lv_has_missing.

      " Temel bilgiler
      gs_result-matnr = gs_mara-matnr.
      gs_result-mtart = gs_mara-mtart.
      gs_result-matkl = gs_mara-matkl.
      gs_result-ernam = gs_mara-ernam.
      gs_result-ersda = gs_mara-ersda.
      gs_result-werks = gs_marc-werks.

      " Sirket kodunu uretim yeri uzerinden belirle
      READ TABLE gt_t001k INTO gs_t001k WITH KEY bwkey = gs_marc-werks.
      IF sy-subrc = 0.
        gs_result-bukrs = gs_t001k-bukrs.
      ENDIF.

      " Malzeme tanimini al
      READ TABLE gt_makt INTO gs_makt WITH KEY matnr = gs_mara-matnr.
      IF sy-subrc = 0.
        gs_result-maktx = gs_makt-maktx.
      ENDIF.

      " Depo yeri bilgisini al
      READ TABLE gt_mard INTO gs_mard WITH KEY matnr = gs_marc-matnr
                                                werks = gs_marc-werks.
      IF sy-subrc = 0.
        gs_result-lgort = gs_mard-lgort.
      ENDIF.

      " Gorunum kontrollerini yap
      PERFORM run_view_checks USING    gs_mara gs_marc
                               CHANGING gs_result lv_has_missing.

      " Genel durumu belirle
      IF lv_has_missing = abap_true.
        gs_result-status = icon_led_red.
        gs_result-status_text = 'Eksik Gorunum/Veri Mevcut'.
      ELSE.
        gs_result-status = icon_led_green.
        gs_result-status_text = 'Tum Gorunumler Tamam'.
      ENDIF.

      " Filtreleme: Sadece eksik olanlari goster
      IF p_miss = 'X'.
        IF lv_has_missing = abap_true.
          APPEND gs_result TO gt_result.
        ENDIF.
      ELSE.
        APPEND gs_result TO gt_result.
      ENDIF.

    ENDLOOP. " gt_marc

    " Uretim yeri kaydi yoksa malzemeyi yine de goster
    IF lv_marc_found = abap_false.

      CLEAR: gs_result, gv_detail, lv_has_missing.

      gs_result-matnr = gs_mara-matnr.
      gs_result-mtart = gs_mara-mtart.
      gs_result-matkl = gs_mara-matkl.
      gs_result-ernam = gs_mara-ernam.
      gs_result-ersda = gs_mara-ersda.

      " Malzeme tanimini al
      READ TABLE gt_makt INTO gs_makt WITH KEY matnr = gs_mara-matnr.
      IF sy-subrc = 0.
        gs_result-maktx = gs_makt-maktx.
      ENDIF.

      " Temel veri kontrolu
      IF p_basic = 'X'.
        CLEAR gv_detail.
        PERFORM check_basic_view USING    gs_mara
                                 CHANGING gs_result
                                          gv_detail
                                          lv_has_missing.
        gs_result-basic_detail = gv_detail.
      ENDIF.

      " Uretim yeri kaydi olmayan gorunumler icin eksik isaretle
      IF p_sales = 'X'.
        gs_result-sales_view = icon_led_red.
        gs_result-sales_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_purch = 'X'.
        gs_result-purch_view = icon_led_red.
        gs_result-purch_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_mrp = 'X'.
        gs_result-mrp_view = icon_led_red.
        gs_result-mrp_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_acct = 'X'.
        gs_result-acct_view = icon_led_red.
        gs_result-acct_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_cost = 'X'.
        gs_result-cost_view = icon_led_red.
        gs_result-cost_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_store = 'X'.
        gs_result-store_view = icon_led_red.
        gs_result-store_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.
      IF p_qual = 'X'.
        gs_result-qual_view = icon_led_red.
        gs_result-qual_detail = 'Uretim yeri kaydi yok'.
        lv_has_missing = abap_true.
      ENDIF.

      " Genel durumu belirle
      gs_result-status = icon_led_red.
      gs_result-status_text = 'Uretim Yeri Kaydi Yok'.

      IF p_miss = 'X'.
        IF lv_has_missing = abap_true.
          APPEND gs_result TO gt_result.
        ENDIF.
      ELSE.
        APPEND gs_result TO gt_result.
      ENDIF.

    ENDIF. " lv_marc_found

  ENDLOOP. " gt_mara

  IF gt_result IS INITIAL.
    MESSAGE s001(00) WITH 'Gosterilecek veri bulunamadi.'
      DISPLAY LIKE 'W'.
    LEAVE LIST-PROCESSING.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form RUN_VIEW_CHECKS
*&---------------------------------------------------------------------*
*& Uretim yeri kaydi olan malzemeler icin tum gorunum kontrollerini calistirir
*&---------------------------------------------------------------------*
FORM run_view_checks USING    ps_mara TYPE mara
                              ps_marc TYPE marc
                     CHANGING ps_result TYPE ty_result
                              pv_has_missing TYPE abap_bool.

  "---------------------------------------------------------------
  " 1. Temel Veri Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_basic = 'X'.
    CLEAR gv_detail.
    PERFORM check_basic_view USING    ps_mara
                             CHANGING ps_result
                                      gv_detail
                                      pv_has_missing.
    ps_result-basic_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 2. Satis Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_sales = 'X'.
    CLEAR gv_detail.
    PERFORM check_sales_view USING    ps_marc-matnr
                             CHANGING ps_result
                                      gv_detail
                                      pv_has_missing.
    ps_result-sales_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 3. Satin Alma Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_purch = 'X'.
    CLEAR gv_detail.
    PERFORM check_purchasing_view USING    ps_marc
                                  CHANGING ps_result
                                           gv_detail
                                           pv_has_missing.
    ps_result-purch_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 4. MRP Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_mrp = 'X'.
    CLEAR gv_detail.
    PERFORM check_mrp_view USING    ps_marc
                           CHANGING ps_result
                                    gv_detail
                                    pv_has_missing.
    ps_result-mrp_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 5. Muhasebe Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_acct = 'X'.
    CLEAR gv_detail.
    PERFORM check_accounting_view USING    ps_marc-matnr
                                           ps_marc-werks
                                  CHANGING ps_result
                                           gv_detail
                                           pv_has_missing.
    ps_result-acct_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 6. Maliyetlendirme Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_cost = 'X'.
    CLEAR gv_detail.
    PERFORM check_costing_view USING    ps_marc
                               CHANGING ps_result
                                        gv_detail
                                        pv_has_missing.
    ps_result-cost_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 7. Depolama Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_store = 'X'.
    CLEAR gv_detail.
    PERFORM check_storage_view USING    ps_marc-matnr
                                        ps_marc-werks
                               CHANGING ps_result
                                        gv_detail
                                        pv_has_missing.
    ps_result-store_detail = gv_detail.
  ENDIF.

  "---------------------------------------------------------------
  " 8. Kalite Yonetimi Gorunumu Kontrolu
  "---------------------------------------------------------------
  IF p_qual = 'X'.
    CLEAR gv_detail.
    PERFORM check_quality_view USING    ps_marc-matnr
                                        ps_marc-werks
                               CHANGING ps_result
                                        gv_detail
                                        pv_has_missing.
    ps_result-qual_detail = gv_detail.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_BASIC_VIEW
*&---------------------------------------------------------------------*
FORM check_basic_view USING    ps_mara  TYPE mara
                      CHANGING ps_result TYPE ty_result
                               pv_missing TYPE string
                               pv_has_missing TYPE abap_bool.

  " Bakim durumu kontrolu: K = Temel veri gorunumu
  IF ps_mara-pstat CS 'K'.
    ps_result-basic_view = icon_led_green.

*    " Temel verilerde eksik alan kontrolu (sari uyarilar devre disi)
*    IF ps_mara-meins IS INITIAL.
*      ps_result-basic_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Temel olcu birimi bos' INTO pv_missing.
*    ENDIF.
*
*    IF ps_mara-matkl IS INITIAL.
*      ps_result-basic_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Malzeme grubu bos' INTO pv_missing.
*    ENDIF.
*
*    IF ps_mara-brgew IS INITIAL OR ps_mara-gewei IS INITIAL.
*      ps_result-basic_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Brut agirlik/birimi bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-basic_view = icon_led_red.
    pv_has_missing = abap_true.
    pv_missing = 'Temel veri gorunumu yok (PSTAT: K eksik)'.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_SALES_VIEW
*&---------------------------------------------------------------------*
FORM check_sales_view USING    pv_matnr TYPE matnr
                      CHANGING ps_result TYPE ty_result
                               pv_missing TYPE string
                               pv_has_missing TYPE abap_bool.

  DATA: ls_mvke TYPE mvke.

  " Bakim durumu kontrolu: V = Satis gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = pv_matnr.

  READ TABLE gt_mvke INTO ls_mvke WITH KEY matnr = pv_matnr.
  IF sy-subrc = 0 AND gs_mara-pstat CS 'V'.
    ps_result-sales_view = icon_led_green.

*    " Satis gorunumunde eksik alan kontrolu (sari uyarilar devre disi)
*    IF ls_mvke-dwerk IS INITIAL.
*      ps_result-sales_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Teslimat uretim yeri bos' INTO pv_missing.
*    ENDIF.
*
*    IF ls_mvke-ktgrm IS INITIAL.
*      ps_result-sales_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Hesap atama grubu bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-sales_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'V'.
      pv_missing = 'Satis gorunumu yok (PSTAT: V eksik)'.
    ELSE.
      pv_missing = 'Satis gorunumu yok (MVKE kaydi yok)'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_PURCHASING_VIEW
*&---------------------------------------------------------------------*
FORM check_purchasing_view USING    ps_marc TYPE marc
                           CHANGING ps_result TYPE ty_result
                                    pv_missing TYPE string
                                    pv_has_missing TYPE abap_bool.

  " Bakim durumu kontrolu: E = Satin alma gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = ps_marc-matnr.

  IF ps_marc-ekgrp IS NOT INITIAL AND gs_mara-pstat CS 'E'.
    ps_result-purch_view = icon_led_green.

*    " Satin alma deger anahtari kontrolu (sari uyarilar devre disi)
*    IF ps_marc-kordb IS INITIAL AND ps_marc-ekgrp IS NOT INITIAL.
*      ps_result-purch_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Satinalma kayit profili bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-purch_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'E'.
      pv_missing = 'Satin alma gorunumu yok (PSTAT: E eksik)'.
    ELSE.
      pv_missing = 'Satin alma grubu bos'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_MRP_VIEW
*&---------------------------------------------------------------------*
FORM check_mrp_view USING    ps_marc TYPE marc
                    CHANGING ps_result TYPE ty_result
                             pv_missing TYPE string
                             pv_has_missing TYPE abap_bool.

  " Bakim durumu kontrolu: D = MRP gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = ps_marc-matnr.

  IF ps_marc-dismm IS NOT INITIAL AND gs_mara-pstat CS 'D'.
    ps_result-mrp_view = icon_led_green.

*    " MRP tipi dolu ama diger alanlar eksik olabilir (sari uyarilar devre disi)
*    IF ps_marc-dispo IS INITIAL.
*      ps_result-mrp_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'MRP denetcisi bos' INTO pv_missing.
*    ENDIF.
*
*    IF ps_marc-beskz IS INITIAL.
*      ps_result-mrp_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Tedarik turu bos' INTO pv_missing.
*    ENDIF.
*
*    IF ps_marc-plifz IS INITIAL.
*      ps_result-mrp_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Planlanan teslimat suresi bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-mrp_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'D'.
      pv_missing = 'MRP gorunumu yok (PSTAT: D eksik)'.
    ELSE.
      pv_missing = 'MRP gorunumu yok (MRP tipi bos)'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_ACCOUNTING_VIEW
*&---------------------------------------------------------------------*
FORM check_accounting_view USING    pv_matnr TYPE matnr
                                    pv_werks TYPE werks_d
                           CHANGING ps_result TYPE ty_result
                                    pv_missing TYPE string
                                    pv_has_missing TYPE abap_bool.

  DATA: ls_mbew TYPE mbew.

  " Bakim durumu kontrolu: B = Muhasebe gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = pv_matnr.

  READ TABLE gt_mbew INTO ls_mbew WITH KEY matnr = pv_matnr
                                           bwkey = pv_werks.
  IF sy-subrc = 0 AND gs_mara-pstat CS 'B'.
    ps_result-acct_view = icon_led_green.

*    " Muhasebe gorunumunde eksik alan kontrolu (sari uyarilar devre disi)
*    IF ls_mbew-vprsv IS INITIAL.
*      ps_result-acct_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Fiyat kontrol gostergesi bos (Muhasebe)' INTO pv_missing.
*    ENDIF.
*
*    IF ls_mbew-bklas IS INITIAL.
*      ps_result-acct_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Degerleme sinifi bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-acct_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'B'.
      pv_missing = 'Muhasebe gorunumu yok (PSTAT: B eksik)'.
    ELSE.
      pv_missing = 'Muhasebe gorunumu yok (MBEW kaydi yok)'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_COSTING_VIEW
*&---------------------------------------------------------------------*
FORM check_costing_view USING    ps_marc TYPE marc
                        CHANGING ps_result TYPE ty_result
                                 pv_missing TYPE string
                                 pv_has_missing TYPE abap_bool.

  " Bakim durumu kontrolu: G = Maliyetlendirme gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = ps_marc-matnr.

  IF gs_mara-pstat CS 'G' AND
     ( ps_marc-losgr IS NOT INITIAL OR ps_marc-prctr IS NOT INITIAL ).
    ps_result-cost_view = icon_led_green.

*    " Maliyetlendirme eksik alan kontrolu (sari uyarilar devre disi)
*    IF ps_marc-prctr IS INITIAL.
*      ps_result-cost_view = icon_led_yellow.
*      pv_has_missing = abap_true.
*      IF pv_missing IS NOT INITIAL.
*        CONCATENATE pv_missing '; ' INTO pv_missing.
*      ENDIF.
*      CONCATENATE pv_missing 'Kar merkezi bos' INTO pv_missing.
*    ENDIF.

  ELSE.
    ps_result-cost_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'G'.
      pv_missing = 'Maliyetlendirme gorunumu yok (PSTAT: G eksik)'.
    ELSE.
      pv_missing = 'Maliyetlendirme gorunumu eksik'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_STORAGE_VIEW
*&---------------------------------------------------------------------*
FORM check_storage_view USING    pv_matnr TYPE matnr
                                 pv_werks TYPE werks_d
                        CHANGING ps_result TYPE ty_result
                                 pv_missing TYPE string
                                 pv_has_missing TYPE abap_bool.

  DATA: ls_mard TYPE mard.

  " Bakim durumu kontrolu: L = Depolama gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = pv_matnr.

  READ TABLE gt_mard INTO ls_mard WITH KEY matnr = pv_matnr
                                           werks = pv_werks.
  IF sy-subrc = 0 AND gs_mara-pstat CS 'L'.
    ps_result-store_view = icon_led_green.
  ELSE.
    ps_result-store_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'L'.
      pv_missing = 'Depolama gorunumu yok (PSTAT: L eksik)'.
    ELSE.
      pv_missing = 'Depolama gorunumu yok (depo yeri tanimli degil)'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_QUALITY_VIEW
*&---------------------------------------------------------------------*
FORM check_quality_view USING    pv_matnr TYPE matnr
                                 pv_werks TYPE werks_d
                        CHANGING ps_result TYPE ty_result
                                 pv_missing TYPE string
                                 pv_has_missing TYPE abap_bool.

  DATA: ls_qmat TYPE qmat.

  " Bakim durumu kontrolu: Q = Kalite yonetimi gorunumu
  READ TABLE gt_mara INTO gs_mara WITH KEY matnr = pv_matnr.

  READ TABLE gt_qmat INTO ls_qmat WITH KEY matnr = pv_matnr
                                           werks = pv_werks.
  IF sy-subrc = 0 AND gs_mara-pstat CS 'Q'.
    ps_result-qual_view = icon_led_green.
  ELSE.
    ps_result-qual_view = icon_led_red.
    pv_has_missing = abap_true.
    IF gs_mara-pstat NS 'Q'.
      pv_missing = 'Kalite yonetimi gorunumu yok (PSTAT: Q eksik)'.
    ELSE.
      pv_missing = 'Kalite yonetimi gorunumu yok (QMAT kaydi yok)'.
    ENDIF.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_ALV
*&---------------------------------------------------------------------*
*& ALV raporunu olusturur ve goruntuler
*&---------------------------------------------------------------------*
FORM display_alv.

  DATA: lx_msg TYPE REF TO cx_salv_msg,
        lx_not TYPE REF TO cx_salv_not_found.

  TRY.
      " ALV nesnesini olustur
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = go_alv
        CHANGING
          t_table      = gt_result ).

      " Standart ALV fonksiyonlarini aktiflestir
      go_functions = go_alv->get_functions( ).
      go_functions->set_all( abap_true ).

      " Gorunum ayarlari
      go_display = go_alv->get_display_settings( ).
      go_display->set_striped_pattern( abap_true ).
      go_display->set_list_header( 'Malzeme Gorunum Kontrol Raporu' ).

      " Layout ayarlari
      go_layout = go_alv->get_layout( ).
      ls_layout-report = sy-repid.
      go_layout->set_key( ls_layout ).
      go_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).

      " Siralama
      go_sorts = go_alv->get_sorts( ).
      TRY.
          go_sorts->add_sort( columnname = 'MATNR' ).
          go_sorts->add_sort( columnname = 'WERKS' ).
        CATCH cx_salv_not_found
              cx_salv_existing
              cx_salv_data_error.
      ENDTRY.

      " Sutun ayarlari
      go_columns = go_alv->get_columns( ).
      go_columns->set_optimize( abap_true ).

      TRY.
          " Malzeme Numarasi
          go_column = go_columns->get_column( 'MATNR' ).
          go_column->set_short_text( 'Malz.No' ).
          go_column->set_medium_text( 'Malzeme No' ).
          go_column->set_long_text( 'Malzeme Numarasi' ).

          " Malzeme Tanimi
          go_column = go_columns->get_column( 'MAKTX' ).
          go_column->set_short_text( 'Malz.Tan' ).
          go_column->set_medium_text( 'Malzeme Tanimi' ).
          go_column->set_long_text( 'Malzeme Tanimi' ).

          " Malzeme Turu
          go_column = go_columns->get_column( 'MTART' ).
          go_column->set_short_text( 'Malz.Tur' ).
          go_column->set_medium_text( 'Malzeme Turu' ).
          go_column->set_long_text( 'Malzeme Turu' ).

          " Mal Grubu
          go_column = go_columns->get_column( 'MATKL' ).
          go_column->set_short_text( 'MalGrb' ).
          go_column->set_medium_text( 'Mal Grubu' ).
          go_column->set_long_text( 'Mal Grubu' ).

          " Yaratan
          go_column = go_columns->get_column( 'ERNAM' ).
          go_column->set_short_text( 'Yaratan' ).
          go_column->set_medium_text( 'Yaratan' ).
          go_column->set_long_text( 'Malzemeyi Yaratan Kullanici' ).

          " Yaratma Tarihi
          go_column = go_columns->get_column( 'ERSDA' ).
          go_column->set_short_text( 'Yrt.Tar' ).
          go_column->set_medium_text( 'Yaratma Tarihi' ).
          go_column->set_long_text( 'Malzeme Yaratma Tarihi' ).

          " Sirket Kodu
          go_column = go_columns->get_column( 'BUKRS' ).
          go_column->set_short_text( 'SirKodu' ).
          go_column->set_medium_text( 'Sirket Kodu' ).
          go_column->set_long_text( 'Sirket Kodu' ).

          " Uretim Yeri
          go_column = go_columns->get_column( 'WERKS' ).
          go_column->set_short_text( 'Urt.Yeri' ).
          go_column->set_medium_text( 'Uretim Yeri' ).
          go_column->set_long_text( 'Uretim Yeri' ).

          " Depo Yeri
          go_column = go_columns->get_column( 'LGORT' ).
          go_column->set_short_text( 'Depo Yr' ).
          go_column->set_medium_text( 'Depo Yeri' ).
          go_column->set_long_text( 'Depo Yeri' ).

          " Gorunum kolonlari - ikon + detay yan yana
          go_column = go_columns->get_column( 'BASIC_VIEW' ).
          go_column->set_short_text( 'Temel' ).
          go_column->set_medium_text( 'Temel Veri' ).
          go_column->set_long_text( 'Temel Veri Gorunumu' ).

          go_column = go_columns->get_column( 'BASIC_DETAIL' ).
          go_column->set_short_text( 'TemelDet' ).
          go_column->set_medium_text( 'Temel Detay' ).
          go_column->set_long_text( 'Temel Veri Eksik Detay' ).

          go_column = go_columns->get_column( 'SALES_VIEW' ).
          go_column->set_short_text( 'Satis' ).
          go_column->set_medium_text( 'Satis Gor.' ).
          go_column->set_long_text( 'Satis Gorunumu' ).

          go_column = go_columns->get_column( 'SALES_DETAIL' ).
          go_column->set_short_text( 'SatisDet' ).
          go_column->set_medium_text( 'Satis Detay' ).
          go_column->set_long_text( 'Satis Eksik Detay' ).

          go_column = go_columns->get_column( 'PURCH_VIEW' ).
          go_column->set_short_text( 'SatAlma' ).
          go_column->set_medium_text( 'Satin Alma' ).
          go_column->set_long_text( 'Satin Alma Gorunumu' ).

          go_column = go_columns->get_column( 'PURCH_DETAIL' ).
          go_column->set_short_text( 'SAlmDet' ).
          go_column->set_medium_text( 'SatAlma Detay' ).
          go_column->set_long_text( 'Satin Alma Eksik Detay' ).

          go_column = go_columns->get_column( 'MRP_VIEW' ).
          go_column->set_short_text( 'MRP' ).
          go_column->set_medium_text( 'MRP Gor.' ).
          go_column->set_long_text( 'MRP Gorunumu' ).

          go_column = go_columns->get_column( 'MRP_DETAIL' ).
          go_column->set_short_text( 'MRPDet' ).
          go_column->set_medium_text( 'MRP Detay' ).
          go_column->set_long_text( 'MRP Eksik Detay' ).

          go_column = go_columns->get_column( 'ACCT_VIEW' ).
          go_column->set_short_text( 'Muhasebe' ).
          go_column->set_medium_text( 'Muhasebe Gor.' ).
          go_column->set_long_text( 'Muhasebe Gorunumu' ).

          go_column = go_columns->get_column( 'ACCT_DETAIL' ).
          go_column->set_short_text( 'MuhDet' ).
          go_column->set_medium_text( 'Muhasebe Detay' ).
          go_column->set_long_text( 'Muhasebe Eksik Detay' ).

          go_column = go_columns->get_column( 'COST_VIEW' ).
          go_column->set_short_text( 'Maliyet' ).
          go_column->set_medium_text( 'Maliyetlendirme' ).
          go_column->set_long_text( 'Maliyetlendirme Gorunumu' ).

          go_column = go_columns->get_column( 'COST_DETAIL' ).
          go_column->set_short_text( 'MalDet' ).
          go_column->set_medium_text( 'Maliyet Detay' ).
          go_column->set_long_text( 'Maliyetlendirme Eksik Detay' ).

          go_column = go_columns->get_column( 'STORE_VIEW' ).
          go_column->set_short_text( 'Depolama' ).
          go_column->set_medium_text( 'Depolama Gor.' ).
          go_column->set_long_text( 'Depolama Gorunumu' ).

          go_column = go_columns->get_column( 'STORE_DETAIL' ).
          go_column->set_short_text( 'DepoDet' ).
          go_column->set_medium_text( 'Depolama Detay' ).
          go_column->set_long_text( 'Depolama Eksik Detay' ).

          go_column = go_columns->get_column( 'QUAL_VIEW' ).
          go_column->set_short_text( 'Kalite' ).
          go_column->set_medium_text( 'Kalite Yon.' ).
          go_column->set_long_text( 'Kalite Yonetimi Gorunumu' ).

          go_column = go_columns->get_column( 'QUAL_DETAIL' ).
          go_column->set_short_text( 'KalDet' ).
          go_column->set_medium_text( 'Kalite Detay' ).
          go_column->set_long_text( 'Kalite Yonetimi Eksik Detay' ).

          " Durum
          go_column = go_columns->get_column( 'STATUS' ).
          go_column->set_short_text( 'Durum' ).
          go_column->set_medium_text( 'Genel Durum' ).
          go_column->set_long_text( 'Genel Durum' ).

          " Durum Aciklamasi
          go_column = go_columns->get_column( 'STATUS_TEXT' ).
          go_column->set_short_text( 'DurumAck' ).
          go_column->set_medium_text( 'Durum Aciklama' ).
          go_column->set_long_text( 'Durum Aciklamasi' ).

          " Siniflandirma gorunumunu gizle (ayri kontrol yok)
          go_column = go_columns->get_column( 'CLASS_VIEW' ).
          go_column->set_visible( abap_false ).

        CATCH cx_salv_not_found INTO lx_not.
          " Sutun bulunamazsa devam et
      ENDTRY.

      " ALV'yi goruntle
      go_alv->display( ).

    CATCH cx_salv_msg INTO lx_msg.
      MESSAGE lx_msg TYPE 'E'.
  ENDTRY.

ENDFORM.
