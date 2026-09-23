# Copyright © 2025, SAS Institute Inc., Cary, NC, USA.  All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

"""Pack, unpack, render, validate and tokenize Custom Analysis Framework packages.

An AIoT analysis *type* is a zip:

.. code-block:: text

    <ANALYSIS_NAME>/input.xml                       registration, steps, parameters, SAS code
    <ANALYSIS_NAME>/<STEP_ID>_vaoutput.template     one Go template per visualizing step

``/iotAnalysisModels`` transports exactly that, so the whole authoring surface is
"build the zip correctly". This module holds the parts that can be got wrong:

* :func:`render_input_xml` / :func:`parse_input_xml` — a JSON-shaped spec to and
  from the XML, in the element order the importer expects. Built by hand rather
  than with ``ElementTree`` because the format is specific about CDATA sections
  and numeric character escapes that a generic serializer will not reproduce.
* :func:`build_package` / :func:`read_package` — the zip, with the top-level
  folder pinned to ``<Registration><Name>`` (the importer keys on it) and the
  template filename derived from the step id.
* :func:`check_tokens` — the check worth having. A ``{{.TOKEN}}`` in a template
  whose name no SAS declaration publishes renders a blank report and reports no
  error, so it is found in the UI, hours later, rather than here.
* :func:`tokenize_report_xml` — take BIRD XML from a report that already works
  in Visual Analytics and swap the live CAS table names for tokens. This is the
  documented manual workflow (design in VA, copy the XML, paste into the Output
  tab) done mechanically, and it is much safer than writing BIRD XML blind.

Everything here is pure except :func:`upload_package`, which owns the one part
of the contract the published API spec leaves open.
"""

from __future__ import annotations

import difflib
import io
import re
import zipfile
from datetime import UTC, datetime
from typing import Any
from xml.etree import ElementTree as ET

import httpx

from ..config import VIYA_ENDPOINT
from ..viya_client import raise_for_viya_status
from .caf_registry import (
    AMBIENT_TOKENS,
    ANALYSIS_TYPES,
    ARRAY_CONTROLS,
    COLUMN_SLOT_ATTR,
    COMPANION_SUFFIXES,
    CTX_METHODS,
    DATA_TYPES,
    DISPLAY_CONTROLS,
    GOTCHAS,
    KEY_GROUPS,
    LOOKUP_TYPES,
    MINIMAL_TEMPLATE,
    OUTPUT_CONTRACT,
    OUTPUT_PARAM_RE,
    OUTPUT_TABLE_RE,
    OUTPUT_VAR_RE,
    POSITIONAL_TOKEN_RE,
    PROPERTY_KEYS,
    TABLE_SLOT_ATTRS,
    TEMPLATE_FUNCTIONS,
    TEMPLATE_SUFFIX,
    TOKEN_RE,
    TOPICS,
    UPLOAD_STRATEGIES,
    topic_index,
)

# --- XML text handling -------------------------------------------------------

# The corpus escapes quotes and apostrophes numerically and encodes newlines as
# &#xA; in both attribute values and text nodes. One function covers both,
# because the format does not distinguish them.
_ESCAPES = (
    ("&", "&amp;"),
    ("<", "&lt;"),
    (">", "&gt;"),
    ('"', "&#34;"),
    ("'", "&#39;"),
    ("\r", "&#xD;"),
    ("\n", "&#xA;"),
)


def esc(value: Any) -> str:
    """Escape *value* for use as XML text or an attribute value."""
    text = "" if value is None else str(value)
    for raw, encoded in _ESCAPES:
        text = text.replace(raw, encoded)
    return text


def _cdata(text: str) -> str:
    """Wrap *text* in a CDATA section, splitting it if it contains the terminator."""
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def _bool(value: Any, default: bool = False) -> str:
    if value is None:
        return "true" if default else "false"
    if isinstance(value, str):
        return "true" if value.strip().lower() in {"true", "1", "yes"} else "false"
    return "true" if value else "false"


def _pick(src: dict[str, Any], *names: str, default: Any = None) -> Any:
    """First present key among *names* — the spec accepts snake_case or the XML spelling."""
    for name in names:
        if name in src and src[name] is not None:
            return src[name]
    return default


def _now() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


# --- rendering ---------------------------------------------------------------

_EMPTY_STAMP = "0001-01-01T00:00:00Z"

# A legal identifier for a parameter, a step or an output param name.
_NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*$")


def template_filename(step_id: str) -> str:
    """The template file a step's output lives in.

    The name comes from the STEP ID with a trailing ``_DEFAULT`` stripped — not
    from ``<TemplateID>``, which frequently carries the suffix. ``SVDD_ASSET_1_DEFAULT``
    and step ``SVDD_ASSET_1`` both give ``SVDD_ASSET_1_vaoutput.template``.
    """
    base = step_id[: -len("_DEFAULT")] if step_id.endswith("_DEFAULT") else step_id
    return f"{base}{TEMPLATE_SUFFIX}"


def _render_values(tag: str, values: Any, indent: str) -> list[str]:
    if not values:
        return []
    out = [f"{indent}<{tag}>"]
    for entry in values:
        if isinstance(entry, dict):
            key = _pick(entry, "key", default="")
            val = _pick(entry, "value", default=key)
        else:
            key = val = entry
        out.append(f'{indent} <Values key="{esc(key)}" value="{esc(val)}"></Values>')
    out.append(f"{indent}</{tag}>")
    return out


def _render_properties(props: Any, indent: str) -> list[str]:
    """``<Properties>`` — emitted even when empty; the importer expects the element."""
    if not props:
        return [f"{indent}<Properties></Properties>"]
    items = props.items() if isinstance(props, dict) else ((p.get("key"), p.get("value")) for p in props)
    out = [f"{indent}<Properties>"]
    for key, value in items:
        out.append(f'{indent} <Property key="{esc(key)}">{esc(value)}</Property>')
    out.append(f"{indent}</Properties>")
    return out


