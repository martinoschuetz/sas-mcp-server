# CAS Adapter (`dfesp_cas_adapter`, ESP Subscriber → CAS Table)

Source: `docs/espca.txt` (CAS adapter, ~L1750–1900) and a live deployment that writes into `PUBLIC.BMC_RAW`.

## 1. Working configuration [VERIFIED]

Put the adapter on a window with `pubsub="true"`. Usually that's a pass-through `window-copy` so the adapter is isolated from compute windows.

```xml
<window-copy name="w_to_cas" pubsub="true" index="pi_EMPTY">
  <connectors>
    <connector class="adapter" name="cas_sub">
      <properties>
        <property name="type"><![CDATA[sub]]></property>
        <property name="command"><![CDATA[dfesp_cas_adapter -C type=sub,cashostport=@SAS_CAS_SERVER_DEFAULT_CLIENT_SERVICE_HOST@:@SAS_CAS_SERVER_DEFAULT_CLIENT_SERVICE_PORT@,casusername=@CAS_USER@,caspassword=@CAS_PASS@,caslib=PUBLIC,castable=MY_TABLE,commitblocks=10,loglevel=info]]></property>
        <property name="url"><![CDATA[dfESP://localhost:31416/<Project>/<ContQuery>/w_to_cas?snapshot=false]]></property>
      </properties>
    </connector>
  </connectors>
</window-copy>
```

- `@SAS_CAS_SERVER_DEFAULT_CLIENT_SERVICE_HOST@` / `_PORT@` are Kubernetes service env vars, and ESP substitutes them at runtime. [VERIFIED]
- The pub/sub port in `url` (31416 here) is the project's pub/sub port, and the path is `Project/ContQuery/Window`. `snapshot=false` skips replaying the window's current contents on connect. [VERIFIED]

## 2. Key parameters

| Parameter | Meaning | Evidence |
|---|---|---|
| `type=sub` | Subscriber: ESP → CAS | DOC |
| `cashostport` | `host:port` of the CAS controller (binary port) | DOC |
| `caslib` / `castable` | Target. `castable` must match a SASHDAT file name (case-sensitive) if the table is loaded from disk | DOC |
| `casusername` / `caspassword` / `casoauthtoken` | Auth. When `caspassword` is missing, the adapter reads authinfo/netrc. Encrypt with `dfesp_pwd_encrypt` + `pwdencrypted=true` | DOC |
| **`commitblocks`** | Number of event blocks per CAS append/commit. **Default is 8. Trades throughput for latency.** | DOC + VERIFIED |
| `blocksize` | Event block size (relevant for the publisher direction) | DOC |
| `columns` | Subset of columns to read or write | DOC |
| `loglevel` | `severe` / `warning` (default) / `info` | DOC |

## 3. Schema mapping [DOC + VERIFIED]
"The event stream processing schema corresponds one to one with the SAS Cloud Analytic Services schema (except for the additional reserved key field required for a publisher and the opcode field written by a subscriber)."

| ESP type | CAS type |
|---|---|
| `int64` | `BIGINT` (**not** DOUBLE) |
| `int32` | `INT` |
| `double` | `DOUBLE` |
| `string` | `VARCHAR` |
| `stamp` (µs since epoch) | datetime (verify against the created table) |

**Pitfall [VERIFIED]:** if a table with a mismatching type already exists (for example `id` as DOUBLE from a DATA step), the subscriber fails. Either drop the table before the run or pre-create it with `PROC FEDSQL` using exact types (`templates/create_cas_target_table.sas`), and promote it to global scope.

## 4. The `java.io.EOFException` incident [VERIFIED]
- **Symptom:** after ~17,500 events the ESP server log shows
  `ERRORS handleMessageTag(): IOException when trying to commit an appender: java.io.EOFException`
- **Root cause:** the Kafka publisher used the default `blocksize=1`, so every event became its own block. The CAS adapter then issued thousands of tiny appends and commits, and the CAS session or connection dropped under load.
- **Fix:**
  1. `blocksize=1000` on the Kafka connector (needs `kafkatype=opaquestring` or `csv`)
  2. `commitblocks=10` on the CAS adapter
- **Result:** the project ran stably (≈90k+ events ingested into `BMC_RAW`).

## 5. Operational notes
- Target tables written by the adapter into `PUBLIC` are global. Transform them in `CASUSER` and promote only the final result, so readers don't collide with the streaming appender. [HEURISTIC]
- After a CAS restart, a streamed table that exists only in memory is gone. Persist it periodically (`proc casutil save`) if it must survive restarts. [HEURISTIC]
