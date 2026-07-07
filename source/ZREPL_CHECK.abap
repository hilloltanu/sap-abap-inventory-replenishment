REPORT zrepl_check.

START-OF-SELECTION.
  DATA(lo_handler) = NEW zcl_repl_handler( ).
  lo_handler->check_replenishment( ).