def _render_lookup(lookup: dict[str, Any], param_name: str, indent: str) -> list[str]:
    lookup_id = _pick(lookup, "id", default=f"{param_name}_LOOKUP")
    name = _pick(lookup, "name")
    kind = _pick(lookup, "type", "lookup_type")
    attrs = [f'id="{esc(lookup_id)}"']
    if name:
        attrs.append(f'name="{esc(name)}"')
    attrs.append(f'isReused="{_bool(_pick(lookup, "is_reused", "isReused"), False)}"')
    if kind:
        attrs.append(f'type="{esc(kind)}"')
    out = [f"{indent}<LookupMetadata {' '.join(attrs)}>"]
    out.append(f"{indent} <CreationTimeStamp>{_EMPTY_STAMP}</CreationTimeStamp>")
    out.append(f"{indent} <CreatedBy></CreatedBy>")
    out.append(f"{indent} <ModifiedTimeStamp>{_EMPTY_STAMP}</ModifiedTimeStamp>")
    out.append(f"{indent} <ModifiedBy></ModifiedBy>")

    rest = _pick(lookup, "rest", "Rest")
    cas = _pick(lookup, "cas_table", "CASTable", "castable")
    if kind == "RESTAPI" and rest:
        out.append(f"{indent} <Rest>")
        out.append(f"{indent}  <Method>{esc(_pick(rest, 'method', 'Method', default='GET'))}</Method>")
        out.append(f"{indent}  <URI>{esc(_pick(rest, 'uri', 'URI', default=''))}</URI>")
        headers = _pick(
            rest,
            "headers",
            "Headers",
            default='{"Content-Type":"application/json","Accept":"application/json"}',
        )
        out.append(f"{indent}  <Headers>{esc(headers)}</Headers>")
        out.append(f"{indent}  <resKeyName>{esc(_pick(rest, 'key_path', 'resKeyName', default=''))}</resKeyName>")
        out.append(
            f"{indent}  <resValueName>{esc(_pick(rest, 'value_path', 'resValueName', default=''))}</resValueName>"
        )
        body = _pick(rest, "body", "Body")
        if body:
            out.append(f"{indent}  <Body>{esc(body)}</Body>")
        out.append(f"{indent} </Rest>")
    elif kind == "CASTABLE" and cas:
        out.append(f"{indent} <CASTable>")
        out.append(f"{indent}  <LibraryName>{esc(_pick(cas, 'library', 'LibraryName', default=''))}</LibraryName>")
        out.append(f"{indent}  <TableName>{esc(_pick(cas, 'table', 'TableName', default=''))}</TableName>")
        out.append(
            f"{indent}  <KeyColumnName>{esc(_pick(cas, 'key_column', 'KeyColumnName', default=''))}</KeyColumnName>"
        )
        out.append(
            f"{indent}  <ValueColumnName>"
            f"{esc(_pick(cas, 'value_column', 'ValueColumnName', default=''))}</ValueColumnName>"
        )
        out.append(
            f"{indent}  <WhereCondition>"
            f"{esc(_pick(cas, 'where', 'WhereCondition', default=''))}</WhereCondition>"
        )
        out.append(f"{indent} </CASTable>")

    out.extend(_render_properties(_pick(lookup, "properties", "Properties"), f"{indent} "))
    out.append(f"{indent}</LookupMetadata>")
    return out


def _render_parameter(param: dict[str, Any], order: int, indent: str) -> list[str]:
    name = _pick(param, "name", default="")
    control = _pick(param, "display_control", "displayControl", default="")
    data_type = _pick(param, "data_type", "dataType")
    if data_type is None:
        data_type = "Array" if control in ARRAY_CONTROLS else "String"
    attrs = (
        f'name="{esc(name)}" '
        f'displayText="{esc(_pick(param, "display_text", "displayText", "display_name", default=""))}" '
        f'required="{_bool(_pick(param, "required"), False)}" '
        f'visibility="{_bool(_pick(param, "visible", "visibility"), True)}" '
        f'order="{_pick(param, "order", default=order)}" '
        f'dataType="{esc(data_type)}" '
        f'displayControl="{esc(control)}"'
    )
    out = [f"{indent}<Parameter {attrs}>"]
    out.extend(_render_values("PossibleValues", _pick(param, "possible_values", "PossibleValues"), f"{indent} "))
    out.extend(_render_values("DefaultValues", _pick(param, "default_values", "DefaultValues"), f"{indent} "))
    lookup = _pick(param, "lookup", "LookupMetadata")
    if lookup:
        out.extend(_render_lookup(lookup, name, f"{indent} "))
    out.extend(_render_properties(_pick(param, "properties", "Properties"), f"{indent} "))

    group = _pick(param, "ui_group", "UIGroup") or {}
    tab = _pick(group, "tab", default="BASIC")
    tab_name = _pick(group, "tab_name", "tabName", default=tab.title())
    out.append(f"{indent} <UIGroup>")
    out.append(f"{indent}  <tab>{esc(tab)}</tab>")
    out.append(f"{indent}  <tabName>{esc(tab_name)}</tabName>")
    out.append(f"{indent}  <group>{esc(_pick(group, 'group', default=tab_name))}</group>")
    out.append(
        f"{indent}  <groupName>"
        f"{esc(_pick(group, 'group_name', 'groupName', default=f'{tab_name} Settings'))}</groupName>"
    )
    out.append(f"{indent} </UIGroup>")
    out.append(f"{indent}</Parameter>")
    return out


