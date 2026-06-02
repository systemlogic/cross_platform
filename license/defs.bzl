"""License metadata provider and declaration rule.

Usage:
  load("//license:defs.bzl", "license_declaration")

  license_declaration(
      name = "my_lib_license",
      spdx_id = "Apache-2.0",
      package_name = "my-lib",
      package_version = "1.2.3",
      url = "https://www.apache.org/licenses/LICENSE-2.0",
      copyright = "Copyright 2024, Example Corp.",
  )
"""

LicenseInfo = provider(
    doc = "License metadata for a Bazel target or known external dependency.",
    fields = {
        "spdx_id": "SPDX license identifier (e.g. 'Apache-2.0', 'MIT', 'BSD-3-Clause')",
        "url": "URL to the full license text",
        "copyright": "Copyright holder(s)",
        "package_name": "Human-readable package or library name",
        "package_version": "Package version string",
    },
)

def _license_declaration_impl(ctx):
    return [LicenseInfo(
        spdx_id = ctx.attr.spdx_id,
        url = ctx.attr.url,
        copyright = ctx.attr.copyright,
        package_name = ctx.attr.package_name if ctx.attr.package_name else ctx.label.name,
        package_version = ctx.attr.package_version,
    )]

license_declaration = rule(
    implementation = _license_declaration_impl,
    attrs = {
        "spdx_id": attr.string(
            mandatory = True,
            doc = "SPDX license identifier (https://spdx.org/licenses/).",
        ),
        "url": attr.string(
            default = "",
            doc = "Canonical URL to the full license text.",
        ),
        "copyright": attr.string(
            default = "",
            doc = "Copyright holder(s).",
        ),
        "package_name": attr.string(
            default = "",
            doc = "Human-readable package name. Defaults to the rule name.",
        ),
        "package_version": attr.string(
            default = "",
            doc = "Package version string.",
        ),
    },
    doc = "Declares license metadata for a package or known external dependency.",
)
