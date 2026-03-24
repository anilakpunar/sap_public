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
         ersda        TYPE ersda,          " Yaratma tarihi
         werks        TYPE werks_d,        " Tesis
         lgort        TYPE lgort_d,        " Depo yeri
         " Gorunum durumu
         basic_view   TYPE icon_d,         " Temel veri gorunumu
         class_view   TYPE icon_d,         " Siniflandirma gorunumu
         sales_view   TYPE icon_d,         " Satis gorunumu
         purch_view   TYPE icon_d,         " Satin alma gorunumu
         mrp_view     TYPE icon_d,         " MRP gorunumu
         acct_view    TYPE icon_d,         " Muhasebe gorunumu
         cost_view    TYPE icon_d,         " Maliyetlendirme gorunumu
         store_view   TYPE icon_d,         " Depolama gorunumu
         qual_view    TYPE icon_d,         " Kalite yonetimi gorunumu
         " Eksik veri kontrolleri
         missing_info TYPE string,         " Eksik bilgi aciklamasi
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
      gs_qmat    TYPE qmat.

* ALV degiskenleri
DATA: go_alv       TYPE REF TO cl_salv_table,
      go_columns   TYPE REF TO cl_salv_columns_table,
      go_column    TYPE REF TO cl_salv_column,
      go_functions TYPE REF TO cl_salv_functions_list,
      go_display   TYPE REF TO cl_salv_display_settings,
      go_sorts     TYPE REF TO cl_salv_sorts,
      go_layout    TYPE REF TO cl_salv_layout,
      ls_layout    TYPE salv_s_layout_key.

DATA: gv_missing TYPE string.

*----------------------------------------------------------------------*
* Secim Ekrani
*----------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS: s_matnr FOR gs_mara-matnr,          " Malzeme no
                  s_mtart FOR gs_mara-mtart,           " Malzeme turu
                  s_ersda FOR gs_mara-ersda,           " Yaratma tarihi
                  s_werks FOR gs_marc-werks.            " Tesis
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

  " Tesis verileri (MARC)
  SELECT * FROM marc
    INTO TABLE gt_marc
    FOR ALL ENTRIES IN gt_mara
    WHERE matnr = gt_mara-matnr
      AND werks IN s_werks.

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

  DATA: lv_has_missing TYPE abap_bool.

  LOOP AT gt_marc INTO gs_marc.

    CLEAR: gs_result, gv_missing, lv_has_missing.

    gs_result-matnr = gs_marc-matnr.
    gs_result-werks = gs_marc-werks.

    " Malzeme temel bilgilerini al
    READ TABLE gt_mara INTO gs_mara WITH KEY matnr = gs_marc-matnr.
    IF sy-subrc = 0.
      gs_result-mtart = gs_mara-mtart.
      gs_result-ersda = gs_mara-ersda.
    ENDIF.

    " Malzeme tanimini al
    READ TABLE gt_makt INTO gs_makt WITH KEY matnr = gs_marc-matnr.
    IF sy-subrc = 0.
      gs_result-maktx = gs_makt-maktx.
    ENDIF.

    " Depo yeri bilgisini al
    READ TABLE gt_mard INTO gs_mard WITH KEY matnr = gs_marc-matnr
                                              werks = gs_marc-werks.
    IF sy-subrc = 0.
      gs_result-lgort = gs_mard-lgort.
    ENDIF.

    "---------------------------------------------------------------
    " 1. Temel Veri Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_basic = 'X'.
      PERFORM check_basic_view USING    gs_mara
                               CHANGING gs_result
                                        gv_missing
                                        lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 2. Satis Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_sales = 'X'.
      PERFORM check_sales_view USING    gs_marc-matnr
                               CHANGING gs_result
                                        gv_missing
                                        lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 3. Satin Alma Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_purch = 'X'.
      PERFORM check_purchasing_view USING    gs_marc
                                    CHANGING gs_result
                                             gv_missing
                                             lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 4. MRP Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_mrp = 'X'.
      PERFORM check_mrp_view USING    gs_marc
                             CHANGING gs_result
                                      gv_missing
                                      lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 5. Muhasebe Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_acct = 'X'.
      PERFORM check_accounting_view USING    gs_marc-matnr
                                             gs_marc-werks
                                    CHANGING gs_result
                                             gv_missing
                                             lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 6. Maliyetlendirme Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_cost = 'X'.
      PERFORM check_costing_view USING    gs_marc
                                 CHANGING gs_result
                                          gv_missing
                                          lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 7. Depolama Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_store = 'X'.
      PERFORM check_storage_view USING    gs_marc-matnr
                                          gs_marc-werks
                                 CHANGING gs_result
                                          gv_missing
                                          lv_has_missing.
    ENDIF.

    "---------------------------------------------------------------
    " 8. Kalite Yonetimi Gorunumu Kontrolu
    "---------------------------------------------------------------
    IF p_qual = 'X'.
      PERFORM check_quality_view USING    gs_marc-matnr
                                          gs_marc-werks
                                 CHANGING gs_result
                                          gv_missing
                                          lv_has_missing.
    ENDIF.

    " Eksik bilgi aciklamasini ata
    gs_result-missing_info = gv_missing.

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

  ENDLOOP.

  IF gt_result IS INITIAL.
    MESSAGE s001(00) WITH 'Gosterilecek veri bulunamadi.'
      DISPLAY LIKE 'W'.
    LEAVE LIST-PROCESSING.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_BASIC_VIEW
