*&---------------------------------------------------------------------*
*& Report Z_INV_REPLENISH001
*&---------------------------------------------------------------------*
*& Author: Hillol
*& Date  : 07/07/2026
*& Purpose: Inventory Replenishment System - Stock level Monitoring 
*&---------------------------------------------------------------------*
REPORT Z_INV_REPLENISH001.

TABLES: ZMAT_STOCK.

*********Type Definitions******************

TYPES: BEGIN OF ty_stock,
        matnr TYPE zmat_stock-matnr,
        werks TYPE zmat_stock-werks,
        lgort TYPE zmat_stock-lgort,
        labst TYPE zmat_stock-labst,
        insme TYPE zmat_stock-insme,
        einme TYPE zmat_stock-einme,
        speme TYPE zmat_stock-speme,
        meins TYPE zmat_stock-meins,
        minbe TYPE zmat_stock-minbe,
        bstrf TYPE zmat_stock-bstrf,
        mmsta TYPE zmat_stock-mmsta,
        dlinl TYPE zmat_stock-dlinl,
        ersda TYPE zmat_stock-ersda,
        ernam TYPE zmat_stock-ernam,
        laeda TYPE zmat_stock-laeda,
        color TYPE c LENGTH 4,
       END OF ty_stock.


DATA: lt_stock TYPE STANDARD TABLE OF ty_stock,
      ls_stock TYPE ty_stock,
      lt_repl TYPE TABLE OF ty_stock,
      lt_crit TYPE TABLE OF ty_stock.

DATA: l_msg TYPE String,
      lv_title TYPE lvc_title..

*********** Selection Screen *******************
SELECTION-SCREEN : BEGIN OF BLOCK B1 WITH FRAME TITLE TEXT-001.
  SELECT-OPTIONS : s_matnr FOR zmat_stock-matnr,
                   s_werks FOR zmat_stock-werks,
                   s_lgort FOR zmat_stock-lgort.
  PARAMETERS:      p_mode TYPE c DEFAULT 'A'.
SELECTION-SCREEN : END OF BLOCK B1.

SELECTION-SCREEN : BEGIN OF BLOCK B2 WITH FRAME TITLE TEXT-002.
  PARAMETERS:       p_email TYPE ad_smtpadr,
                    p_alert AS CHECKBOX DEFAULT 'X',
                    p_print AS CHECKBOX DEFAULT ' '.
SELECTION-SCREEN : END OF BLOCK B2.

************* Main Processing ******************

START-OF-SELECTION.

SELECT * FROM zmat_stock
  INTO CORRESPONDING FIELDS OF TABLE lt_stock
  WHERE werks IN s_werks
    AND matnr IN s_matnr
    ORDER BY werks matnr lgort.


LOOP AT lt_stock INTO ls_stock.
  DATA(lv_pct) = ( ls_stock-labst / ls_stock-minbe ) * 100.

  IF lv_pct < 20.
    ls_stock-mmsta = 'C'.
  ELSEIF ls_stock-labst < ls_stock-minbe.
    ls_stock-mmsta = 'R'.
  ELSE.
    ls_stock-mmsta = '0'.
  ENDIF.

  ls_stock-laeda = sy-datum.

  UPDATE zmat_stock
    SET mmsta = ls_stock-mmsta
        laeda = ls_stock-laeda
    WHERE matnr = ls_stock-matnr
      AND werks = ls_stock-werks
      AND lgort = ls_stock-lgort.

  MODIFY lt_stock FROM ls_stock.

ENDLOOP.

COMMIT WORK.

PERFORM Display_alv USING lt_stock.

IF p_alert eq abap_true AND p_email IS NOT INITIAL
  AND lt_repl IS NOT INITIAL.

  PERFORM send_alert_email.
ENDIF.

