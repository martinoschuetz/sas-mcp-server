libname winedemo "/opt/data/wine";

DATA winedemo.wineDemand;
    LENGTH
        PRODUCT_ID       $ 20
        STORE_LOCATION_ID $ 14
        Reseller_ID      $ 24
        Demand_QTY         8
        IND1               8
        IND2               8
        IND3               8
        IND4               8
        IND5               8
        IND6               8
        IND7               8
        IND8               8
        IND9               8
        IND10              8
        IND11              8
        IND12              8
        IND13              8
        IND14              8
        IND15              8
        date_str           8 ;
    FORMAT
        PRODUCT_ID       $CHAR20.
        STORE_LOCATION_ID $CHAR14.
        Reseller_ID      $CHAR24.
        Demand_QTY       BEST4.
        IND1             BEST2.
        IND2             BEST3.
        IND3             BEST4.
        IND4             BEST3.
        IND5             BEST5.
        IND6             BEST3.
        IND7             BEST3.
        IND8             BEST5.
        IND9             BEST4.
        IND10            BEST3.
        IND11            BEST3.
        IND12            BEST3.
        IND13            BEST3.
        IND14            BEST3.
        IND15            BEST3.
        date_str         DATE9. ;
    INFORMAT
        PRODUCT_ID       $CHAR20.
        STORE_LOCATION_ID $CHAR14.
        Reseller_ID      $CHAR24.
        Demand_QTY       BEST4.
        IND1             BEST2.
        IND2             BEST3.
        IND3             BEST4.
        IND4             BEST3.
        IND5             BEST5.
        IND6             BEST3.
        IND7             BEST3.
        IND8             BEST5.
        IND9             BEST4.
        IND10            BEST3.
        IND11            BEST3.
        IND12            BEST3.
        IND13            BEST3.
        IND14            BEST3.
        IND15            BEST3.
        date_str         DATE9. ;
    INFILE '/opt/data/raw/wineDemand.csv'
        LRECL=128
        ENCODING="UTF-8"
        TERMSTR=CRLF
        DLM=','
        MISSOVER
        DSD
        firstobs=2;
    INPUT
        PRODUCT_ID       : $CHAR20.
        STORE_LOCATION_ID : $CHAR14.
        Reseller_ID      : $CHAR24.
        Demand_QTY       : ?? BEST4.
        IND1             : ?? BEST2.
        IND2             : ?? BEST3.
        IND3             : ?? BEST4.
        IND4             : ?? BEST3.
        IND5             : ?? BEST5.
        IND6             : ?? BEST3.
        IND7             : ?? BEST3.
        IND8             : ?? BEST5.
        IND9             : ?? BEST4.
        IND10            : ?? BEST3.
        IND11            : ?? BEST3.
        IND12            : ?? BEST3.
        IND13            : ?? BEST3.
        IND14            : ?? BEST3.
        IND15            : ?? BEST3.
        date_str         : ?? DATE9. ;
RUN;
