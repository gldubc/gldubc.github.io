# Run with:
#   elixir guard_negation_examples_elixir_1.20.0_rc4.exs

Code.require_file("type_helper_elixir_1.20.0_rc4.exs", __DIR__)

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
