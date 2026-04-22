# Loaded automatically by the Elixir 1.19.5 example files.

Application.put_env(:elixir, :ansi_enabled, true)
Code.compiler_options(debug_info: true, infer_signatures: [:elixir])

unless Process.whereis(ExUnit.Server) do
  ExUnit.start(exclude: [windows: true, distributed: true])
end

defmodule TypesTest1195 do
end

defmodule TypeHelper1195 do
  alias Module.Types
  alias Module.Types.{Descr, Expr, Pattern}

  defmacro typecheck!(patterns \\ [], guards \\ true, body) do
    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1195.__typecheck__!()
    end
  end

  defmacro typeerror!(patterns \\ [], guards \\ true, body) do
    [patterns, guards, body] = prune_columns([patterns, guards, body])

    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1195.__typeerror__!()
    end
  end

  defmacro typewarn!(patterns \\ [], guards \\ true, body) do
    [patterns, guards, body] = prune_columns([patterns, guards, body])

    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1195.__typewarn__!()
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
    do: {:no_error, warnings}

  def __typeerror__!({type, _}),
    do: {:no_error, Descr.to_quoted_string(type)}

  def __typewarn__!({type, %{warnings: [{module, warning, _locs}], failed: false}}),
    do: {type, module.format_diagnostic(warning).message}

  def __typewarn__!({type, %{warnings: []}}),
    do: raise("type checking ok without warnings: #{Descr.to_quoted_string(type)}")

  def __typewarn__!({_type, %{warnings: warnings, failed: false}}),
    do: raise("type checking ok but many warnings: #{inspect(warnings)}")

  def __typewarn__!({_type, %{warnings: warnings, failed: true}}),
    do: raise("type checking errored with warnings: #{inspect(warnings)}")

  def __typecheck__(mode, patterns, guards, body) do
    stack = new_stack(mode)
    expected = Enum.map(patterns, fn _ -> Descr.dynamic() end)

    {_trees, context} =
      Pattern.of_head(patterns, guards, expected, :default, [], stack, new_context())

    Expr.of_expr(body, Descr.term(), :ok, stack, context)
  end

  defp typecheck(mode, patterns, guards, body, env) do
    {patterns, guards, body} = expand_and_unpack(patterns, guards, body, env)

    quote do
      TypeHelper1195.__typecheck__(
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
    {patterns, guards} = Enum.split(args, -1)
    {patterns, guards, body}
  end

  defp new_stack(mode) do
    cache = if mode == :infer, do: :none, else: Module.ParallelChecker.test_cache()
    handler = fn _, fun_arity, _, _ -> raise "no local lookup for: #{inspect(fun_arity)}" end
    Types.stack(mode, "types_test.ex", TypesTest1195, {:test, 0}, [], cache, handler)
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
