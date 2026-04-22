# Run with:
#   elixir guard_refinement_examples_elixir_1.19.5.exs

Code.require_file("type_helper_elixir_1.19.5.exs", __DIR__)

defmodule GuardRefinementExamples1195Test do
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
                 {x, _y} when is_integer(x) -> pair
               end
             )
           ) == "dynamic()"

    assert quoted(
             typecheck!(
               [pair],
               true,
               case pair do
                 {x, _y} when is_integer(x) -> elem(pair, 0)
               end
             )
           ) == "dynamic()"

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

  test "misses selector misuse when dependency information is not propagated" do
    assert quoted(
             typecheck!(
               [pair],
               true,
               case pair do
                 {x, _y} when is_integer(x) -> String.length(elem(pair, 0))
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
