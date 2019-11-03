defmodule ZiglerTest.ParserTest do
  use ExUnit.Case, async: true

  alias Zigler.Parser

  @moduletag :parser

  describe "the docstring line parser" do
    test "will ignore a non docline" do
      assert {:error, _, _, _, _, _} = Parser.parse_docstring_line(" this is not a docline ")
    end
    test "can identify a single docline" do
      docline = "/// this is a docline\n"
      assert {:ok, docline, _, _, _, _} = Parser.parse_docstring_line(docline)
    end
    test "can identify a single docline when it's got indentation" do
      docline = "  /// this is a docline\n"
      assert {:ok, docline, _, _, _, _} = Parser.parse_docstring_line(docline)
    end
  end

  describe "the docstring multiline parser" do
    test "can identify multiline docstrings" do
      docstring = """
        /// this is the first line
        /// and this is the second line
      """
      assert {:ok, docstring, _, _, _, _} = Parser.parse_docstring(docstring)
    end
  end

  describe "the nif parser" do
    test "can identify nifs" do
      code = """
        /// nif: my_function/1
        fn my_function(val:i8) i8 {
          return val + 1;
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_nif_line(code)
    end
  end

  describe "the function header parser" do
    test "can identify zero-arity function headers" do
      code = """
        fn zero_arity_func() i8 {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    test "can identify one-arity function headers" do
      code = """
        fn one_arity_func(val : i8) i8 {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    test "can identify two-arity function headers" do
      code = """
        fn two_arity_func(val : i8, val2 : i8) i8 {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    test "can identify bool function headers" do
      code = """
        fn two_arity_func(val : i8, val2 : i8) bool {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    test "can identify string function headers" do
      code = """
        fn string_in(val: [*c]u8) c_int {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    test "can identify erlnifenv headers" do
      code = """
        fn compare(env: ?*e.ErlNifEnv, val1: c_int, val2: c_int) e.ErlNifTerm {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end

    @tag :one
    test "can identify beam.env headers" do
      code = """
        fn double_atom(env: beam.env, string: []u8) beam.atom {
        }
      """
      assert {:ok, _, _, _, _, _} = Parser.parse_function_header(code)
    end
  end
end