*&---------------------------------------------------------------------*
FORM check_basic_view USING    ps_mara  TYPE mara
                      CHANGING ps_result TYPE ty_result
                               pv_missing TYPE string
                               pv_has_missing TYPE abap_bool.

  IF ps_mara-matnr IS NOT INITIAL.
    " Temel veri gorunumu var
    ps_result-basic_view = icon_led_green.

    " Temel verilerde eksik alan kontrolu
    IF ps_mara-meins IS INITIAL.
      ps_result-basic_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Temel olcu birimi bos' INTO pv_missing.
    ENDIF.

    IF ps_mara-matkl IS INITIAL.
      ps_result-basic_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Malzeme grubu bos' INTO pv_missing.
    ENDIF.

    IF ps_mara-brgew IS INITIAL OR ps_mara-gewei IS INITIAL.
      ps_result-basic_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Brut agirlik/birimi bos' INTO pv_missing.
    ENDIF.

  ELSE.
    ps_result-basic_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Temel veri gorunumu yok' INTO pv_missing.
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

  READ TABLE gt_mvke INTO ls_mvke WITH KEY matnr = pv_matnr.
  IF sy-subrc = 0.
    ps_result-sales_view = icon_led_green.

    " Satis gorunumunde eksik alan kontrolu
    IF ls_mvke-dwerk IS INITIAL.
      ps_result-sales_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Teslimat tesisi bos' INTO pv_missing.
    ENDIF.

    IF ls_mvke-ktgrm IS INITIAL.
      ps_result-sales_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Hesap atama grubu bos' INTO pv_missing.
    ENDIF.

  ELSE.
    ps_result-sales_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Satis gorunumu yok' INTO pv_missing.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_PURCHASING_VIEW
*&---------------------------------------------------------------------*
FORM check_purchasing_view USING    ps_marc TYPE marc
                           CHANGING ps_result TYPE ty_result
                                    pv_missing TYPE string
                                    pv_has_missing TYPE abap_bool.

  IF ps_marc-ekgrp IS NOT INITIAL.
    ps_result-purch_view = icon_led_green.
  ELSE.
    " Satin alma grubu bos ise gorunum eksik kabul edilir
    ps_result-purch_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Satin alma grubu bos' INTO pv_missing.
  ENDIF.

  " Satin alma deger anahtari kontrolu (KORREME - satinalma kayit profili)
  IF ps_marc-kordb IS INITIAL AND ps_marc-ekgrp IS NOT INITIAL.
    ps_result-purch_view = icon_led_yellow.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Satinalma kayit profili bos' INTO pv_missing.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_MRP_VIEW
*&---------------------------------------------------------------------*
FORM check_mrp_view USING    ps_marc TYPE marc
                    CHANGING ps_result TYPE ty_result
                             pv_missing TYPE string
                             pv_has_missing TYPE abap_bool.

  IF ps_marc-dismm IS NOT INITIAL.
    ps_result-mrp_view = icon_led_green.

    " MRP tipi dolu ama diger alanlar eksik olabilir
    IF ps_marc-dispo IS INITIAL.
      ps_result-mrp_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'MRP denetcisi bos' INTO pv_missing.
    ENDIF.

    IF ps_marc-beskz IS INITIAL.
      ps_result-mrp_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Tedarik turu bos' INTO pv_missing.
    ENDIF.

    IF ps_marc-plifz IS INITIAL.
      ps_result-mrp_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Planlanan teslimat suresi bos' INTO pv_missing.
    ENDIF.

  ELSE.
    ps_result-mrp_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'MRP gorunumu yok (MRP tipi bos)' INTO pv_missing.
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

  READ TABLE gt_mbew INTO ls_mbew WITH KEY matnr = pv_matnr
                                           bwkey = pv_werks.
  IF sy-subrc = 0.
    ps_result-acct_view = icon_led_green.

    " Muhasebe gorunumunde eksik alan kontrolu
    IF ls_mbew-vprsv IS INITIAL.
      ps_result-acct_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Fiyat kontrol gostergesi bos (Muhasebe)' INTO pv_missing.
    ENDIF.

    IF ls_mbew-bklas IS INITIAL.
      ps_result-acct_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Degerleme sinifi bos' INTO pv_missing.
    ENDIF.

  ELSE.
    ps_result-acct_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Muhasebe gorunumu yok' INTO pv_missing.
  ENDIF.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form CHECK_COSTING_VIEW