PERFORM write_application_log.
*&---------------------------------------------------------------------*
*&      Form  DISPLAY_ALV
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LT_STOCK  text
*----------------------------------------------------------------------*
FORM DISPLAY_ALV  USING P_LT_STOCK.

  DATA: lo_alv      TYPE REF TO CL_SALV_TABLE,
        lo_cols     TYPE REF TO CL_SALV_COLUMNS_TABLE,
        lo_col      TYPE REF TO CL_SALV_COLUMN_TABLE,
        lo_display  TYPE REF TO CL_SALV_DISPLAY_SETTINGS,
        lo_funcs    TYPE REF TO CL_SALV_FUNCTIONS_LIST.

  TRY.
    cl_salv_table=>factory(
      IMPORTING  r_salv_table = lo_alv
        CHANGING t_table      = p_lt_stock ).

    lo_funcs = lo_alv->get_functions( ).
    lo_funcs->set_all( abap_true ).

    lo_cols = lo_alv->get_columns( ).
    lo_cols->set_optimize( abap_true ).
    lo_cols->set_color_column( 'COLOR' ).

    lo_col ?= lo_cols->get_column( 'MATNR' ).
    lo_col->set_long_text( 'Material Number' ).

    lo_col ?= lo_cols->get_column( 'WERKS' ).
    lo_col->set_long_text( 'Plant' ).

    lo_col ?= lo_cols->get_column( 'LGORT' ).
    lo_col->set_long_text( 'Storage Location' ).

    lo_col ?= lo_cols->get_column( 'LABST' ).
    lo_col->set_long_text( 'Current Unrestricted Stock' ).

    lo_col ?= lo_cols->get_column( 'INSME' ).
    lo_col->set_long_text( 'Stock in QI' ).

    lo_col ?= lo_cols->get_column( 'BSTRF' ).
    lo_col->set_long_text( 'Replenishment Qty' ).

    lo_col ?= lo_cols->get_column( 'MEINS' ).
    lo_col->set_long_text( 'UOM' ).

    lo_col ?= lo_cols->get_column( 'MMSTA' ).
    lo_col->set_long_text( 'Plant-Specific Status' ).

    lo_col ?= lo_cols->get_column( 'DLINL' ).
    lo_col->set_long_text( 'Last Inventory Date' ).

    lo_col ?= lo_cols->get_column( 'MATNR' ).
    lo_col->set_long_text( 'Material Number' ).

    lo_col ?= lo_cols->get_column( 'COLOR' ).
    lo_col->set_visible( abap_false ).

    lo_display = lo_alv->get_display_settings( ).
    lv_title = 'Inventory Replenishment Dashboard'.

    lo_display->set_list_header( lv_title ).


  CATCH CX_ROOT INTO DATA(lx_data).
    l_msg = lx_data->get_text( ).
    MESSAGE e398(00) WITH 'Error Retrieved :' l_msg.
  ENDTRY.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  SEND_ALERT_EMAIL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM SEND_ALERT_EMAIL .

  DATA: lo_req TYPE REF TO cl_bcs,
        lo_doc TYPE REF TO cl_document_bcs,
        lo_rcpt TYPE REF TO if_recipient_bcs,
        lt_body TYPE bcsy_text,
        ls_line TYPE soli,
        lv_count_r TYPE i,
        lv_count_c TYPE i,
        lv_pct     TYPE p DECIMALS 2,
        lv_text    TYPE char50.

  DESCRIBE TABLE lt_repl LINES lv_count_r.
  DESCRIBE TABLE lt_crit LINES lv_count_c.

  ls_line-line = '==========================================================='.
  APPEND ls_line TO lt_body.

  ls_line-line = '==========================================================='.
  APPEND ls_line TO lt_body.

  ls_line-line = '==========================================================='.
  APPEND ls_line TO lt_body.

  ls_line-line = ' '.
  APPEND ls_line TO lt_body.

