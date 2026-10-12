/* =====================================================================
   create_cas_target_table.sas
   Pre-create a global CAS table whose column types match the ESP window
   that the dfesp_cas_adapter subscribes to.
   Rule: ESP int64 -> BIGINT, double -> DOUBLE, string -> VARCHAR.
   The int64 -> BIGINT mapping is VERIFIED (DOUBLE caused subscriber failure).
   The stamp mapping is NOT verified: inspect the table that the adapter
   creates (proc cas; table.columnInfo) and adjust.
   ===================================================================== */
cas mysess;
caslib _all_ assign;

proc casutil;
  droptable casdata="BMC_RAW" incaslib="PUBLIC" quiet;
quit;

proc fedsql sessref=mysess;
  create table casuser.BMC_RAW (
      id                        bigint,
      kafka_topic               varchar(256),
      ce_id                     varchar(64),
      ce_source                 varchar(256),
      ce_type                   varchar(256),
      origin                    varchar(256),
      isa95                     varchar(256),
      gxp                       varchar(16),
      isdc                      varchar(16),
      dataschema                varchar(256),
      ce_time                   double,   /* stamp: verify type */
      ce_timeEventReceived      double,   /* stamp: verify type */
      ce_timeEdgeBrokerReceived double,   /* stamp: verify type */
      tag_name                  varchar(128),
      tag_value                 double,
      tag_uom                   varchar(32),
      tag_quality               varchar(16),
      tag_origin                varchar(128)
  );
quit;

/* Promote to global scope so the ESP adapter session can see it */
proc casutil;
  promote casdata="BMC_RAW" incaslib="casuser" outcaslib="PUBLIC" casout="BMC_RAW";
quit;

proc cas;
  table.columnInfo / table={caslib="PUBLIC", name="BMC_RAW"};
quit;
