defmodule ZiglerTest.Integration.ZigTest do
  use ExUnit.Case
  use Zigler

  import Zigler.Unit

  @moduletag :zigtest

  # imports module support/passing_tests.exs into zigler.
  # note that this should be precompiled as a result of being in
  # test/support directory.
  zigtest ZiglerTest.ZigTest.PassingTests

  # make sure the existing module recapitulates the code from the
  # tested module

  test "this module has the code" do
    [zigler] = __MODULE__.__info__(:attributes)[:zigler]
    assert IO.iodata_to_binary(zigler.code)
      =~ "forty_seven()"
  end

  @this_file __ENV__.file

  alias ZiglerTest.Integration.ZigTest.FailShim

  test "a test can fail, with the correct line number" do
    @this_file
    |> Path.dirname
    |> Path.join("fail_shim.exs")
    |> Code.compile_file

    assert {:error, _zig_file, 14} =
      apply(FailShim, :"a lie", [])

    assert {:error, _zig_file, 18} =
      apply(FailShim, :"a multiline lie", [])

    assert {:error, _zig_file, 25} =
      apply(FailShim, :"a truth and a lie", [])
  end

end
