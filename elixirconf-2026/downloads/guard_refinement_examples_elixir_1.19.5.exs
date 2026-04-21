# Run with:
#   elixir guard_refinement_examples_elixir_1.19.5.exs

Application.put_env(:elixir, :ansi_enabled, true)
Code.compiler_options(debug_info: true, infer_signatures: [:elixir])

unless Process.whereis(ExUnit.Server) do
  ExUnit.start(exclude: [windows: true, distributed: true])
end

defmodule TypesTest do
end

defmodule Point do
  defstruct [:x, :y, z: 0]
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
    Types.stack(mode, "types_test.ex", TypesTest, {:test, 0}, [], cache, handler)
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

module_ast =
  quote do
    defmodule GuardRefinementExamples1195SharedTest do
      use ExUnit.Case, async: false

      require TypeHelper1195
      import TypeHelper1195

      defp quoted(type) do
        Module.Types.Descr.to_quoted_string(type)
      end

      defp compile_modules(files) do
        previous_cwd = File.cwd!()
        directory = Path.join(System.tmp_dir!(), "guard_refinement_old_#{System.unique_integer([:positive])}")

        File.rm_rf!(directory)
        File.mkdir_p!(directory)
        File.cd!(directory)

        try do
          paths =
            for {file, contents} <- files do
              File.write!(file, contents)
              file
            end

          {:ok, modules, warnings} =
            Kernel.ParallelCompiler.compile_to_path(paths, ".", return_diagnostics: true)

          assert warnings == %{compile_warnings: [], runtime_warnings: []}

          binaries =
            Map.new(modules, fn module ->
              {^module, binary, _filename} = :code.get_object_code(module)
              {module, binary}
            end)

          Enum.each(modules, fn module ->
            :code.purge(module)
            :code.delete(module)
          end)

          binaries
        after
          File.cd!(previous_cwd)
          File.rm_rf!(directory)
        end
      end

      defp inferred_signature(binary, name, arity) do
        assert {:ok, {_module, [{~c"ExCk", chunk}]}} = :beam_lib.chunks(binary, [~c"ExCk"])
        {_version, %{exports: exports}} = :erlang.binary_to_term(chunk)

        pair = {name, arity}
        {^pair, %{sig: {:infer, domain, clauses}}} = List.keyfind(exports, pair, 0)
        {domain, clauses}
      end

      test "this already worked: plain head patterns could preserve whole-value shape" do
        assert quoted(typecheck!([{:ok, x}], true, {:ok, x})) == "dynamic({:ok, term()})"
      end

      test "collapses complex tuple guards to dynamic" do
        assert quoted(
                 typecheck!(
                   [x],
                   tuple_size(x) == 2 and
                     ((elem(x, 0) == :data and is_binary(elem(x, 1))) or
                        (elem(x, 0) == :halt and elem(x, 1) == :normal)),
                   x
                 )
               ) == "dynamic()"
      end

      test "collapses complex map guards to dynamic" do
        assert quoted(
                 typecheck!(
                   [x],
                   (x.kind == :file and is_binary(x.path)) or
                     (x.kind == :fd and is_integer(x.fd)),
                   x
                 )
               ) == "dynamic()"
      end

      test "does not refine non-precise local guard information yet" do
        assert quoted(typecheck!([x], hd(x) == :ok, x)) == "dynamic()"
      end

      test "does not keep residual information across guarded clauses" do
        assert quoted(
                 typecheck!(
                   [reply],
                   true,
                   case reply do
                     {:ok, value} when is_binary(value) -> {:text, value}
                     {:ok, value} -> {:other, value}
                   end
                 )
               ) == "dynamic({:other or :text, term()})"
      end

      test "does not propagate guard refinements through variable dependencies" do
        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) -> pair
                   end
                 )
               ) == "dynamic()"

        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) -> elem(pair, 0)
                   end
                 )
               ) == "dynamic()"

        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) -> elem(pair, 1)
                   end
                 )
               ) == "dynamic()"
      end

      test "misses selector misuse when dependency information is not propagated" do
        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) -> String.length(elem(pair, 0))
                   end
                 )
               ) == "dynamic()"
      end

      test "does not use complex guard refinements to reject contradicted code yet" do
        assert quoted(
                 typecheck!(
                   [x],
                   tuple_size(x) == 2 and
                     ((elem(x, 0) == :data and is_binary(elem(x, 1))) or
                        (elem(x, 0) == :halt and elem(x, 1) == :normal)),
                   elem(x, 1) + 1
                 )
               ) == "float() or integer()"
      end

      test "does not reject impossible guards yet" do
        assert typeerror!([x], is_pid(x) and is_atom(x), x) == {:no_error, []}
      end

      test "does not warn about repeated guarded tuple clauses" do
        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) and is_integer(y) -> {:ints, x, y}
                     {x, y} when is_integer(x) and is_integer(y) -> {:again, x, y}
                   end
                 )
               ) == "dynamic({:again or :ints, term(), term()})"
      end

      test "does not refine exported domains from successful stdlib calls yet" do
        modules =
          compile_modules(%{
            "reverse_arrow_demo.ex" => """
            defmodule ReverseArrowDemo do
              def render_tagged({:int, value}), do: Integer.to_string(value)
              def render_tagged({:not_int, value}), do: {:not_int, value}
            end
            """
          })

        {domain, clauses} = inferred_signature(modules[ReverseArrowDemo], :render_tagged, 1)

        assert Enum.map(domain, &quoted/1) == ["dynamic({:int or :not_int, term()})"]

        assert Enum.map(clauses, fn {[argument], return} ->
                 {quoted(argument), quoted(return)}
               end) == [
                 {"dynamic({:int, term()})", "binary()"},
                 {"dynamic({:not_int, term()})", "dynamic({:not_int, term()})"}
               ]
      end
    end
  end

Code.eval_quoted(module_ast)