*&---------------------------------------------------------------------*
FORM check_costing_view USING    ps_marc TYPE marc
                        CHANGING ps_result TYPE ty_result
                                 pv_missing TYPE string
                                 pv_has_missing TYPE abap_bool.

  " Maliyetlendirme gorunumu MARC uzerinden kontrol
  IF ps_marc-losgr IS NOT INITIAL OR ps_marc-prctr IS NOT INITIAL.
    ps_result-cost_view = icon_led_green.

    IF ps_marc-prctr IS INITIAL.
      ps_result-cost_view = icon_led_yellow.
      pv_has_missing = abap_true.
      IF pv_missing IS NOT INITIAL.
        CONCATENATE pv_missing '; ' INTO pv_missing.
      ENDIF.
      CONCATENATE pv_missing 'Kar merkezi bos' INTO pv_missing.
    ENDIF.

  ELSE.
    ps_result-cost_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Maliyetlendirme gorunumu eksik' INTO pv_missing.
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

  READ TABLE gt_mard INTO ls_mard WITH KEY matnr = pv_matnr
                                           werks = pv_werks.
  IF sy-subrc = 0.
    ps_result-store_view = icon_led_green.
  ELSE.
    ps_result-store_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Depolama gorunumu yok (depo yeri tanimli degil)' INTO pv_missing.
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

  READ TABLE gt_qmat INTO ls_qmat WITH KEY matnr = pv_matnr
                                           werks = pv_werks.
  IF sy-subrc = 0.
    ps_result-qual_view = icon_led_green.
  ELSE.
    ps_result-qual_view = icon_led_red.
    pv_has_missing = abap_true.
    IF pv_missing IS NOT INITIAL.
      CONCATENATE pv_missing '; ' INTO pv_missing.
    ENDIF.
    CONCATENATE pv_missing 'Kalite yonetimi gorunumu yok' INTO pv_missing.
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

          " Yaratma Tarihi
          go_column = go_columns->get_column( 'ERSDA' ).
          go_column->set_short_text( 'Yrt.Tar' ).
          go_column->set_medium_text( 'Yaratma Tarihi' ).
          go_column->set_long_text( 'Malzeme Yaratma Tarihi' ).

          " Tesis
          go_column = go_columns->get_column( 'WERKS' ).
          go_column->set_short_text( 'Tesis' ).
          go_column->set_medium_text( 'Tesis' ).
          go_column->set_long_text( 'Tesis' ).

          " Depo Yeri
          go_column = go_columns->get_column( 'LGORT' ).
          go_column->set_short_text( 'Depo Yr' ).
          go_column->set_medium_text( 'Depo Yeri' ).
          go_column->set_long_text( 'Depo Yeri' ).

          " Gorunum kolonlari
          go_column = go_columns->get_column( 'BASIC_VIEW' ).
          go_column->set_short_text( 'Temel' ).
          go_column->set_medium_text( 'Temel Veri' ).
          go_column->set_long_text( 'Temel Veri Gorunumu' ).

          go_column = go_columns->get_column( 'SALES_VIEW' ).
          go_column->set_short_text( 'Satis' ).
          go_column->set_medium_text( 'Satis Gor.' ).
          go_column->set_long_text( 'Satis Gorunumu' ).

          go_column = go_columns->get_column( 'PURCH_VIEW' ).
          go_column->set_short_text( 'SatAlma' ).
          go_column->set_medium_text( 'Satin Alma' ).
          go_column->set_long_text( 'Satin Alma Gorunumu' ).

          go_column = go_columns->get_column( 'MRP_VIEW' ).
          go_column->set_short_text( 'MRP' ).
          go_column->set_medium_text( 'MRP Gor.' ).
          go_column->set_long_text( 'MRP Gorunumu' ).

          go_column = go_columns->get_column( 'ACCT_VIEW' ).
          go_column->set_short_text( 'Muhasebe' ).
          go_column->set_medium_text( 'Muhasebe Gor.' ).
          go_column->set_long_text( 'Muhasebe Gorunumu' ).

          go_column = go_columns->get_column( 'COST_VIEW' ).
          go_column->set_short_text( 'Maliyet' ).
          go_column->set_medium_text( 'Maliyetlendirme' ).
          go_column->set_long_text( 'Maliyetlendirme Gorunumu' ).

          go_column = go_columns->get_column( 'STORE_VIEW' ).
          go_column->set_short_text( 'Depolama' ).
          go_column->set_medium_text( 'Depolama Gor.' ).
          go_column->set_long_text( 'Depolama Gorunumu' ).

          go_column = go_columns->get_column( 'QUAL_VIEW' ).
          go_column->set_short_text( 'Kalite' ).
          go_column->set_medium_text( 'Kalite Yon.' ).
          go_column->set_long_text( 'Kalite Yonetimi Gorunumu' ).

          " Eksik Bilgi
          go_column = go_columns->get_column( 'MISSING_INFO' ).
          go_column->set_short_text( 'Eksikler' ).
          go_column->set_medium_text( 'Eksik Bilgiler' ).
          go_column->set_long_text( 'Eksik Bilgi Detaylari' ).

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
