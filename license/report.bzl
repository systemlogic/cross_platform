"""license_report and license_set rules.

license_report  — generates a human-readable license report for a Bazel artifact.
license_set     — groups multiple license_declaration targets for convenient reuse.

Example:

  load("//license:report.bzl", "license_report", "license_set")

  license_set(
      name = "java_grpc_deps",
      licenses = [
          "//license:grpc_java_api",
          "//license:protobuf_java",
          # …
      ],
  )

  license_report(
      name = "server_licenses",
      target = "//examples/java/grpc_server:server",
      artifact_name = "Java gRPC Server",
      deps_licenses = [":java_grpc_deps"],
  )

  # Build the report:
  #   bazel build //examples/java/grpc_server:server_licenses
  # Then read it:
  #   cat bazel-bin/examples/java/grpc_server/server_licenses_license_report.txt
"""

load("//license:aspect.bzl", "LicensesInfo", "license_aspect")

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _collect_entries(ctx):
    """Return a deduplicated list of decoded license-entry dicts."""
    raw = []
    if LicensesInfo in ctx.attr.target:
        raw += ctx.attr.target[LicensesInfo].entries.to_list()
    for lic in ctx.attr.deps_licenses:
        if LicensesInfo in lic:
            raw += lic[LicensesInfo].entries.to_list()

    seen = {}
    unique = []
    for s in raw:
        e = json.decode(s)
        key = e.get("label", s)
        if key not in seen:
            seen[key] = True
            unique.append(e)
    return unique

def _format_report(entries, artifact_name):
    """Return the report as a single string using pure Starlark."""
    by_license = {}
    for e in entries:
        spdx = e.get("spdx_id") or "UNKNOWN"
        if spdx not in by_license:
            by_license[spdx] = []
        by_license[spdx].append(e)

    sep = "=" * 70
    thin = "-" * 70

    lines = [
        sep,
        "  LICENSE REPORT  :  " + artifact_name,
        sep,
        "  Unique license types : %d" % len(by_license),
        "  Total packages       : %d" % len(entries),
        sep,
        "",
    ]

    for spdx in sorted(by_license.keys()):
        pkgs = sorted(
            by_license[spdx],
            key = lambda e: (e.get("package_name") or e.get("label", "")).lower(),
        )
        n = len(pkgs)
        lines.append("[ %s ]  (%d package%s)" % (spdx, n, "s" if n != 1 else ""))
        lines.append(thin)
        for e in pkgs:
            name = e.get("package_name") or e.get("label", "")
            ver = e.get("package_version") or ""
            display = ("  - " + name + " " + ver) if ver else ("  - " + name)
            lines.append(display)
            if e.get("copyright"):
                lines.append("      Copyright : " + e.get("copyright"))
            if e.get("url"):
                lines.append("      License   : " + e.get("url"))
            lines.append("      Bazel     : " + e.get("label", ""))
        lines.append("")

    lines.append(sep)
    return "\n".join(lines) + "\n"

# ---------------------------------------------------------------------------
# license_set
# ---------------------------------------------------------------------------

def _license_set_impl(ctx):
    # The license_aspect propagates through the "licenses" attribute automatically
    # (because "licenses" is in aspect.bzl's _DEP_ATTRS), so this rule does not
    # need to return LicensesInfo itself — the aspect adds it after the fact.
    return []

license_set = rule(
    implementation = _license_set_impl,
    attrs = {
        "licenses": attr.label_list(
            aspects = [license_aspect],
            doc = "license_declaration or license_set targets to bundle together.",
        ),
    },
    doc = "Groups multiple license_declaration targets for convenient reference in license_report.",
)

# ---------------------------------------------------------------------------
# license_report
# ---------------------------------------------------------------------------

def _license_report_impl(ctx):
    entries = _collect_entries(ctx)
    artifact_name = ctx.attr.artifact_name or str(ctx.attr.target.label)

    report = ctx.actions.declare_file(ctx.label.name + "_license_report.txt")
    ctx.actions.write(
        output = report,
        content = _format_report(entries, artifact_name),
    )
    return [
        DefaultInfo(files = depset([report])),
        OutputGroupInfo(license_report = depset([report])),
    ]

license_report = rule(
    implementation = _license_report_impl,
    attrs = {
        "target": attr.label(
            mandatory = True,
            aspects = [license_aspect],
            doc = "The artifact target whose full transitive dep tree is scanned.",
        ),
        "deps_licenses": attr.label_list(
            default = [],
            aspects = [license_aspect],
            doc = (
                "Explicit license_declaration or license_set targets for external " +
                "deps that are not auto-discovered (e.g. Maven JARs, pip packages)."
            ),
        ),
        "artifact_name": attr.string(
            default = "",
            doc = "Human-readable name shown in the report header. Defaults to target label.",
        ),
    },
    doc = "Generates a license compliance report for a Bazel artifact and all its dependencies.",
)
