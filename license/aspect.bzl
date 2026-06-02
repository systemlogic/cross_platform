"""Aspect that collects LicenseInfo through the transitive dependency graph.

The aspect propagates through deps, runtime_deps, and exports.  For each
target that carries LicenseInfo (i.e. a license_declaration) it serialises
the metadata to a JSON string and accumulates it in a string depset.
Depset semantics deduplicate equal strings automatically, so a library
reached via multiple paths is counted only once.
"""

load("//license:defs.bzl", "LicenseInfo")

LicensesInfo = provider(
    doc = "Accumulated license entries (JSON strings) from a target and its transitive deps.",
    fields = {
        "entries": "depset of JSON-encoded license-entry strings (one per licensed target)",
    },
)

_DEP_ATTRS = ["deps", "runtime_deps", "exports", "licenses"]

def _license_aspect_impl(target, ctx):
    # Gather entries from all relevant dep attributes transitively.
    transitive = []
    for attr_name in _DEP_ATTRS:
        for dep in getattr(ctx.rule.attr, attr_name, []):
            if LicensesInfo in dep:
                transitive.append(dep[LicensesInfo].entries)

    # If this target itself carries LicenseInfo, encode it as a JSON string.
    direct = []
    if LicenseInfo in target:
        info = target[LicenseInfo]
        direct.append(json.encode({
            "label": str(target.label),
            "spdx_id": info.spdx_id,
            "package_name": info.package_name,
            "package_version": info.package_version,
            "url": info.url,
            "copyright": info.copyright,
        }))

    return [LicensesInfo(entries = depset(direct, transitive = transitive))]

license_aspect = aspect(
    implementation = _license_aspect_impl,
    attr_aspects = _DEP_ATTRS,
    doc = "Propagates through deps/runtime_deps/exports collecting LicenseInfo providers.",
)
