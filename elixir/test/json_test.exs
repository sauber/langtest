# Verifies the dependency-free JSON decoder on meta-file constructs.
defmodule Langtest.JSONTest do
  use ExUnit.Case, async: true

  alias Langtest.JSON

  # Objects, arrays, strings, booleans, null, and numbers decode correctly.
  test "decodes nested documents" do
    document = ~s({"a": [1, 2.5, -3e2], "b": {"ok": true, "none": null}, "c": "hi\\nthere"})

    assert JSON.decode!(document) == %{
             "a" => [1, 2.5, -300.0],
             "b" => %{"ok" => true, "none" => nil},
             "c" => "hi\nthere"
           }
  end

  # Unicode escapes become UTF-8 strings.
  test "decodes unicode escapes" do
    assert JSON.decode!(~s("caf\\u00e9")) == "café"
  end

  # A top-level scalar is valid JSON.
  test "decodes top-level scalars" do
    assert JSON.decode!("123") == 123
    assert JSON.decode!("1.5") == 1.5
    assert JSON.decode!("false") == false
  end

  # Trailing garbage is rejected instead of silently ignored.
  test "rejects trailing content" do
    assert_raise ArgumentError, fn -> JSON.decode!("[] extra") end
  end
end
