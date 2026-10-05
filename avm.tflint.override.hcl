# `avm_azapi_resource_tags_required` as shipped in `tflint-ruleset-avm` v1.0.0 -- the version
# `Avm.Authoring` 0.17.0 pins -- required the tags attribute to be EXACTLY `tags = var.tags`
# on every AzAPI resource whose type supports tags.
#
# This module cannot satisfy that. `inbound_endpoints[*]`, `outbound_endpoints[*]` and
# `outbound_endpoints[*].forwarding_ruleset[*]` each expose `tags` and `merge_with_module_tags`,
# a released feature that lets a consumer tag an individual child resource and choose whether
# the module-level `var.tags` is merged in. The child resources therefore take
# `local.<x>_tags[each.key]`, which resolves to `var.tags` whenever the consumer sets no
# per-resource tags. `azapi_resource.this` still takes `tags = var.tags` literally.
#
# Upstream has already walked the strict check back: PR Azure/tflint-ruleset-avm#161,
# "feat(tags): support per-resource tag overrides", released in v1.1.0 on 2026-09-04, drops the
# literal-expression test and keeps the checks that matter -- tags must be set on a type that
# supports them, and must not be set on a type that does not.
#
# So rather than disabling the rule, this override moves the plugin to the release that
# supports this module's shape. Remove this file once `Avm.Authoring` pins v1.1.0 or later.
plugin "avm" {
  version = "1.1.0"
}
