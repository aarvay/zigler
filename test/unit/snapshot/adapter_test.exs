defmodule ZiglerTest.Snapshot.AdapterTest do
  use ExUnit.Case, async: true

  alias Zigler.Code
  alias Zigler.Parser.Nif

  describe "for a basic, zero-arity function" do
    test "the shim function directly calls the target function" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_result__ = foo();

        return beam.make_c_long(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 0, args: [], retval: "c_long"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim function can use other types" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_result__ = foo();

        return beam.make_c_int(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 0, args: [], retval: "c_int"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a one-arity function" do
    test "the shim function will correctly fill out arguments" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_i64(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        var __foo_result__ = foo(__foo_arg0__);

        return beam.make_i64(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["i64"], retval: "i64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a zero-arity function with a environment term" do
    test "that is beam.env the shim function passes the env term in" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_result__ = foo(env);

        return beam.make_i64(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 0, args: ["beam.env"], retval: "i64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "that is ?*e.ErlNifEnv the shim function passes the env term in" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_result__ = foo(env);

        return beam.make_i64(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 0, args: ["?*e.ErlNifEnv"], retval: "i64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a one-arity function with a special type" do
    test "the shim function respects beam.term type" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = argv[0];

        return foo(__foo_arg0__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["beam.term"], retval: "beam.term"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim function respects e.ErlNifTerm type" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = argv[0];

        return foo(__foo_arg0__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["e.ErlNifTerm"], retval: "e.ErlNifTerm"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim function respects beam.pid type" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_pid(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        foo(__foo_arg0__);

        return beam.make_nil(env);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["beam.pid"], retval: "void"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim function respects e.ErlNifPid type" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_pid(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        foo(__foo_arg0__);

        return beam.make_nil(env);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["e.ErlNifPid"], retval: "void"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a one-arity function being passed a slice" do
    test "the shim function respects integers" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_slice_of(i32, env, argv[0]) catch |err| switch (err) {
          error.OutOfMemory => return beam.raise_enomem(env),
          beam.Error.FunctionClauseError => return beam.raise_function_clause_error(env)
        };
        defer beam.allocator.free(__foo_arg0__);

        var __foo_result__ = foo(__foo_arg0__);

        return beam.make_i32_list(env, __foo_result__) catch return beam.raise_enomem(env);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["[]i32"], retval: "[]i32"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim function respects floats" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_slice_of(f64, env, argv[0]) catch |err| switch (err) {
          error.OutOfMemory => return beam.raise_enomem(env),
          beam.Error.FunctionClauseError => return beam.raise_function_clause_error(env)
        };
        defer beam.allocator.free(__foo_arg0__);

        var __foo_result__ = foo(__foo_arg0__);

        return beam.make_f64_list(env, __foo_result__) catch return beam.raise_enomem(env);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["[]f64"], retval: "[]f64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a one-arity function with a environment term" do
    test "that is beam.env the shim function passes the env term in" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_i64(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        var __foo_result__ = foo(env, __foo_arg0__);

        return beam.make_i64(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["beam.env", "i64"], retval: "i64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "that is ?*e.ErlNifEnv the shim function passes the env term in" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_i64(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        var __foo_result__ = foo(env, __foo_arg0__);

        return beam.make_i64(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["?*e.ErlNifEnv", "i64"], retval: "i64"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a one-arity function being passed a u8 slice" do
    test "the shim function assumes binary" do
      assert """
      export fn __foo_shim__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var __foo_arg0__ = beam.get_char_slice(env, argv[0])
          catch return beam.raise_function_clause_error(env);

        var __foo_result__ = foo(__foo_arg0__);

        return beam.make_slice(env, __foo_result__);
      }

      """ == %Nif{name: :foo, arity: 1, args: ["[]u8"], retval: "[]u8"}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

  describe "for a long function" do
    test "the shim generates the correct shimming functions" do
      assert """
      const __foo_cache__ = struct {
        env: beam.env,
        self: beam.pid,
        thread: *std.Thread,
        response: beam.term,
        result: i32
      };

      /// resource: __foo_cache_ptr__ definition
      const __foo_cache_ptr__ = ?*__foo_cache__;

      /// resource: __foo_cache_ptr__ cleanup
      fn __foo_cache_cleanup__(env: beam.env, cache_res_ptr: *__foo_cache_ptr__) void {
        if (cache_res_ptr.*) | cache_ptr | {
          beam.allocator.destroy(cache_ptr);
        }
      }

      export fn __foo_launch__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        return __foo_pack__(env, argv)
          catch beam.raise(env, beam.make_atom(env, "error"));
      }

      fn __foo_pack__(env: beam.env, argv: [*c] const beam.term) !beam.term {
        var cache_term = try __resource__.create(__foo_cache_ptr__, env, null);
        errdefer __resource__.release(__foo_cache_ptr__, env, cache_term);

        var cache = try beam.allocator.create(__foo_cache__);
        try __resource__.update(__foo_cache_ptr__, env, cache_term, cache);

        var done_atom = beam.make_atom(env, "done");

        cache.env = env;
        cache.self = try beam.self(env);
        cache.response = e.enif_make_tuple(env, 2, done_atom, cache_term);

        cache.thread = try std.Thread.spawn(cache, __foo_harness__);

        return cache_term;
      }

      fn __foo_harness__(cache: *__foo_cache__) void {
        cache.result = foo();
        var _sent = beam.send(null, cache.self, null, cache.response);
      }

      export fn __foo_fetch__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        var cache_q: ?*__foo_cache__ = __resource__.fetch(__foo_cache_ptr__, env, argv[0])
          catch return beam.raise_function_clause_error(env);
        defer __resource__.release(__foo_cache_ptr__, env, argv[0]);

        if (cache_q) | cache | {
          return beam.make_i32(env, cache.result);
        } else {
          return beam.raise_function_clause_error(env);
        }
      }
      """ == %Nif{name: :foo, arity: 0, args: [], retval: "i32", opts: [long: true]}
      |> Code.adapter
      |> IO.iodata_to_binary
    end

    test "the shim generates appropriate content for a void returning long function" do
      assert """
      const __bar_cache__ = struct {
        env: beam.env,
        self: beam.pid,
        thread: *std.Thread,
        response: beam.term,
      };

      /// resource: __bar_cache_ptr__ definition
      const __bar_cache_ptr__ = ?*__bar_cache__;

      /// resource: __bar_cache_ptr__ cleanup
      fn __bar_cache_cleanup__(env: beam.env, cache_res_ptr: *__bar_cache_ptr__) void {
        if (cache_res_ptr.*) | cache_ptr | {
          beam.allocator.destroy(cache_ptr);
        }
      }

      export fn __bar_launch__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        return __bar_pack__(env, argv)
          catch beam.raise(env, beam.make_atom(env, "error"));
      }

      fn __bar_pack__(env: beam.env, argv: [*c] const beam.term) !beam.term {
        var cache_term = try __resource__.create(__bar_cache_ptr__, env, null);
        errdefer __resource__.release(__bar_cache_ptr__, env, cache_term);

        var cache = try beam.allocator.create(__bar_cache__);
        try __resource__.update(__bar_cache_ptr__, env, cache_term, cache);

        var done_atom = beam.make_atom(env, "done");

        cache.env = env;
        cache.self = try beam.self(env);
        cache.response = e.enif_make_tuple(env, 2, done_atom, cache_term);

        cache.thread = try std.Thread.spawn(cache, __bar_harness__);

        return cache_term;
      }

      fn __bar_harness__(cache: *__bar_cache__) void {
        bar();
        var _sent = beam.send(null, cache.self, null, cache.response);
      }

      export fn __bar_fetch__(env: beam.env, argc: c_int, argv: [*c] const beam.term) beam.term {
        __resource__.release(__bar_cache_ptr__, env, argv[0]);
        return beam.make_atom(env, "nil");
      }
      """ == %Nif{name: :bar, arity: 0, args: [], retval: "void", opts: [long: true]}
      |> Code.adapter
      |> IO.iodata_to_binary
    end
  end

end
