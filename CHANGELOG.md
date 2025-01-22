= 1.4.0

 * Dependencies were updated to support latest gems, in particular both Rack 2.x and 3.x are now supported.

 * The inputs containing characters from Unicode Cf (Format) and Co (Private Use) categories are rejected as was intended.

 * More robust handling of inputs with invalid encoding:
   * Strings returned by `form_value` are now scrubbed so they don't cause errors when used in templates.
   * The hash keys with invalid encoding are now handled properly, too.

= 1.3.0

 * Further improvements for JSON payloads:
   * Added set of methods for distinguishing between set and unset parameters.
   * The `import` now properly handles parameters with `nil` and `false` values.
   * The `to_data` method now returns all set parameters, regardless of their value.

= 1.2.0

 * Few changes for easier import and export of JSON payloads:
   * The `import` and the new `from_data` methods now support numeric, boolean, and `nil` values natively.
   * Added `to_data` method which creates a hash of all non-`nil` parameters.

= 1.1.0

 * Added `report!` methods for late reporting of the most fundamental errors.

 * Added support for multiple `check` and `test` validation callbacks.

= 1.0.0

 * Initial release.
