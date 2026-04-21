# Run with:
#   /path/to/elixir-1.20.0-rc.4/bin/elixir guard_refinement_examples_elixir_1.20.0_rc4.exs

Code.require_file("type_helper_elixir_1.20.0_rc4.exs", __DIR__)

module_ast =
  quote do
    defmodule GuardRefinementExamples1200Rc4SharedTest do
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
                     {x, y} when is_integer(x) -> pair
                   end
                 )
               ) == "dynamic({integer(), term()})"

        assert quoted(
                 typecheck!(
                   [pair],
                   true,
                   case pair do
                     {x, y} when is_integer(x) -> elem(pair, 0)
                   end
                 )
               ) == "integer()"

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

      test "uses propagated refinements when checking later expressions" do
        message =
          typeerror!(
            [pair],
            true,
            case pair do
              {x, y} when is_integer(x) -> String.length(elem(pair, 0))
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
  end

Code.eval_quoted(module_ast)
