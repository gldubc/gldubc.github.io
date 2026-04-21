# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec
#
# Adapted from:
#   lib/elixir/test/elixir/module/types/type_helper.exs
# in the Elixir 1.20.0-rc.4 source tree.

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

  defmacro precise?(patterns, guards \\ true) do
    quote do
      unquote(precise(patterns, guards, __CALLER__))
    end
  end

  defmacro typecheck!(patterns \\ [], guards \\ true, body) do
    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1200Rc4.__typecheck__!()
    end
  end

  defmacro typeerror!(patterns \\ [], guards \\ true, body) do
    [patterns, guards, body] = prune_columns([patterns, guards, body])

    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1200Rc4.__typeerror__!()
    end
  end

  defmacro typewarn!(patterns \\ [], guards \\ true, body) do
    [patterns, guards, body] = prune_columns([patterns, guards, body])

    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1200Rc4.__typewarn__!()
    end
  end

  def __typecheck__!({type, %{warnings: []}}), do: type

  def __typecheck__!({_type, %{warnings: warnings, failed: false}}),
    do: raise("type checking ok but with warnings: #{inspect(warnings)}")

  def __typecheck__!({_type, %{warnings: warnings, failed: true}}),
    do: raise("type checking errored with warnings: #{inspect(warnings)}")

  def __typeerror__!({_type, %{warnings: [{module, warning, _locs} | _], failed: true}}),
    do: module.format_diagnostic(warning).message

  def __typeerror__!({_type, %{warnings: warnings, failed: false}}),
    do: raise("type checking with warnings but expected error: #{inspect(warnings)}")

  def __typeerror__!({type, _}),
    do: raise("type checking ok but expected error: #{Descr.to_quoted_string(type)}")

  def __typewarn__!({type, %{warnings: [{module, warning, _locs}], failed: false}}),
    do: {type, module.format_diagnostic(warning).message}

  def __typewarn__!({type, %{warnings: []}}),
    do: raise("type checking ok without warnings: #{Descr.to_quoted_string(type)}")

  def __typewarn__!({_type, %{warnings: warnings, failed: false}}),
    do: raise("type checking ok but many warnings: #{inspect(warnings)}")

  def __typewarn__!({_type, %{warnings: warnings, failed: true}}),
    do: raise("type checking errored with warnings: #{inspect(warnings)}")

  def __precise__?(patterns, guards) do
    stack = new_stack(:static)
    expected = Enum.map(patterns, fn _ -> Descr.dynamic() end)
    init_previous = Pattern.init_previous()
    tag = {:fn, patterns}

    {_trees, _, previous, _context} =
      Pattern.of_head(patterns, guards, expected, init_previous, tag, [], stack, new_context())

    previous != init_previous
  end

  def __typecheck__(mode, patterns, guards, body) do
    stack = new_stack(mode)
    expected = Enum.map(patterns, fn _ -> Descr.dynamic() end)
    previous = Pattern.init_previous()
    tag = {:fn, patterns}

    {_trees, _, _, context} =
      Pattern.of_head(patterns, guards, expected, previous, tag, [], stack, new_context())

    Expr.of_expr(body, Descr.term(), :ok, stack, context)
  end

  @strip_ansi [IO.ANSI.green(), IO.ANSI.red(), IO.ANSI.reset()]

  def strip_ansi(doc) do
    String.replace(doc, @strip_ansi, "")
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

  defp precise(patterns, guards, env) do
    {_, vars} =
      Macro.prewalk(patterns, [], fn
        {:"::", _, [left, _right]}, acc ->
          {left, acc}

        {name, _, ctx} = var, acc when is_atom(ctx) and name != :_ ->
          {var, [var | acc]}

        node, acc ->
          {node, acc}
      end)

    {patterns, guards, _body} = expand_and_unpack(patterns, guards, vars, env)

    quote do
      TypeHelper1200Rc4.__precise__?(
        unquote(Macro.escape(patterns)),
        unquote(Macro.escape(guards))
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

  defp prune_columns(ast) do
    Macro.prewalk(ast, fn node ->
      Macro.update_meta(node, &Keyword.delete(&1, :column))
    end)
  end
end