*  APPEND INITIAL LINE TO lt_body ASSIGNING FIELD-VALUE(ls_line).
  IF lt_crit IS NOT INITIAL.
    LOOP AT lt_crit INTO ls_stock.
      IF ls_stock-minbe > 0.
        lv_pct = ( ls_stock-labst / ls_stock-minbe ) * 100.
      ELSE.
        lv_pct = 0.
      ENDIF.

      WRITE ls_stock-labst TO lv_text LEFT-JUSTIFIED.
      ls_line-line = 'Material: ' && ls_stock-matnr &&
                     ' | Stock: ' && lv_text &&
                     ' | Status: C'.
      APPEND ls_line TO lt_body.
    ENDLOOP.
  ELSE.
    ls_line-line = 'No critical items.'.
    APPEND ls_line TO lt_body.
  ENDIF.

  ls_line-line = ' '.
  APPEND ls_line TO lt_body.

  ls_line-line = '- REPLENISHMENT REQUIRED -'.
  APPEND ls_line-line TO lt_body.


  IF lt_repl IS NOT INITIAL.
    LOOP AT lt_repl INTO ls_stock.
      WRITE ls_stock-labst TO lv_text LEFT-JUSTIFIED.
      ls_line-line = 'Material: ' && ls_stock-matnr &&
                     ' | Plant: ' && ls_stock-werks &&
                     ' | Stock: ' && lv_text.
      APPEND ls_line TO lt_body.
    ENDLOOP.
  ELSE.
    ls_line-line = 'No replenishment Required.'.
    APPEND ls_line TO lt_body.
  ENDIF.

  TRY.
    lo_req = cl_bcs=>create_persistent( ).

    lo_doc = cl_document_bcs=>create_document(
      i_type    =  'RAW'
      i_text    =  lt_body
      i_subject =  'ALERT: Inventory Replenishment' ).

    lo_req->set_document( lo_doc ).
    lo_rcpt = cl_cam_address_bcs=>create_internet_address( p_email ).
    lo_req->add_recipient( lo_rcpt ).
    lo_req->send( ).
    COMMIT WORK.

    MESSAGE 'Email alert sent successfully' TYPE 'S'.

  CATCH CX_BCS INTO DATA(lx_bcs).
    MESSAGE 'Email sending failed' TYPE 'W'.
  ENDTRY.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  WRITE_APPLICATION_LOG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
FORM WRITE_APPLICATION_LOG .

  DATA: lv_handle     TYPE balloghndl,
        lt_log_handle TYPE bal_t_logh,
        ls_msg        TYPE bal_s_msg,
        lv_msg_count  TYPE i.

  "Create application log header
  CALL FUNCTION 'BAL_LOG_CREATE'
    EXPORTING
      I_S_LOG                       = VALUE bal_s_log(
                                        object    = 'ZREPL'
                                        subobject = 'STOCK_CHK'
                                        extnumber = sy-datum
                                        aluser    = sy-uname )
   IMPORTING
     E_LOG_HANDLE                  = lv_handle
   EXCEPTIONS
     LOG_HEADER_INCONSISTENT       = 1
     OTHERS                        = 2
            .
  IF SY-SUBRC <> 0.
* Implement suitable error handling here
    MESSAGE 'Application log creation failed' TYPE 'W'.
    RETURN.
  ENDIF.

  APPEND lv_handle TO lt_log_handle.

  LOOP AT lt_crit INTO ls_stock.
    ls_msg-msgty = 'E'.
    ls_msg-msgid = 'Z_REPL'.
    ls_msg-msgno = '001'.
    ls_msg-msgv1 = ls_stock-matnr.
    ls_msg-msgv2 = ls_stock-werks.
    ls_msg-msgv3 = ls_stock-lgort.
    ls_msg-msgv4 = 'CRITICAL'.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        I_LOG_HANDLE              = lv_handle
        I_S_MSG                   = ls_msg.
  ENDLOOP.

  "Log Replenishment items
   LOOP AT lt_repl INTO ls_stock.
    ls_msg-msgty = 'W'.
    ls_msg-msgid = 'Z_REPL'.
    ls_msg-msgno = '001'.
    ls_msg-msgv1 = ls_stock-matnr.
    ls_msg-msgv2 = ls_stock-werks.
    ls_msg-msgv3 = ls_stock-lgort.
    ls_msg-msgv4 = 'REPLENISH'.

    CALL FUNCTION 'BAL_LOG_MSG_ADD'
      EXPORTING
        I_LOG_HANDLE              = lv_handle
        I_S_MSG                   = ls_msg.
   ENDLOOP.

   CALL FUNCTION 'BAL_DB_SAVE'
    EXPORTING
      I_CLIENT                   = sy-mandt
      I_T_LOG_HANDLE             = lt_log_handle

    EXCEPTIONS
      LOG_NOT_FOUND              = 1
      SAVE_NOT_ALLOWED           = 2
      NUMBERING_ERROR            = 3
      OTHERS                     = 4
             .

    IF sy-subrc = 0.
      MESSAGE 'Application log saved to SLG1' TYPE 'S'.
    ELSE.
      MESSAGE 'Application log save failed'   TYPE 'W'.
    ENDIF.

ENDFORM.
