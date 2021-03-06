%%% @doc Unit tests for {@link moka_mod_utils}

-module(moka_mod_utils_eunit).

-export([hook_in/2]).

-include_lib("eunit/include/eunit.hrl").

get_beam_code_test_() ->
    FakeModule = fake_module(),
    [?_assert(is_binary(moka_mod_utils:get_object_code(test_module())))
     , ?_assertThrow(
          {cannot_get_object_code, FakeModule},
          moka_mod_utils:get_object_code(FakeModule))].

get_abs_code_test_() ->
    FakeModule = fake_module(),
    [?_assert(is_list(moka_mod_utils:get_abs_code(test_module())))
     , ?_assertThrow(
          {cannot_get_object_code, FakeModule},
          moka_mod_utils:get_abs_code(FakeModule))
    ].

%% This test is mainly to verify the possibility of loading new code. Further
%% tests will use this functionality, but if this fails is quite likely that
%% something with code loading has broken.
swap_forms_test_() ->
    Module1 = test_module(),
    Module2 = test_module2(),
    {setup,
     setup_get_forms([Module1, Module2]),
     fun(_) -> ok end,
     fun([AbsCode1, AbsCode2]) ->
             {inorder,
              [?_assertEqual({foo, bar}, {Module1:foo(), Module2:bar()})
               , ?_assertError(undef, Module1:bar())
               , ?_assertError(undef, Module2:foo())

               , ?_test(moka_mod_utils:load_abs_code(Module1, AbsCode2))
               , ?_test(moka_mod_utils:load_abs_code(Module2, AbsCode1))

               , ?_assertEqual({foo, bar}, {Module2:foo(), Module1:bar()})
               , ?_assertError(undef, Module2:bar())
               , ?_assertError(undef, Module1:foo())

               , ?_assertEqual(ok, moka_mod_utils:restore_module(Module1))
               , ?_assertEqual(ok, moka_mod_utils:restore_module(Module2))
              ]}
     end}.

modify_remote_call_test_() ->
    Module = test_module(),
    {setup,
     setup_get_forms([Module]),
     cleanup_restore_modules([Module]),
     fun([AbsCode]) ->
             {inorder,
              [?_assertEqual(bar, Module:remote_bar())

               , ?_test(moka_mod_utils:load_abs_code(
                          Module, modify_bar_call(AbsCode)))

               , ?_assertEqual(node(), Module:remote_bar())]}
     end}.

%% Test we can capture the arguments of the substituted call
modify_remote_call_with_args_test_() ->
    Module = test_module(),
    {setup,
     setup_get_forms([Module]),
     cleanup_restore_modules([Module]),
     fun([AbsCode]) ->
             {inorder,
              [?_assertEqual(6, Module:remote_mult(2))

               , ?_test(moka_mod_utils:load_abs_code(
                          Module, modify_mult_call(AbsCode)))

               , ?_assertEqual({factors, 2, 3}, Module:remote_mult(2))]}
     end}.

%%%===================================================================
%%% Internals
%%%===================================================================
test_module() -> moka_test_module.

test_module2() -> moka_test_module2.

%% We assume this module doesn't exist
fake_module() -> moka_fake_mod.

setup_get_forms(Modules) ->
    fun() -> [moka_mod_utils:get_abs_code(M) || M <- Modules] end.

cleanup_restore_modules(Modules) ->
    fun(_) ->
            lists:foreach(
              fun(M) -> moka_mod_utils:restore_module(M) end,
              Modules)
    end.

modify_bar_call(AbsCode) ->
    moka_mod_utils:replace_remote_calls(
      {test_module2(), bar, 0},
      {erlang, node, []},
      AbsCode).

modify_mult_call(AbsCode) ->
    moka_mod_utils:replace_remote_calls(
      {test_module2(), mult, 2},
      {?MODULE, hook_in, [factors, '$args']},
      AbsCode).

%% We inject this function in some tests
hook_in(What, [A, B]) -> {What, A, B}.
