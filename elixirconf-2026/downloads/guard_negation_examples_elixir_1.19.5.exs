# Run with:
#   elixir guard_negation_examples_elixir_1.19.5.exs

Code.require_file("type_helper_elixir_1.19.5.exs", __DIR__)

defmodule GuardNegationExamples1195Test do
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