def default_containers(parameters: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """One TAB per distinct ``ui_group.tab``, holding that tab's parameters in order.

    The layout most analyses use, so a caller who does not care about layout can
    omit ``containers`` entirely. Form order is what the UI honours — the
    parameter's own ``order`` attribute does not reorder a laid-out form — so the
    parameters are emitted here in the order they were declared.
    """
    tabs: dict[str, dict[str, Any]] = {}
    for param in parameters:
        group = _pick(param, "ui_group", "UIGroup") or {}
        tab = _pick(group, "tab", default="BASIC")
        label = _pick(group, "tab_name", "tabName", default=tab.title())
        bucket = tabs.setdefault(tab, {"type": "TAB", "display_text": label, "items": []})
        bucket["items"].append(_pick(param, "name", default=""))
    return [
        {
            "type": "TAB",
            "display_text": tab["display_text"],
            "forms": [{"items": [{"ref": "", "type": "INLINE"}, *({"ref": n} for n in tab["items"])]}],
        }
        for tab in tabs.values()
    ]


def _render_form_item(item: Any, indent: str) -> str:
    if isinstance(item, str):
        item = {"ref": item}
    ref = esc(_pick(item, "ref", default=""))
    kind = _pick(item, "type")
    type_attr = f' type="{esc(kind)}"' if kind else ""
    return f'{indent}<FormItem ref="{ref}"{type_attr}></FormItem>'


def _render_containers(containers: list[dict[str, Any]], indent: str) -> list[str]:
    out = [f"{indent}<Containers>"]
    for tab in containers:
        label = esc(_pick(tab, "display_text", "displayText", "label", default=""))
        out.append(f'{indent} <Container type="{esc(_pick(tab, "type", default="TAB"))}" displayText="{label}">')
        for form in _pick(tab, "forms", default=[{"items": _pick(tab, "items", default=[])}]):
            form_label = esc(_pick(form, "display_text", "displayText", default=""))
            out.append(f'{indent}  <Container type="FORM" displayText="{form_label}">')
            for item in _pick(form, "items", default=[]):
                out.append(_render_form_item(item, f"{indent}   "))
            out.append(f"{indent}  </Container>")
        out.append(f"{indent} </Container>")
    out.append(f"{indent}</Containers>")
    return out


def _render_step(step: dict[str, Any], position: int, indent: str) -> list[str]:
    step_id = _pick(step, "id", "step_id", default=f"STP_{position}")
    attrs = (
        f'id="{esc(step_id)}" '
        f'displayName="{esc(_pick(step, "display_name", "displayName", default=step_id))}" '
        f'order="{_pick(step, "order", default=position)}"'
    )
    out = [f"{indent}<Step {attrs}>"]
    out.append(f"{indent} <TemplateID>{esc(_pick(step, 'template_id', 'TemplateID', default=step_id))}</TemplateID>")

    parameters = _pick(step, "parameters", default=[])
    out.append(f"{indent} <Parameters>")
    for i, param in enumerate(parameters):
        out.extend(_render_parameter(param, i, f"{indent}  "))
    out.append(f"{indent} </Parameters>")

    containers = _pick(step, "containers") or default_containers(parameters)
    out.extend(_render_containers(containers, f"{indent} "))

    code = _pick(step, "code", "Code", default="")
    out.append(f"{indent} <Code>{_cdata(code)}</Code>")
    out.append(f"{indent}</Step>")
    return out


def _render_interaction(interaction: dict[str, Any], model_name: str, indent: str) -> list[str]:
    attrs = (
        f'name="{esc(_pick(interaction, "name", default=""))}" '
        f'sourceParamName="{esc(_pick(interaction, "source_param", "sourceParamName", default=""))}" '
        f'modelName="{esc(_pick(interaction, "model_name", "modelName", default=model_name))}" '
        f'combinator="{esc(_pick(interaction, "combinator", default="AND"))}" '
        f'Order="{_pick(interaction, "order", "Order", default=0)}"'
    )
    out = [f"{indent}<Interaction {attrs}>"]
    condition = _pick(interaction, "condition", "Condition", default="")
    # An empty <Condition/> means "always" — the actions run on every change of
    # the source parameter. That is the common case for a cascade.
    out.append(f"{indent} <Condition>{_cdata(condition) if condition else ''}</Condition>")
    out.append(f"{indent} <Actions>")
    for i, action in enumerate(_pick(interaction, "actions", default=[])):
        if isinstance(action, str):
            action = {"expression": action}
        expression = _pick(action, "expression", "action", "Action", default="")
        if isinstance(expression, list):
            expression = "\n".join(expression)
        result = _bool(_pick(action, "condition_result", "conditionResult"), True)
        out.append(f'{indent}  <Action Order="{_pick(action, "order", "Order", default=i)}">')
        out.append(f"{indent}   <Action>{esc(expression)}</Action>")
        out.append(f"{indent}   <ConditionResult>{result}</ConditionResult>")
        out.append(f"{indent}  </Action>")
    out.append(f"{indent} </Actions>")
    out.append(f"{indent}</Interaction>")
    return out


def render_input_xml(spec: dict[str, Any]) -> str:
    """Render an analysis-type *spec* as ``input.xml``.

    Element order is fixed — Registration, Steps, Interactions, ZipModifiedAt,
    ZipHash — and matches every shipped package. ``<ZipHash>`` is left empty, as
    it is in all of them; nothing needs hashing for the import to succeed.
    """
    name = _pick(spec, "name", "Name", default="")
    lines = ["<AnalysisModel>"]
    lines.append(
        " <Registration "
        f'active="{_bool(_pick(spec, "active"), True)}" '
        f'type="{esc(_pick(spec, "type", default="CUSTOM"))}" '
        f'orderNo="{_pick(spec, "order_no", "orderNo", default=0)}" '
        f'revisionNo="{_pick(spec, "revision_no", "revisionNo", default=1)}" '
        f'dataSelectionRequired="{_bool(_pick(spec, "data_selection_required"), False)}">'
    )
    lines.append(f"  <Name>{esc(name)}</Name>")
    lines.append(f"  <DisplayName>{esc(_pick(spec, 'display_name', 'DisplayName', default=name))}</DisplayName>")
    lines.append(
        f"  <Description>"
        f"{esc(_pick(spec, 'description', 'Description', default='Analysis type description'))}</Description>"
    )
    lines.append(f"  <KeyGroup>{esc(_pick(spec, 'key_group', 'KeyGroup', default='ASSET'))}</KeyGroup>")
    lines.append(f"  <ModifiedTime>{_pick(spec, 'modified_time', default=_now())}</ModifiedTime>")
    lines.append(" </Registration>")

    lines.append(" <Steps>")
    for i, step in enumerate(_pick(spec, "steps", default=[]), start=1):
        lines.extend(_render_step(step, i, "  "))
    lines.append(" </Steps>")

    interactions = _pick(spec, "interactions", default=[])
    if interactions:
        lines.append(" <Interactions>")
        for interaction in interactions:
            lines.extend(_render_interaction(interaction, name, "  "))
        lines.append(" </Interactions>")
    else:
        lines.append(" <Interactions></Interactions>")

    lines.append(f" <ZipModifiedAt>{_pick(spec, 'zip_modified_at', default=_now())}</ZipModifiedAt>")
    lines.append(" <ZipHash></ZipHash>")
    lines.append("</AnalysisModel>")
    return "\n".join(lines)


# --- parsing -----------------------------------------------------------------


def _text(node: ET.Element | None, tag: str, default: str = "") -> str:
    if node is None:
        return default
    child = node.find(tag)
    return default if child is None or child.text is None else child.text


def _parse_properties(node: ET.Element | None) -> dict[str, str]:
    if node is None:
        return {}
    props = node.find("Properties")
    if props is None:
        return {}
    return {p.get("key", ""): (p.text or "") for p in props.findall("Property")}


def _parse_values(node: ET.Element, tag: str) -> list[dict[str, str]]:
    holder = node.find(tag)
    if holder is None:
        return []
    return [{"key": v.get("key", ""), "value": v.get("value", "")} for v in holder.findall("Values")]


def _parse_lookup(node: ET.Element) -> dict[str, Any] | None:
    lookup = node.find("LookupMetadata")
    if lookup is None:
        return None
    out: dict[str, Any] = {
        "id": lookup.get("id", ""),
        "name": lookup.get("name"),
        "is_reused": lookup.get("isReused") == "true",
        "type": lookup.get("type"),
        "properties": _parse_properties(lookup),
    }
    rest = lookup.find("Rest")
    if rest is not None:
        out["rest"] = {
            "method": _text(rest, "Method", "GET"),
            "uri": _text(rest, "URI"),
            "headers": _text(rest, "Headers"),
            "key_path": _text(rest, "resKeyName").strip(),
            "value_path": _text(rest, "resValueName").strip(),
        }
    cas = lookup.find("CASTable")
    if cas is not None:
        out["cas_table"] = {
            "library": _text(cas, "LibraryName"),
            "table": _text(cas, "TableName"),
            "key_column": _text(cas, "KeyColumnName"),
            "value_column": _text(cas, "ValueColumnName"),
            "where": _text(cas, "WhereCondition"),
        }
    if out["type"] is None and rest is None and cas is None:
        # No type and no payload: a reference to a shared platform lookup by id.
        out["shared_reference"] = True
    return out


def _parse_containers(step: ET.Element) -> list[dict[str, Any]]:
    holder = step.find("Containers")
    if holder is None:
        return []
    tabs = []
    for tab in holder.findall("Container"):
        forms = []
        for form in tab.findall("Container"):
            forms.append(
                {
                    "display_text": form.get("displayText", ""),
                    "items": [
                        {"ref": item.get("ref", ""), "type": item.get("type")}
                        for item in form.findall("FormItem")
                    ],
                }
            )
        tabs.append({"type": tab.get("type", "TAB"), "display_text": tab.get("displayText", ""), "forms": forms})
    return tabs


def parse_input_xml(xml: str) -> dict[str, Any]:
    """Parse ``input.xml`` into the same spec shape :func:`render_input_xml` consumes.

    Round-tripping a shipped package through parse→render is how the renderer is
    kept honest about element order and required-but-empty elements.
    """
    root = ET.fromstring(xml)  # noqa: S314 - artifact from an authenticated Viya service
    reg = root.find("Registration")
    spec: dict[str, Any] = {
        "name": _text(reg, "Name"),
        "display_name": _text(reg, "DisplayName"),
        "description": _text(reg, "Description"),
        "key_group": _text(reg, "KeyGroup"),
        "type": reg.get("type", "CUSTOM") if reg is not None else "CUSTOM",
        "active": (reg.get("active") == "true") if reg is not None else True,
        "order_no": int(reg.get("orderNo", "0")) if reg is not None else 0,
        "revision_no": int(reg.get("revisionNo", "1")) if reg is not None else 1,
        "data_selection_required": (reg.get("dataSelectionRequired") == "true") if reg is not None else False,
        "modified_time": _text(reg, "ModifiedTime"),
        "steps": [],
        "interactions": [],
    }

    steps_node = root.find("Steps")
    for step in steps_node.findall("Step") if steps_node is not None else []:
        params = []
        params_node = step.find("Parameters")
        for param in params_node.findall("Parameter") if params_node is not None else []:
            entry: dict[str, Any] = {
                "name": param.get("name", ""),
                "display_text": param.get("displayText", ""),
                "required": param.get("required") == "true",
                "visible": param.get("visibility") != "false",
                "order": int(param.get("order", "0")),
                "data_type": param.get("dataType", ""),
                "display_control": param.get("displayControl", ""),
                "properties": _parse_properties(param),
            }
            possible = _parse_values(param, "PossibleValues")
            if possible:
                entry["possible_values"] = possible
            defaults = _parse_values(param, "DefaultValues")
            if defaults:
                entry["default_values"] = defaults
            lookup = _parse_lookup(param)
            if lookup:
                entry["lookup"] = lookup
            group = param.find("UIGroup")
            if group is not None:
                entry["ui_group"] = {
                    "tab": _text(group, "tab"),
                    "tab_name": _text(group, "tabName"),
                    "group": _text(group, "group"),
                    "group_name": _text(group, "groupName"),
                }
            params.append(entry)

        spec["steps"].append(
            {
                "id": step.get("id", ""),
                "display_name": step.get("displayName", ""),
                "order": int(step.get("order", "0")),
                "template_id": _text(step, "TemplateID"),
                "parameters": params,
                "containers": _parse_containers(step),
                "code": _text(step, "Code"),
            }
        )

    interactions_node = root.find("Interactions")
    for interaction in interactions_node.findall("Interaction") if interactions_node is not None else []:
        actions = []
        actions_node = interaction.find("Actions")
        for action in actions_node.findall("Action") if actions_node is not None else []:
            actions.append(
                {
                    "order": int(action.get("Order", "0")),
                    "expression": _text(action, "Action"),
                    "condition_result": _text(action, "ConditionResult", "true") == "true",
                }
            )
        spec["interactions"].append(
            {
                "name": interaction.get("name", ""),
                "source_param": interaction.get("sourceParamName", ""),
                "model_name": interaction.get("modelName", ""),
                "combinator": interaction.get("combinator", "AND"),
                "order": int(interaction.get("Order", "0")),
                "condition": _text(interaction, "Condition"),
                "actions": actions,
            }
        )
    return spec


# --- the zip -----------------------------------------------------------------


def build_package(spec: dict[str, Any]) -> tuple[bytes, dict[str, Any]]:
    """Build the analysis-type zip. Returns ``(zip_bytes, manifest)``.

    The top-level folder is ``<Registration><Name>`` — the importer keys on it,
    and a mismatch is rejected with an unhelpful error. A step with no
    ``vaoutput_template`` of its own gets the minimal legal BIRD report rather
    than no file: a missing template and an empty one fail differently, and both
    fail later than here.
    """
    name = _pick(spec, "name", "Name", default="")
    xml = render_input_xml(spec)
    manifest: dict[str, Any] = {"folder": name, "files": [f"{name}/input.xml"], "templates": {}}

    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr(f"{name}/input.xml", xml)
        for step in _pick(spec, "steps", default=[]):
            step_id = _pick(step, "id", "step_id", default="")
            template = _pick(step, "vaoutput_template", "template")
            if template is None and not _pick(step, "no_template", default=False):
                template = MINIMAL_TEMPLATE
                manifest["templates"][step_id] = "minimal placeholder"
            elif template is not None:
                manifest["templates"][step_id] = f"{len(template)} chars"
            if template is None:
                continue
            filename = f"{name}/{template_filename(step_id)}"
            zf.writestr(filename, template)
            manifest["files"].append(filename)
    return buffer.getvalue(), manifest


def read_package(data: bytes) -> dict[str, Any]:
    """Unpack an analysis-type zip into ``{folder, input_xml, templates, spec}``."""
    with zipfile.ZipFile(io.BytesIO(data)) as zf:
        names = [n for n in zf.namelist() if not n.endswith("/")]
        input_names = [n for n in names if n.endswith("input.xml")]
        if not input_names:
            raise ValueError(f"No input.xml in the package; it holds {names}.")
        input_name = input_names[0]
        input_xml = zf.read(input_name).decode("utf-8")
        templates = {
            n.rsplit("/", 1)[-1][: -len(TEMPLATE_SUFFIX)]: zf.read(n).decode("utf-8", "replace")
            for n in names
            if n.endswith(TEMPLATE_SUFFIX)
        }
    return {
        "folder": input_name.rsplit("/", 1)[0] if "/" in input_name else "",
        "input_xml": input_xml,
        "templates": templates,
        "spec": parse_input_xml(input_xml),
    }


# --- tokens ------------------------------------------------------------------


def template_tokens(template: str) -> set[str]:
    """Every ``{{.TOKEN}}`` a template reads, including inside ``{{if}}`` pipelines."""
    return set(TOKEN_RE.findall(template or ""))


def code_tokens(code: str) -> dict[str, set[str]]:
    """Every output name a step's SAS code publishes, by the mechanism that publishes it.

    Two mechanisms, and an analysis may use either:

    * declarative — ``%let g_output_table_N = lib.MEMBER;`` publishes the BARE
      MEMBER NAME (the libref is where the table is read from, not what it is
      called downstream), and ``%let g_output_var_N = NAME;`` publishes ``NAME``;
    * explicit — a POST to the step's ``outputParams`` endpoint, where each
      ``"outputname"`` in the body is published verbatim.
    """
    text = code or ""
    tables = {value.strip().rsplit(".", 1)[-1].strip().upper() for _, value in OUTPUT_TABLE_RE.findall(text)}
    variables = {value.strip().upper() for _, value in OUTPUT_VAR_RE.findall(text)}
    explicit = {
        value.strip().upper()
        for value in OUTPUT_PARAM_RE.findall(text)
        if _NAME_RE.match(value.strip())
    }
    return {"tables": tables, "variables": variables, "explicit": explicit}


def publishes_dynamically(code: str) -> bool:
    """True when a step builds its output-param names at run time.

    The shipped MTS analysis writes its ``outputParams`` body from a macro loop —
    ``put ' { "outputname":"' "ANALYSISVAR&l_c" '"...'`` — so the names only exist
    once SAS has run, and no static reading of the code can enumerate them. The
    tell is that ``outputname`` appears more often than a literal name can be
    read out of it. A step like that cannot be token-checked, and pretending
    otherwise reports every one of its tokens as missing.
    """
    text = code or ""
    mentions = text.count("outputname")
    if not mentions:
        return False
    literal = len([v for v in OUTPUT_PARAM_RE.findall(text) if _NAME_RE.match(v.strip())])
    return literal < mentions


def check_tokens(spec: dict[str, Any]) -> list[dict[str, Any]]:
    """Cross-check every step's template tokens against what could resolve them.

    An unmatched ``{{.TOKEN}}`` renders an empty report and raises nothing
    anywhere, so this is the check worth running — but three things resolve a
    token, and treating only the first as valid produces a wall of false alarms
    (verified against all 34 shipped packages):

    * an **output param** published by this step or an earlier one — steps see
      each other's outputs, which is how a visualization step reads a
      preparation step's table;
    * an **input parameter** of the analysis — ``{{.REPORTING_VAR}}`` renders the
      column the user picked, so a parameter name is a valid token;
    * **anything at all**, for a STANDARD or ALERTS type: ``%anl_driver``
      publishes a large fixed vocabulary the step's own code never names (the
      shipped Trend type reads 234 tokens from a one-line program), so the
      producer set is not knowable from the package and the check is skipped.

    What is left over is a genuine dangling token.
    """
    findings: list[dict[str, Any]] = []
    kind = str(_pick(spec, "type", default="CUSTOM")).upper()
    steps = sorted(_pick(spec, "steps", default=[]), key=lambda s: _pick(s, "order", default=0))

    # Parameter names resolve as tokens regardless of which step declares them.
    parameters = {
        str(_pick(p, "name", default="")).upper()
        for s in steps
        for p in _pick(s, "parameters", default=[])
    }
    published: set[str] = set()

    for step in steps:
        code = _pick(step, "code", default="") or ""
        produced = code_tokens(code)
        published |= produced["tables"] | produced["variables"] | produced["explicit"]
        template = _pick(step, "vaoutput_template", "template") or ""
        wanted = template_tokens(template)
        step_id = _pick(step, "id", default="")

        # %anl_driver publishes implicitly; so does any step that posts output
        # params with names built at run time rather than written as literals.
        dynamic = publishes_dynamically(code)
        implicit = kind != "CUSTOM" or "%anl_driver" in code.lower() or dynamic
        if dynamic and wanted:
            findings.append(
                {
                    "severity": "info",
                    "step": step_id,
                    "message": (
                        "This step builds its output-param names at run time, so its template "
                        "tokens cannot be checked statically. Confirm them from a real run's "
                        "output params."
                    ),
                }
            )

        for token in sorted(wanted):
            upper = token.upper()
            # A companion token (X_LABEL, X_FORMAT, X_DESC) is derived by the
            # framework, so it resolves whether or not X itself is published.
            base = next((upper[: -len(s)] for s in COMPANION_SUFFIXES if upper.endswith(s)), upper)
            if (
                implicit
                or upper in published
                or upper in parameters
                or upper in AMBIENT_TOKENS
                or base != upper
                or POSITIONAL_TOKEN_RE.match(token)
            ):
                continue
            close = difflib.get_close_matches(upper, sorted(published | parameters), n=2, cutoff=0.6)
            findings.append(
                {
                    "severity": "error",
                    "step": step_id,
                    "token": token,
                    "message": (
                        f"Template token {{{{.{token}}}}} has no producer. It is neither an output "
                        "published by this step or an earlier one, nor a parameter name, so the "
                        "report will render blank with no error. Add "
                        "`%let g_output_table_N = <lib>.<member>;` (the token is the bare member "
                        "name, uppercase) or publish it via the outputParams POST."
                    ),
                    "did_you_mean": close,
                }
            )

        unused = {t.upper() for t in produced["tables"] | produced["variables"]} - {t.upper() for t in wanted}
        if unused and template:
            findings.append(
                {
                    "severity": "info",
                    "step": step_id,
                    "message": (
                        f"Published but not read by this step's template: {sorted(unused)}. "
                        "Fine if a later step reads them."
                    ),
                }
            )
    return findings


def output_contract(tables: list[str], variables: list[str] | None = None) -> str:
    """Render the ``g_output_table_N`` / ``%afi_caf_postprocess`` tail for *tables*.

    Emitting this alongside a tokenized template is what keeps the two halves of
    the name mapping in step: the tokens the template reads are exactly the
    member names declared here.
    """
    variables = variables or []
    return OUTPUT_CONTRACT.format(
        n_tables=len(tables),
        tables="\n".join(f"%let g_output_table_{i} = {t};" for i, t in enumerate(tables, start=1)),
        n_vars=len(variables),
        vars="\n".join(f"%let g_output_var_{i} = {v};" for i, v in enumerate(variables, start=1)),
    )


# --- tokenizing a working VA report ------------------------------------------

_ATTR_RE_CACHE: dict[str, re.Pattern[str]] = {}


def _attr_re(attr: str) -> re.Pattern[str]:
    if attr not in _ATTR_RE_CACHE:
        _ATTR_RE_CACHE[attr] = re.compile(rf'({attr}=")([^"]*)(")')
    return _ATTR_RE_CACHE[attr]


def tokenize_report_xml(
    xml: str,
    table_map: dict[str, str],
    column_map: dict[str, str] | None = None,
) -> tuple[str, dict[str, Any]]:
    """Replace live CAS table and column names in BIRD XML with ``{{.TOKEN}}`` slots.

    *table_map* maps a runtime table name to the token that should stand in its
    place — ``{"DEMO_SAMPLE_9F2A1B": "SAMPLE"}`` — and is applied to both
    attributes that carry a table name: ``CasResource/@table`` (the physical
    slot) and ``DataSource/@label`` (the design-time label beside it). Missing
    the label is the usual reason a tokenized report half-works.

    Columns are only worth tokenizing when the run can produce different ones;
    a fixed schema is better left literal.

    Returns the rewritten XML and a report of what was substituted, so a caller
    can see that a mapping entry matched nothing before shipping it.
    """
    counts: dict[str, int] = dict.fromkeys(table_map, 0)
    column_map = column_map or {}
    counts.update(dict.fromkeys(column_map, 0))

    def substitute(attr: str, mapping: dict[str, str], text: str) -> str:
        def repl(match: re.Match[str]) -> str:
            value = match.group(2)
            token = mapping.get(value)
            if token is None:
                return match.group(0)
            counts[value] += 1
            return f"{match.group(1)}{{{{.{token}}}}}{match.group(3)}"

        return _attr_re(attr).sub(repl, text)

    out = xml
    for attr in TABLE_SLOT_ATTRS:
        out = substitute(attr, table_map, out)
    if column_map:
        out = substitute(COLUMN_SLOT_ATTR, column_map, out)

    unmatched = sorted(name for name, hits in counts.items() if hits == 0)
    report: dict[str, Any] = {
        "substitutions": {name: hits for name, hits in counts.items() if hits},
        "tokens": sorted(template_tokens(out)),
    }
    if unmatched:
        report["unmatched"] = unmatched
        report["warning"] = (
            f"These names appear nowhere in the report: {unmatched}. Check them against the "
            "CasResource/@table values in the source XML — a runtime table name carries the "
            "<ANALYSIS_TYPE>_<member>_<SHORT_ID> suffix and is easy to mistype."
        )
    return out, report


# --- validation --------------------------------------------------------------

def _suggest(value: str, allowed: Any) -> list[str]:
    return difflib.get_close_matches(str(value), sorted(allowed), n=3, cutoff=0.5)


def validate_spec(spec: dict[str, Any]) -> list[dict[str, Any]]:
    """Check a spec against the enumerations and the structural rules.

    Errors block an upload; warnings are things the importer accepts but the UI
    will not behave as intended about.
    """
    issues: list[dict[str, Any]] = []

    def add(severity: str, where: str, message: str, **extra: Any) -> None:
        issues.append({"severity": severity, "where": where, "message": message, **extra})

    name = str(_pick(spec, "name", default=""))
    if not name:
        add("error", "registration", "name is required; it is also the zip's folder name.")
    elif not _NAME_RE.match(name):
        add("error", "registration", f"name '{name}' must start with a letter and hold only letters, digits and _.")
    elif name != name.upper():
        add("warning", "registration", f"name '{name}' is not uppercase; every shipped type is.")

    kind = _pick(spec, "type", default="CUSTOM")
    if kind not in ANALYSIS_TYPES:
        add("error", "registration", f"type '{kind}' is not one of {sorted(ANALYSIS_TYPES)}.")
    key_group = _pick(spec, "key_group", default="ASSET")
    if key_group not in KEY_GROUPS:
        add("error", "registration", f"key_group '{key_group}' is not one of {sorted(KEY_GROUPS)}.")

    steps = _pick(spec, "steps", default=[])
    if not steps:
        add("error", "steps", "at least one step is required.")

    step_ids: set[str] = set()
    declared: set[str] = set()
    for step in steps:
        step_id = str(_pick(step, "id", "step_id", default=""))
        where = f"step '{step_id or '?'}'"
        if not step_id:
            add("error", where, "step id is required; the template filename is derived from it.")
        elif step_id in step_ids:
            add("error", where, f"duplicate step id '{step_id}'.")
        step_ids.add(step_id)

        names_in_step: set[str] = set()
        for param in _pick(step, "parameters", default=[]):
            pname = str(_pick(param, "name", default=""))
            pwhere = f"{where} parameter '{pname or '?'}'"
            if not pname:
                add("error", pwhere, "parameter name is required.")
            elif pname in names_in_step:
                add("error", pwhere, f"duplicate parameter name '{pname}' in this step.")
            names_in_step.add(pname)
            declared.add(pname)

            control = _pick(param, "display_control", "displayControl", default="")
            if control not in DISPLAY_CONTROLS:
                add(
                    "error",
                    pwhere,
                    f"display_control '{control}' is not recognised.",
                    did_you_mean=_suggest(control, DISPLAY_CONTROLS),
                )
            data_type = _pick(param, "data_type", "dataType", default="String")
            if data_type not in DATA_TYPES:
                canonical = next((d for d in DATA_TYPES if d.lower() == str(data_type).lower()), None)
                if canonical:
                    # The importer accepts 'string' for 'String' — one shipped
                    # package relies on it — so this is a style point, not a fault.
                    add("warning", pwhere, f"data_type '{data_type}' should be spelled '{canonical}'.")
                else:
                    add("error", pwhere, f"data_type '{data_type}' is not one of {sorted(DATA_TYPES)}.")
            if control in ARRAY_CONTROLS and data_type != "Array":
                add(
                    "warning",
                    pwhere,
                    f"{control} with data_type '{data_type}': multi-value controls need "
                    "dataType='Array' or only the last selection reaches the code.",
                )

            for key in (_pick(param, "properties", default={}) or {}):
                if key not in PROPERTY_KEYS:
                    add("warning", pwhere, f"unknown property '{key}'.", did_you_mean=_suggest(key, PROPERTY_KEYS))

            lookup = _pick(param, "lookup")
            if lookup:
                issues.extend(_validate_lookup(lookup, pwhere))
                if control == "STABLEPERIOD" and _pick(lookup, "type") != "CASTABLE":
                    add("error", pwhere, "STABLEPERIOD requires a CASTABLE lookup naming the key and value columns.")

        # Every FormItem must point at a parameter of this step (or be an INLINE divider).
        for tab in _pick(step, "containers", default=[]) or []:
            for form in _pick(tab, "forms", default=[]):
                for item in _pick(form, "items", default=[]):
                    ref = item if isinstance(item, str) else _pick(item, "ref", default="")
                    if ref and ref not in names_in_step:
                        add(
                            "error",
                            where,
                            f"form item references '{ref}', which is not a parameter of this step.",
                            did_you_mean=_suggest(ref, names_in_step),
                        )

        code = _pick(step, "code", default="")
        if code and kind == "CUSTOM" and "%afi_caf_postprocess" not in code and "%anl_driver" not in code:
            add(
                "warning",
                where,
                "code declares no outputs: without %afi_caf_postprocess (or %anl_driver) nothing "
                "is promoted to QASANLOUT and every template token stays unresolved.",
            )

    for interaction in _pick(spec, "interactions", default=[]):
        iname = _pick(interaction, "name", default="?")
        where = f"interaction '{iname}'"
        source = _pick(interaction, "source_param", "sourceParamName", default="")
        if source and source not in declared:
            # A warning: several shipped packages carry interactions left behind
            # by a renamed parameter (HVAC fires on 'p_targetnmx', which does not
            # exist). They are dead rather than broken — the interaction simply
            # never fires — so this is a smell to report, not a blocker.
            add(
                "warning",
                where,
                f"sourceParamName '{source}' matches no declared parameter, so this interaction "
                "can never fire. Usually a parameter that was renamed.",
                did_you_mean=_suggest(source, declared),
            )
        combinator = _pick(interaction, "combinator", default="AND")
        if combinator not in {"AND", "OR"}:
            add("error", where, f"combinator '{combinator}' must be AND or OR.")
        expressions = " ".join(
            str(_pick(a, "expression", "action", default="") if isinstance(a, dict) else a)
            for a in _pick(interaction, "actions", default=[])
        )
        text = f"{_pick(interaction, 'condition', default='')} {expressions}"
        for method in re.findall(r"#?ctx\.(\w+)\s*\(", text):
            if method not in CTX_METHODS:
                add(
                    "error",
                    where,
                    f"#ctx.{method}() is not a known method; the UI silently does nothing for it.",
                    did_you_mean=_suggest(method, CTX_METHODS),
                )
        # A cascade that re-fetches its own source parameter re-triggers itself.
        if source and f"fetchPossibleValues('{source}')" in expressions.replace('"', "'"):
            add(
                "warning",
                where,
                f"this interaction fires on '{source}' and re-fetches '{source}', which re-triggers it. "
                "Guard with #ctx.getChangedParamName() or drop the self-fetch.",
            )

    issues.extend(check_tokens(spec))
    return issues


def _validate_lookup(lookup: dict[str, Any], where: str) -> list[dict[str, Any]]:
    issues: list[dict[str, Any]] = []
    kind = _pick(lookup, "type")
    if kind is not None and kind not in LOOKUP_TYPES:
        issues.append(
            {
                "severity": "error",
                "where": where,
                "message": f"lookup type '{kind}' must be RESTAPI, CASTABLE, or omitted "
                "(omitted = a reference to a shared platform lookup by id).",
            }
        )
    rest = _pick(lookup, "rest") or {}
    cas = _pick(lookup, "cas_table") or {}
    interpolating = "{{" in str(_pick(rest, "uri", default="")) or "{{" in str(_pick(cas, "where", default=""))
    resolve_on_ui = str((_pick(lookup, "properties", default={}) or {}).get("RESOLVEONUI", "")).lower() == "true"
    if interpolating and not resolve_on_ui:
        # A warning, not an error: plenty of shipped lookups interpolate without
        # it and work, because a cascade that re-fetches them on every change of
        # the source parameter never sees a stale value. It is the fix when a
        # picker shows values for the previously selected parent.
        issues.append(
            {
                "severity": "warning",
                "where": where,
                "message": "this lookup interpolates another parameter's value without setting "
                "RESOLVEONUI=true. If the picker shows values for the PREVIOUS selection, that "
                "is why — the lookup resolved server-side against a stale value. Add "
                "properties={'RESOLVEONUI': 'true'}, or make sure an interaction re-fetches it.",
            }
        )
    if kind == "CASTABLE" and cas and not _pick(cas, "table"):
        issues.append({"severity": "error", "where": where, "message": "CASTABLE lookup needs a table name."})
    if kind == "RESTAPI" and rest and not _pick(rest, "uri"):
        issues.append({"severity": "error", "where": where, "message": "RESTAPI lookup needs a URI."})
    return issues


def blocking(issues: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """The subset of *issues* that must be fixed before an upload is worth attempting."""
    return [i for i in issues if i.get("severity") == "error"]


# --- summaries ---------------------------------------------------------------


def summarize_package(package: dict[str, Any]) -> dict[str, Any]:
    """Describe an unpacked package without returning its bytes.

    Templates run to hundreds of kilobytes; a caller almost always wants the
    shape, the tokens and the parameter list rather than the XML.
    """
    spec = package["spec"]
    steps = []
    for step in spec["steps"]:
        template = package["templates"].get(template_filename(step["id"])[: -len(TEMPLATE_SUFFIX)], "")
        produced = code_tokens(step.get("code", ""))
        steps.append(
            {
                "id": step["id"],
                "display_name": step["display_name"],
                "order": step["order"],
                "parameters": [
                    {
                        "name": p["name"],
                        "display_text": p["display_text"],
                        "control": p["display_control"],
                        "data_type": p["data_type"],
                        "lookup": (p.get("lookup") or {}).get("type") or ("shared" if p.get("lookup") else None),
                    }
                    for p in step["parameters"]
                ],
                "code_lines": len((step.get("code") or "").splitlines()),
                "publishes": sorted(produced["tables"] | produced["variables"] | produced["explicit"]),
                "template_chars": len(template),
                "template_tokens": sorted(template_tokens(template)),
            }
        )
    return {
        "name": spec["name"],
        "display_name": spec["display_name"],
        "description": spec["description"],
        "type": spec["type"],
        "key_group": spec["key_group"],
        "active": spec["active"],
        "data_selection_required": spec["data_selection_required"],
        "folder": package["folder"],
        "steps": steps,
        "interactions": [
            {
                "name": i["name"],
                "source_param": i["source_param"],
                "has_condition": bool(i["condition"].strip()),
                "actions": [a["expression"] for a in i["actions"]],
            }
            for i in spec["interactions"]
        ],
    }


def describe(topic: str | None = None, control: str | None = None) -> dict[str, Any]:
    """Progressive disclosure over the CAF format.

    No arguments gives the index; *topic* gives one layer in depth; *control*
    documents one display control. This is what lets a model author a package
    correctly without the whole format in context.
    """
    if control is not None:
        if control not in DISPLAY_CONTROLS:
            return {
                "status": "unknown_control",
                "control": control,
                "valid_controls": sorted(DISPLAY_CONTROLS),
                "did_you_mean": _suggest(control, DISPLAY_CONTROLS),
            }
        entry: dict[str, Any] = {
            "control": control,
            "purpose": DISPLAY_CONTROLS[control],
            "data_type": "Array" if control in ARRAY_CONTROLS else "String",
        }
        if control in ARRAY_CONTROLS:
            entry["note"] = "Multi-value: declare dataType='Array' or only the last selection survives."
        if control == "NUMERICSTEPPER":
            entry["properties"] = {"min": PROPERTY_KEYS["min"], "max": PROPERTY_KEYS["max"]}
            entry["note"] = (
                "The corpus declares these as dataType='String' with min/max properties rather "
                "than Integer/Float; the value reaches SAS as text either way."
            )
        if control == "STABLEPERIOD":
            entry["requires"] = (
                "A CASTABLE lookup whose key column is the time variable and whose value "
                "column is the measure being scoped."
            )
        return entry

    if topic is None:
        return topic_index()

    topics: dict[str, dict[str, Any]] = {
        "overview": {
            "what": "An AIoT analysis TYPE is a zip: <NAME>/input.xml plus one "
            "<STEP_ID>_vaoutput.template per visualizing step. input.xml holds the input form, "
            "the UI interactions and the SAS code; the template holds the Visual Analytics "
            "report, with {{.TOKEN}} slots where the runtime table names go.",
            "three_languages": {
                "interactions": "SpEL against a #ctx root object (topic='interactions')",
                "lookups": "Go text/template over the live form values (topic='lookups')",
                "output": "Go text/template over the step's output params (topic='output')",
            },
            "next": "topic='package' for the layout, topic='tokens' for the part most often got wrong.",
        },
        "package": {
            "layout": ["<NAME>/input.xml", "<NAME>/<STEP_ID>_vaoutput.template"],
            "rules": [
                "The folder name must equal <Registration><Name>.",
                "The template filename comes from the STEP ID, not <TemplateID>: strip a "
                "trailing _DEFAULT, append _vaoutput.template.",
                "Step @order need not be contiguous and steps do not chain declaratively — "
                "they chain through published output params at runtime.",
                "<ZipHash> is empty in every shipped package; nothing needs hashing.",
            ],
            "element_order": [
                "Registration (Name, DisplayName, Description, KeyGroup, ModifiedTime)",
                "Steps (Step -> TemplateID, Parameters, Containers, Code)",
                "Interactions",
                "ZipModifiedAt",
                "ZipHash",
            ],
        },
        "registration": {
            "type": sorted(ANALYSIS_TYPES),
            "key_group": sorted(KEY_GROUPS),
            "fields": {
                "name": "Uppercase identifier. Also the folder name and the prefix of every "
                "promoted output table.",
                "display_name": "What the user sees in the analysis-type picker.",
                "data_selection_required": "true if the analysis must run against a data selection.",
                "active": "false hides the type from users without deleting it.",
            },
        },
        "parameters": {
            "attributes": [
                "name", "display_text", "required", "visible", "order", "data_type", "display_control",
            ],
            "display_controls": DISPLAY_CONTROLS,
            "data_types": sorted(DATA_TYPES),
            "properties": PROPERTY_KEYS,
            "reserved_names": "__DATASELECTIONID__, __DATASELCREATIONTYPE__, __ANALYSISNAME__, "
            "__VECHILDANALYSIS__ are filled in by the framework — declare one to receive it.",
            "in_sas": "A parameter p_x arrives as the macro variable &g_p_x: 'g_' prefix, name verbatim.",
            "notes": [
                "<Properties> and <UIGroup> are required on every parameter, even empty.",
                "displayControl='' is a hidden constant: no widget, but the default value "
                "still reaches the code.",
                "There is no <Validations> element. #ctx.addValidationError is the whole "
                "validation mechanism.",
            ],
        },
        "lookups": {
            "modes": {
                "RESTAPI": "Inline: <Rest> with Method, URI, Headers, resKeyName, resValueName. "
                "The URI is a Go template over the live form values.",
                "CASTABLE": "Inline: <CASTable> with LibraryName, TableName, KeyColumnName, "
                "ValueColumnName, WhereCondition. The WhereCondition is a Go template.",
                "reference": "No type attribute and no payload: a reference to a shared platform "
                "lookup by id. About 70% of the corpus.",
                "static": "No lookup at all — <PossibleValues><Values key= value=/> instead.",
            },
            "functions": TEMPLATE_FUNCTIONS,
            "critical": "A lookup that interpolates another parameter's value MUST set "
            "RESOLVEONUI=true, or it resolves server-side against a stale value.",
            "escaping": "The WhereCondition lives in XML: write <> as &lt;&gt;.",
        },
        "containers": {
            "grammar": "Containers -> Container[type=TAB] -> Container[type=FORM] -> FormItem. "
            "Two levels, no more.",
            "form_item": "ref names a parameter. ref='' with type='INLINE' is a section divider.",
            "note": "Form order is what the UI renders; a parameter's own order attribute does "
            "not reorder a laid-out form.",
            "default": "Omit containers and one TAB per distinct ui_group.tab is generated, "
            "holding that tab's parameters in declaration order.",
        },
        "interactions": {
            "language": "SpEL, evaluated against a #ctx root object. Only a small subset of the "
            "grammar appears: #ctx method calls, == and !=, && and ||, and the ternary.",
            "scope": "<Interactions> is MODEL-level, not per-step. Scope to a step with "
            "#ctx.getCurrentStep().",
            "shape": "name, sourceParamName, modelName, combinator, Order; a <Condition> (empty "
            "means always) and one or more <Action> blocks, each with a <ConditionResult> that "
            "says which branch it is. ConditionResult=false is the else-branch.",
            "separators": "Several statements in one action are separated by a newline (CUSTOM "
            "types) or a '|' (STANDARD types). Both are accepted.",
            "methods": CTX_METHODS,
            "cascade_pattern": "An interaction on p_a whose action is "
            "#ctx.fetchPossibleValues('p_b') is how a picker cascades. Never re-fetch the "
            "source parameter itself — it re-triggers the interaction.",
        },
        "code": {
            "skeleton": "%afi_caf_loadmacros(...); %afi_caf_preprocess(?g_cas, ?analysisID); "
            "<logic>; <output contract>; %afi_caf_postprocess;",
            "standard_types": "A shipped STANDARD type is one line: %anl_driver.",
            "substitutions": "?g_cas, ?analysisID, ?g_metadata, ?limit, ?append, ?filter are "
            "replaced by the mid-tier ONCE, case-sensitively, at the FIRST occurrence — "
            "including inside a comment. Never name one in a comment.",
            "macros": "The framework sets g_caslib, g_analysis_id, g_analysis_short_id, "
            "g_analysis_type, g_step_id, g_output_caslib before the code runs.",
            "limits": "A macro variable caps at 64KB. Write longer payloads to a file and %include it.",
            "next": "topic='tokens' for how the output contract feeds the report template.",
        },
        "output": {
            "format": "Visual Analytics BIRD XML, with Go template tokens in place of table names.",
            "how_to_get_one": "Do NOT write BIRD XML by hand. Build the report in VA (or with "
            "the Tier 3 report tools), read it back as XML, then tokenize it — that is what "
            "templatize_va_report does.",
            "minimum": "A step that computes but does not visualize still needs a template file; "
            "the minimal legal report is available from the create tools as the default.",
            "structure": "SASReport -> DataSources, DataDefinitions, VisualElements, View, "
            "MediaSchemes, MediaTargets. Symbols are dsN/ddN/biN/veN/viN/prN and "
            "nextUniqueNameIndex must exceed every number used.",
            "layout_hazard": "Every <Weights> block's <Weight> count must equal its container's "
            "child count, for every media target. A mismatch renders the page blank.",
            "functions": TEMPLATE_FUNCTIONS,
        },
        "tokens": {
            "rule": "An output param named X is readable in the template as {{.X}}. That is the "
            "entire name mapping.",
            "sas_side": [
                "Declarative: %let g_num_output_tables = 2; %let g_output_table_1 = work.SAMPLE; "
                "... %afi_caf_postprocess; — publishes the BARE MEMBER NAME (SAMPLE), and promotes "
                "the table into QASANLOUT as <ANALYSIS_TYPE>_SAMPLE_<SHORT_ID>.",
                "Explicit: POST {'analysisStepOutputParams':[{'outputname':'X','outputvalue':'...'}]} "
                "to /iotAnalysis/analyses/{id}/steps/{stepId}/outputParams. ?append=false replaces "
                "the existing set instead of merging into it.",
            ],
            "xml_side": [
                'CasResource/@table="{{.SAMPLE}}" — the physical table slot.',
                'DataSource/@label="{{.SAMPLE}}" — the design-time label. BOTH must be tokenized.',
                'DataItem/@xref="{{.COL1}}" — a column slot, when the columns vary per run.',
            ],
            "positional": "STANDARD types use {{.OUTPUTTABLENAME1}}..{{.OUTPUTTABLENAME29}} "
            "instead of base names; the framework fills those in by position.",
            "failure_mode": "A token with no producer renders a BLANK report and reports NO error. "
            "validate_analysis_type_spec checks this before you ship.",
            "case": "Token case must match the published name exactly.",
        },
        "gotchas": {"ranked": list(GOTCHAS)},
    }

    if topic not in topics:
        return {
            "status": "unknown_topic",
            "topic": topic,
            "valid_topics": list(TOPICS),
            "did_you_mean": _suggest(topic, TOPICS),
        }
    return {"topic": topic, **topics[topic]}


# --- the one impure part -----------------------------------------------------


async def upload_package(
    client: httpx.AsyncClient,
    url: str,
    data: bytes,
    filename: str,
    *,
    method: str = "POST",
) -> dict[str, Any]:
    """Upload an analysis-type zip, resolving the undocumented request encoding.

    The published OpenAPI spec for ``POST /iotAnalysisModels/models`` and
    ``PUT /iotAnalysisModels/models/{name}`` documents no ``requestBody`` media
    type, only that the body "must contain a valid ZIP file". Deployments have
    been seen to want either a ``multipart/form-data`` part or a raw
    ``application/zip`` body, and the two are indistinguishable from the
    contract, so both are attempted in order and whichever the service accepts
    wins. A 4xx that is specifically about the encoding falls through to the next
    strategy; any other failure is raised with Viya's own message attached.
    """
    full_url = f"{VIYA_ENDPOINT}{url}"
    attempts: list[dict[str, Any]] = []

    for strategy in UPLOAD_STRATEGIES:
        if strategy == "multipart":
            request = client.build_request(
                method,
                full_url,
                files={"file": (filename, data, "application/zip")},
                headers={"Accept": "application/json"},
            )
        else:
            request = client.build_request(
                method,
                full_url,
                content=data,
                headers={"Content-Type": "application/zip", "Accept": "application/json"},
            )
        resp = await client.send(request)
        if resp.status_code < 400:
            body: dict[str, Any] = {}
            if resp.content and resp.headers.get("content-type", "").startswith("application/json"):
                body = resp.json()
            return {"status": "ok", "http_status": resp.status_code, "encoding": strategy, "response": body}
        attempts.append({"encoding": strategy, "http_status": resp.status_code, "detail": resp.text[:500]})
        # A 403 here is not a package problem, and it is easy to misread as a
        # missing group. On the reference deployment it is not one: the same
        # identity can POST /iotAnalysisModels/lookups and reach validation (400),
        # yet POST /models answers "not authorized to execute this api upsert
        # embeded models" — so this endpoint enforces something beyond the
        # /iotAnalysisModels/** authorization rules, which do grant writes.
        # Worth translating, because chasing group membership here wastes a day.
        if resp.status_code == 403:
            return {
                "status": "forbidden",
                "http_status": 403,
                "encoding": strategy,
                "message": (
                    "The service refused the write before parsing the package — nothing was "
                    "created. Check the deployment's /iotAnalysisModels/** authorization rules, "
                    "but note that a 403 on this endpoint specifically is not necessarily about "
                    "group membership: it has been seen to refuse identities that other writes "
                    "to the same service accept. If it persists, import through the AIoT UI."
                ),
                "detail": resp.text[:500],
            }
        # 415/400 reads as "wrong encoding"; anything else is a real rejection
        # (a bad package, a name clash) and retrying the other encoding would
        # only obscure it.
        if resp.status_code not in (400, 415):
            raise_for_viya_status(resp)

    return {
        "status": "failed",
        "message": (
            "The service rejected both upload encodings. This endpoint's request body type is "
            "undocumented; the attempts below record what each returned."
        ),
        "attempts": attempts,
    }
