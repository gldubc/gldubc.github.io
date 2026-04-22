# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2021 The Elixir Team
# SPDX-FileCopyrightText: 2012 Plataformatec
#
# Adapted from:
#   lib/elixir/test/elixir/module/types/type_helper.exs
# in the Elixir 1.20.0-rc.4 source tree.
#
# Run with:
#   elixir guard_refinement_examples_elixir_1.20.0_rc4.exs

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

defmodule GuardRefinementExamples1200Rc4Test do
  use ExUnit.Case, async: false

  require TypeHelper1200Rc4
  import TypeHelper1200Rc4

  defp quoted(type) do
    Module.Types.Descr.to_quoted_string(type)
  end

  defp clean(message) do
    TypeHelper1200Rc4.strip_ansi(message)
  end

  defp compile_modules(files) do
    previous_cwd = File.cwd!()
    directory = Path.join(System.tmp_dir!(), "guard_refinement_#{System.unique_integer([:positive])}")

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

  test "infers an exact tagged-union domain from a complex guard" do
    assert precise?(
             [x],
             tuple_size(x) == 2 and
               ((elem(x, 0) == :data and is_binary(elem(x, 1))) or
                  (elem(x, 0) == :halt and elem(x, 1) == :normal))
           )

    assert quoted(
             typecheck!(
               [x],
               tuple_size(x) == 2 and
                 ((elem(x, 0) == :data and is_binary(elem(x, 1))) or
                    (elem(x, 0) == :halt and elem(x, 1) == :normal)),
               x
             )
           ) == "dynamic({:data, binary()} or {:halt, :normal})"
  end

  test "infers an exact map-shaped domain from a complex guard" do
    assert precise?(
             [x],
             (x.kind == :file and is_binary(x.path)) or
               (x.kind == :fd and is_integer(x.fd))
           )

    assert quoted(
             typecheck!(
               [x],
               (x.kind == :file and is_binary(x.path)) or
                 (x.kind == :fd and is_integer(x.fd)),
               x
             )
           ) ==
             "dynamic(%{..., fd: integer(), kind: :fd} or %{..., kind: :file, path: binary()})"
  end

  test "refines locally even when the accepted domain is not exact" do
    refute precise?([x], hd(x) == :ok)

    assert quoted(typecheck!([x], hd(x) == :ok, x)) ==
             "dynamic(non_empty_list(term(), term()))"
  end

  test "tracks residual information across case clauses" do
    assert quoted(
             typecheck!(
               [reply],
               true,
               case reply do
                 {:ok, value} when is_binary(value) -> {:text, value}
                 {:ok, value} -> {:other, value}
               end
             )
           ) == "dynamic({:other, not binary()} or {:text, binary()})"
  end

  test "propagates guard refinements through variable dependencies" do
    assert quoted(
             typecheck!(
               [pair],
               true,
               case pair do
                 {x, _y} when is_integer(x) -> pair
               end
             )
           ) == "dynamic({integer(), term()})"

    assert quoted(
             typecheck!(
               [pair],
               true,
               case pair do
                 {x, _y} when is_integer(x) -> elem(pair, 0)
               end
             )
           ) == "integer()"

    assert quoted(
             typecheck!(
               [pair],
               true,
               case pair do
                 {x, _y} when is_integer(x) -> elem(pair, 1)
               end
             )
           ) == "dynamic()"
  end

  test "uses propagated refinements when checking later expressions" do
    message =
      typeerror!(
        [pair],
        true,
        case pair do
          {x, _y} when is_integer(x) -> String.length(elem(pair, 0))
        end
      )
      |> clean()

    assert message =~ "incompatible types given to String.length/1"
    assert message =~ "given types:"
    assert message =~ "integer()"
    assert message =~ "dynamic({integer(), term()})"
  end

  test "rejects code that contradicts the refined value space" do
    message =
      typeerror!(
        [x],
        tuple_size(x) == 2 and
          ((elem(x, 0) == :data and is_binary(elem(x, 1))) or
             (elem(x, 0) == :halt and elem(x, 1) == :normal)),
        elem(x, 1) + 1
      )
      |> clean()

    assert message =~ "incompatible types given to Kernel.+/2"
    assert message =~ "dynamic(:normal or binary()), integer()"
    assert message =~ "{:data, binary()} or {:halt, :normal}"
  end

  test "rejects impossible guards" do
    message =
      typeerror!([x], is_pid(x) and is_atom(x), x)
      |> clean()

    assert message =~ "this guard will never succeed"
    assert message =~ "because it returns type:"
    assert message =~ "false"
  end

  test "warns when a later clause is already covered" do
    {type, warning} =
      typewarn!(
        [pair],
        true,
        case pair do
          {x, y} when is_integer(x) and is_integer(y) -> {:ints, x, y}
          {x, y} when is_integer(x) and is_integer(y) -> {:again, x, y}
        end
      )

    assert quoted(type) == "dynamic({:again or :ints, integer(), integer()})"

    warning = clean(warning)
    assert warning =~ "the following clause is redundant"
    assert warning =~ "{integer(), integer()}"
  end

  test "infers reverse-arrow domains from successful stdlib calls" do
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

    assert Enum.map(domain, &quoted/1) == ["{:int, integer()} or {:not_int, term()}"]

    assert Enum.map(clauses, fn {[argument], return} ->
             {quoted(argument), quoted(return)}
           end) == [
             {"{:int, integer()}", "binary()"},
             {"{:not_int, term()}", "dynamic({:not_int, term()})"}
           ]
  end
end
