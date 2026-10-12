# Python Window – JSON Flattening

## 1. Contract [VERIFIED]
```xml
<window-python name="w_flatten" events="create" index="pi_EMPTY">
  <schema> ... output fields, exactly one key field ... </schema>
  <code><![CDATA[
def create(data, context):
    event = {}
    event['id'] = data['id']          # carry the key through
    ...
    return event                      # dict: field name -> value; omit keys for NULL
  ]]></code>
</window-python>
```
- `events="create"` names the Python function that gets called for each incoming event. `data` is a dict of the input window's fields.
- Return **one dict** (one output event). Fields you leave out are NULL.
- Keep the output key equal to the input key (`id`) when the mapping is 1:1.

## 2. Timestamp handling [VERIFIED]
ESP `stamp` = **microseconds since the Unix epoch** (int). Convert ISO-8601 like this:
```python
import datetime
def parse_time(t_str):
    if not t_str:
        return None
    try:
        dt = datetime.datetime.fromisoformat(t_str.replace('Z', '+00:00'))
        return int(dt.timestamp() * 1_000_000)
    except Exception:
        return None
```
Only assign the field when the result isn't `None`.

## 3. Defensive parsing rules [VERIFIED / HEURISTIC]
- Wrap `json.loads` in `try/except`. One malformed message must not stop the window.
- Use `.get()` with defaults for every key. Producers drop optional *and* mandatory fields (for example, CloudEvents `specversion` was missing in production).
- Cast numerics explicitly (`float(val)`) and catch `ValueError`.
- Don't validate strictly against the JSON schema inside the stream. Flatten permissively, and filter downstream (Filter window or ETL).

## 4. Pattern: CloudEvents + telemetry → narrow EAV row
Outer CloudEvent (`id`, `source`, `type`, `time`, `dataschema`, custom extensions such as `origin`, `isa95`, `gxp`, `isdc`, `timeEventReceived`, `timeEdgeBrokerReceived`) plus inner `data` (`tag_name`, `value`, `uom`, `quality`, `origin.tag_name`) → one row per tag reading. See `templates/kafka_json_to_cas.xml` for the full code.
