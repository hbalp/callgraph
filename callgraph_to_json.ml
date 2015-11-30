(******************************************************************************)
(*   Copyright (C) 2014-2015 THALES Communication & Security                  *)
(*   All Rights Reserved                                                      *)
(*   KTD SCIS 2014-2015                                                       *)
(*   Use Case Legacy TOSA                                                     *)
(*   author: Hugues Balp                                                      *)
(*                                                                            *)
(******************************************************************************)
(* forked from callers_to_json.org *)

open Callgraph_t

(* Anonymous argument *)
let spec =
  let open Core.Std.Command.Spec in
  empty

(* Basic command *)
let command =
  Core.Std.Command.basic
    ~summary:"Writes a test json file with one directory containing two files, each one defining some functions"
    ~readme:(fun () -> "More detailed information")
    spec
    (
      fun () -> 
      
      let jsoname_dir : String.t = "test.dir.callgraph.gen.json" in
      
      let fct_main : Callgraph_t.fonction =
      	{
	  (* eClass = Config.callgraph_get_type_fonction(); *)
      	  sign = "int main()";
      	  (* virtuality = None; *)
      	  locallers = None;
      	  locallees = Some [ "void a()" ];
      	  extcallers = None;
      	  extcallees = None;
      	  (* redeclarations = None; *)
      	  (* definitions = None; *)
      	  (* redefinitions = None; *)
      	}
      in

      let fct_a : Callgraph_t.fonction = 
	{ 
	  (* eClass = Config.callgraph_get_type_fonction(); *)
	  sign = "void a()";
	  (* line = 11; *)
	  (* decl = None; *)
	  (* virtuality = None; *)
	  locallers = None;
	  locallees = Some [ "int b()" ];
	  extcallers = None;
	  extcallees = Some [ "int printf()" ];
	  (* builtins = None; *)
	}
      in
	
      let fct_b : Callgraph_t.fonction = 
	{ 
	  (* eClass = Config.callgraph_get_type_fonction(); *)
	  sign = "int b()";
	  (* line = 12; *)
	  (* decl = None; *)
	  (* virtuality = None; *)
	  locallers = Some [ "void a()" ];
	  locallees = Some [ "int c()" ];
	  extcallers = None;
	  extcallees = Some [ "int printf()" ];
	  (* builtins = None; *)
	}
      in

      let fct_c : Callgraph_t.fonction = 
	{
	  (* eClass = Config.callgraph_get_type_fonction(); *)
	  sign = "int c()";
	  (* line = 13; *)
	  (* decl = None; *)
	  (* virtuality = None; *)
	  locallers = Some [ "int b()" ];
	  locallees = Some [ "void a()" ];
	  extcallers = None;
	  extcallees = Some [ "int printf()" ];
	  (* builtins = None; *)
	}
      in

      (* let base_class0 : Callgraph_t.inheritance =  *)
      (* 	{  *)
      (*     record = "class0"; *)
      (* 	  decl = "/path/to/class0:pos"; *)
      (* 	} *)
      (* in *)

      (* let child_class2 : Callgraph_t.inheritance =  *)
      (* 	{  *)
      (*     record = "class2"; *)
      (* 	  decl = "/path/to/class2:pos"; *)
      (* 	} *)
      (* in *)

      (* let class1 : Callgraph_t.record =  *)
      (* 	{ *)
      (* 	  (\* eClass = Config.callgraph_get_type_record();  *\) *)
      (*     (\* name = "class1"; *\) *)
      (*     fullname = "::module1::class1"; *)
      (* 	  kind = "class"; *)
      (* 	  loc = 13; *)
      (* 	  inherits = Some [ base_class0 ]; *)
      (* 	  inherited = Some [ child_class2 ]; *)
      (* 	} *)
      (* in *)

      (* let struct1 : Callgraph_t.record =  *)
      (* 	{  *)
      (* 	  (\*eClass = Config.callgraph_get_type_record(); *\) *)
      (*     (\* name = "struct1"; *\) *)
      (*     fullname = "::module1::struct1"; *)
      (* 	  kind = "struct"; *)
      (* 	  loc = 20; *)
      (* 	  inherits = None; *)
      (* 	  inherited = None; *)
      (* 	} *)
      (* in *)

      (* let module1 : Callgraph_t.namespace =  *)
      (* 	{ *)
      (* 	  name = "module1"; *)
      (* 	  qualifier = "toto::tata::module1"; *)
      (* 	  (\* namespaces = None; *\) *)
      (* 	  (\* records = None; *\) *)
      (* 	  (\* defined = None; *\) *)
      (* 	} *)
      (* in *)
      
      let file_test : Callgraph_t.file = 
	{
	  (* eClass = Config.callgraph_get_type_file(); *)
	  name = "test_local_callcycle.c";
	  (* path = Some "/opt/uc_sso/src/callgraph/dir_root"; *)
	  (* namespaces = Some [module1]; *)
	  (* records = Some [class1; struct1]; *)
	  declared = None;
	  defined = Some [fct_main; fct_a; fct_b; fct_c];
	}
      in

      let fct_printf : Callgraph_t.fonction = 
	{
	  (* eClass = Config.callgraph_get_type_fonction(); *)
	  sign = "int printf()";
	  (* line = 13; *)
	  (* decl = None; *)
	  (* virtuality = None; *)
	  locallers = Some [ "void a()"; "int b()"; "int c()" ];
	  locallees = None;
	  extcallers = None;
	  extcallees = None;
	  (* builtins = None; *)
	}
      in
            
      let file_stdio : Callgraph_t.file = 
	{
	  (* eClass = Config.callgraph_get_type_file(); *)
	  name = "stdio.h";
	  (* path = Some "/path/to/file_stdio"; *)
	  (* namespaces = Some [module1]; *)
	  (* records = Some [class1; struct1]; *)
	  declared = Some [fct_printf];
	  defined = None;
	}
      in
      
      let dir_test : Callgraph_t.dir = 
	{
	  (* eClass = Config.callgraph_get_type_dir(); *)
	  name = "test_local_callcycle";
	  (* path = "/path/to/dir_test"; *)
	  children = None;
	  files = Some [ file_test ]
	} 
      in

      let dir_includes : Callgraph_t.dir = 
	{
	  (* eClass = Config.callgraph_get_type_dir(); *)
	  name = "includes";
	  (* path = "/path/to/dir_stdio"; *)
	  children = None;
	  files = Some [ file_stdio ]
	} 
      in

      let dir_root : Callgraph_t.dir = 
	{
	  (* eClass = Config.callgraph_get_type_dir(); *)
	  name = "root_dir";
	  (* path = "/path/to/dir_root"; *)
	  children = Some [ dir_test; dir_includes ];
	  files = None;
	} 
      in

      if true then
	(
	  (* Serialize the directory dir_root with atdgen. *)
	  let jdir_root = Callgraph_j.string_of_dir dir_root in
	  (* print_endline jdir_root; *)

	  (* Write the directory dir_root serialized by atdgen to a JSON file *)
	  Core.Std.Out_channel.write_all jsoname_dir jdir_root;
	);
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread callgraph_to_json.native" *)
(* End: *)
