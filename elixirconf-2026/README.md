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

For the `1.20.0-rc.4` snapshot, activate that Elixir version and run:

```bash
elixir guard_negation_examples_elixir_1.20.0_rc4.exs
elixir guard_refinement_examples_elixir_1.20.0_rc4.exs
```

Each example starts the same way: `elixir <file>.exs`.
The `1.19.5` files load a local helper, while the `1.20.0-rc.4` files are fully self-contained.

## Files

- `downloads/type_helper_elixir_1.19.5.exs`
- `downloads/guard_negation_examples_elixir_1.19.5.exs`
- `downloads/guard_refinement_examples_elixir_1.19.5.exs`
- `downloads/guard_negation_examples_elixir_1.20.0_rc4.exs`
- `downloads/guard_refinement_examples_elixir_1.20.0_rc4.exs`

## Attribution

The helper code embedded in the `1.20.0-rc.4` files is adapted from Elixir test
code by the Elixir Team and Plataformatec, distributed under Apache-2.0. Those
files keep the upstream SPDX notices in their headers.
