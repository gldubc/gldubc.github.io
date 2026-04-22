# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec
#
# Adapted from:
#   lib/elixir/test/elixir/module/types/type_helper.exs
# in the Elixir 1.20.0-rc.4 source tree.
#
# Run with:
#   elixir guard_negation_examples_elixir_1.20.0_rc4.exs

Application.put_env(:elixir, :ansi_enabled, true)
Code.compiler_options(debug_info: true, infer_signatures: [:elixir])

unless Process.whereis(ExUnit.Server) do
  ExUnit.start(exclude: [windows: true, distributed: true])
end

defmodule TypesTest1200Rc4 do
end

defmodule TypeHelper1200Rc4 do
  alias Module.Types
  alias Module.Types.{Descr, Expr, Pattern}

  defmacro typecheck!(patterns \\ [], guards \\ true, body) do
    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1200Rc4.__typecheck__!()
    end
  end

  def __typecheck__!({type, %{warnings: []}}), do: type

  def __typecheck__!({_type, %{warnings: warnings, failed: false}}),
    do: raise("type checking ok but with warnings: #{inspect(warnings)}")

  def __typecheck__!({_type, %{warnings: warnings, failed: true}}),
    do: raise("type checking errored with warnings: #{inspect(warnings)}")

  def __typecheck__(mode, patterns, guards, body) do
    stack = new_stack(mode)
    expected = Enum.map(patterns, fn _ -> Descr.dynamic() end)
    previous = Pattern.init_previous()
    tag = {:fn, patterns}

    {_trees, _, _, context} =
      Pattern.of_head(patterns, guards, expected, previous, tag, [], stack, new_context())

    Expr.of_expr(body, Descr.term(), :ok, stack, context)
  end

  defp typecheck(mode, patterns, guards, body, env) do
    {patterns, guards, body} = expand_and_unpack(patterns, guards, body, env)

    quote do
      TypeHelper1200Rc4.__typecheck__(
        unquote(mode),
        unquote(Macro.escape(patterns)),
        unquote(Macro.escape(guards)),
        unquote(Macro.escape(body))
      )
    end
  end

  defp expand_and_unpack(patterns, guards, body, env) do
    fun =
      quote do
        fn unquote_splicing(patterns) when unquote(guards) -> unquote(body) end
      end

    {ast, _, _} = :elixir_expand.expand(fun, :elixir_env.env_to_ex(env), env)
    {:fn, _, [{:->, _, [[{:when, _, args}], body]}]} = ast
    {patterns, [guards]} = Enum.split(args, -1)
    {patterns, flatten_when(guards), body}
  end

  defp flatten_when({:when, _meta, [left, right]}), do: [left | flatten_when(right)]
  defp flatten_when(other), do: [other]

  defp new_stack(mode) do
    cache =
      if mode == :infer do
        :none
      else
        {:ok, cache} = Module.ParallelChecker.start_link()
        cache
      end

    handler = fn _, fun_arity, _, _ -> raise "no local lookup for: #{inspect(fun_arity)}" end
    Types.stack(mode, "types_test.ex", TypesTest1200Rc4, {:test, 0}, [], cache, handler)
  end

  defp new_context() do
    Types.context()
  end
end

defmodule GuardNegationExamples1200Rc4Test do
  use ExUnit.Case, async: false

  require TypeHelper1200Rc4
  import TypeHelper1200Rc4

  defp quoted(type) do
    Module.Types.Descr.to_quoted_string(type)
  end

  test "tracks missing map keys through negation" do
    assert quoted(typecheck!([x], not is_map_key(x, :foo), x)) ==
             "dynamic(%{..., foo: not_set()})"
  end

  test "recovers an exact binary tuple by negating an inequality" do
    assert quoted(typecheck!([x], not (tuple_size(x) != 2), x)) ==
             "dynamic({term(), term()})"
  end

  test "recovers a non-empty map by negating emptiness" do
    assert quoted(typecheck!([x], not (map_size(x) == 0), x)) ==
             "dynamic(map() and not empty_map())"
  end

  test "recovers the empty list by negating non-emptiness" do
    assert quoted(typecheck!([x], not (length(x) != 0), x)) == "empty_list()"
  end

  test "recovers a non-empty list by negating an upper bound" do
    assert quoted(typecheck!([x], not (length(x) <= 0), x)) ==
             "dynamic(non_empty_list(term()))"
  end

  test "recovers tuples of arity three or more by negating a size upper bound" do
    assert quoted(typecheck!([x], not (tuple_size(x) <= 2), x)) ==
             "dynamic({term(), term(), term(), ...})"
  end

  test "pushes negation through tuple selector truthiness" do
    assert quoted(typecheck!([x], not elem(x, 1), x)) ==
             "dynamic({term(), false, ...})"
  end

  test "pushes negation through field truthiness" do
    assert quoted(typecheck!([x = %{foo: :bar}], not x.bar, x)) ==
             "dynamic(%{..., bar: false, foo: :bar})"
  end

  test "excludes a finite atom set with not in" do
    assert quoted(typecheck!([x], x not in [:foo, :bar], x)) ==
             "dynamic(not :bar and not :foo)"
  end

  test "keeps both domains live under a negated size disjunction" do
    assert quoted(typecheck!([x, y, z], not (length(x) == z or map_size(y) == z), {x, y})) ==
             "dynamic({list(term()), map()})"
  end
end
