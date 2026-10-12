# Kafka Connector (ESP Publisher → Source Window)

Source: `docs/espca.txt` (Kafka section, ~L4560–5000) and a live deployment on Viya 2026.08 against Confluent Cloud.

## 1. Working configuration (Confluent Cloud, SASL_SSL/PLAIN, JSON payload as opaque string) [VERIFIED]

```xml
<window-source name="w_source" insert-only="true" autogen-key="true" index="pi_EMPTY">
  <schema>
    <fields>
      <field name="id"       type="int64"  key="true"/>   <!-- index:int64 -->
      <field name="json_raw" type="string"/>              <!-- message:string -->
    </fields>
  </schema>
  <connectors>
    <connector class="kafka" name="KafkaIn">
      <properties>
        <property name="type"><![CDATA[pub]]></property>
        <property name="kafkahostport"><![CDATA[<bootstrap-host>:9092]]></property>
        <property name="kafkatopic"><![CDATA[<topic>]]></property>
        <property name="kafkatype"><![CDATA[opaquestring]]></property>
        <property name="urlhostport"><![CDATA[localhost_31415]]></property>
        <property name="kafkaconsumergroupid"><![CDATA[<unique-group-id>]]></property>
        <property name="kafkainitialoffset"><![CDATA[smallest]]></property>
        <property name="disableespmetaconsumer"><![CDATA[true]]></property>
        <property name="kafkaglobalconfig"><![CDATA[security.protocol=SASL_SSL;sasl.mechanism=PLAIN;sasl.username=@KAFKA_USER@;sasl.password=@KAFKA_PASS@;auto.offset.reset=earliest;enable.auto.commit=true]]></property>
        <property name="blocksize"><![CDATA[1000]]></property>
      </properties>
    </connector>
  </connectors>
</window-source>
```

## 2. Property semantics

| Property | Meaning / gotcha | Evidence |
|---|---|---|
| `type=pub` | Kafka → ESP (the connector publishes *into* ESP). | DOC |
| `kafkatype` | `binary`, `csv`, `json`, `protobuf`, `avro`, `opaquestring`, `opaquebinary`. With **`opaquestring`**, ESP assumes the Source schema `index:int64,message:string`, so the window must have exactly that shape. Use this when the payload is a nested JSON (CloudEvents) that ESP's `json` mode can't map. | DOC + VERIFIED |
| `blocksize` | Events per published event block. **Valid only with `kafkatype=csv` or `opaquestring`.** Default is 1. Set ~1000 for high-volume streams so downstream subscribers (CAS adapter) get large blocks. | DOC + VERIFIED |
| `transactional` | With csv/opaquestring, makes the blocks transactional. | DOC |
| `urlhostport` | host:port field for the ESP metadata topic. Kafka topic names don't allow `:`, so write `localhost_31415` instead of `localhost:31415`. | DOC |
| `disableespmetaconsumer` | `true` skips joining the `espmeta` consumer group. **Required on managed brokers** where the service account has no rights on ESP's meta topic or group. Default is `false`. | DOC + VERIFIED |
| `kafkaconsumergroupid` | Consumer group ID. Default is a random string, which means "no committed offsets", so the stream replays from `kafkainitialoffset` each time. Use an explicit ID for resumable consumption. | DOC |
| `kafkainitialoffset` | ESP-level start offset: `smallest` / `largest` / number. ESP uses **`smallest`**, not librdkafka's `earliest`. | DOC |
| `kafkaglobalconfig` | Semicolon-separated librdkafka `key=value` list. Wrap values that contain `;` in double quotes. Use it for SASL/SSL and `auto.offset.reset`. | DOC |
| `kafkapartition` | `-1` reads all partitions (no failover support in that mode). | DOC |
| `commitfinalwindow` + `enable.auto.commit=false` | Manual commits after the event reaches a given window. If you use this, leave `kafkaconsumergroupid`, `kafkapartition`, and `kafkainitialoffset` **unset** (ESP builds the group ID internally). | DOC |
| `ssl.endpoint.identification.algorithm=none` | Passed through `kafkaglobalconfig` to turn off hostname verification (for example for Event Hubs or self-signed certs). | DOC |

## 3. Offset decision tree [DOC + VERIFIED]

From the docs (espca ~L4604):
- No group ID and no initial offset → **smallest** available offset.
- Group ID set, no initial offset → **last committed offset** for that group. If the broker has none → **latest** (override with `auto.offset.reset` in `kafkaglobalconfig`).

```
Need to replay the full topic history?
├─ Use a brand-new kafkaconsumergroupid           → starts at smallest/earliest
└─ Keep the existing group ID
   └─ Reset committed offsets to the low watermark (templates/kafka_reset_offsets.py)
      └─ STOP the ESP project first: Confluent rejects offset commits for an active group
```

`auto.offset.reset=earliest` **only** applies when the broker has **no** stored offset for the group.

## 4. Retention caveat [VERIFIED]
The low watermark moves forward as broker retention deletes old segments. A reset to "earliest" only replays what retention still keeps. If you need the full history, archive it to CAS or files continuously.

## 5. Managed-broker checklist
- [ ] `security.protocol=SASL_SSL;sasl.mechanism=PLAIN` (Confluent API key and secret as username and password)
- [ ] `disableespmetaconsumer=true`
- [ ] Explicit `kafkaconsumergroupid` that the service account is allowed to use (Confluent ACLs often restrict group prefixes)
- [ ] Credentials injected through `@VAR@` or Studio env vars, never committed
- [ ] Outbound connectivity from the ESP pod to the bootstrap host on 9092
