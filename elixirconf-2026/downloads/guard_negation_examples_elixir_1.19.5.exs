# Run with:
#   elixir guard_negation_examples_elixir_1.19.5.exs

Application.put_env(:elixir, :ansi_enabled, true)
Code.compiler_options(debug_info: true, infer_signatures: [:elixir])

unless Process.whereis(ExUnit.Server) do
  ExUnit.start(exclude: [windows: true, distributed: true])
end

defmodule TypesTest do
end

defmodule TypeHelper1195 do
  alias Module.Types
  alias Module.Types.{Pattern, Expr, Descr}

  defmacro typecheck!(patterns \\ [], guards \\ true, body) do
    quote do
      unquote(typecheck(:static, patterns, guards, body, __CALLER__))
      |> TypeHelper1195.__typecheck__!()
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

    {_trees, context} =
      Pattern.of_head(patterns, guards, expected, :default, [], stack, Types.context())

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
    Types.stack(mode, "types_test.ex", TypesTest, {:test, 0}, [], cache, handler)
  end
end

module_ast =
  quote do
    defmodule GuardNegationExamples1195SharedTest do
      use ExUnit.Case, async: false

      require TypeHelper1195
      import TypeHelper1195

      defp quoted(type) do
        Module.Types.Descr.to_quoted_string(type)
      end

      test "does not track missing map keys through negation yet" do
        assert quoted(typecheck!([x], not is_map_key(x, :foo), x)) == "dynamic()"
      end

      test "does not recover an exact binary tuple by negating an inequality yet" do
        assert quoted(typecheck!([x], not (tuple_size(x) != 2), x)) == "dynamic()"
      end

      test "does not recover a non-empty map by negating emptiness yet" do
        assert quoted(typecheck!([x], not (map_size(x) == 0), x)) == "dynamic()"
      end

      test "does not recover the empty list by negating non-emptiness yet" do
        assert quoted(typecheck!([x], not (length(x) != 0), x)) == "dynamic()"
      end

      test "does not recover a non-empty list by negating an upper bound yet" do
        assert quoted(typecheck!([x], not (length(x) <= 0), x)) == "dynamic()"
      end

      test "does not recover tuples of arity three or more by negating a size upper bound yet" do
        assert quoted(typecheck!([x], not (tuple_size(x) <= 2), x)) == "dynamic()"
      end

      test "does not push negation through tuple selector truthiness yet" do
        assert quoted(typecheck!([x], not elem(x, 1), x)) == "dynamic()"
      end

      test "does not recover the false field fact under negation yet" do
        assert quoted(typecheck!([x = %{foo: :bar}], not x.bar, x)) ==
                 "dynamic(%{..., foo: :bar})"
      end

      test "does not exclude a finite atom set with not in yet" do
        assert quoted(typecheck!([x], x not in [:foo, :bar], x)) == "dynamic()"
      end

      test "does not keep both domains live under a negated size disjunction yet" do
        assert quoted(typecheck!([x, y, z], not (length(x) == z or map_size(y) == z), {x, y})) ==
                 "dynamic({term(), term()})"
      end
    end
  end

Code.eval_quoted(module_ast)
