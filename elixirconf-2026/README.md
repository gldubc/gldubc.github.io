# ElixirConf 2026 Guard Analysis Tests

These files back the examples from "From Guards to Types" at ElixirConf 2026.

## Versions

- `Elixir 1.19.5`: released baseline used for the "before" results
- `Elixir 1.20.0-rc.4`: compiler snapshot used for the "current" results in the talk

## Run The Files

For the `1.19.5` baseline:

```bash
elixir guard_negation_examples_elixir_1.19.5.exs
elixir guard_refinement_examples_elixir_1.19.5.exs
```

For the `1.20.0-rc.4` snapshot:

```bash
/path/to/elixir-1.20.0-rc.4/bin/elixir guard_negation_examples_elixir_1.20.0_rc4.exs
/path/to/elixir-1.20.0-rc.4/bin/elixir guard_refinement_examples_elixir_1.20.0_rc4.exs
```

The `1.20.0-rc.4` files vendor a minimal helper adapted from Elixir's
`lib/elixir/test/elixir/module/types/type_helper.exs`.

## Files

- `downloads/guard_negation_examples_elixir_1.19.5.exs`
- `downloads/guard_refinement_examples_elixir_1.19.5.exs`
- `downloads/type_helper_elixir_1.20.0_rc4.exs`
- `downloads/guard_negation_examples_elixir_1.20.0_rc4.exs`
- `downloads/guard_refinement_examples_elixir_1.20.0_rc4.exs`

## Attribution

`type_helper_elixir_1.20.0_rc4.exs` is adapted from Elixir test code by the
Elixir Team and Plataformatec, distributed under Apache-2.0. The file keeps the
upstream SPDX notices in its header.
