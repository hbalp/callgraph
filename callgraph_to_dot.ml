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

(* Function callgraph *)
class function_callgraph (callgraph_jsonfile:string)
			 (other:string list option)
  = object(self)

  val json_filepath : string = callgraph_jsonfile

  val mutable json_rootdir : Callgraph_t.dir option = None

  val show_files : bool = 

    (match other with
    | None -> false
    | Some args -> 
      
      let show_files : string =
	try
	  List.find
	    (
	      fun arg -> 
		(match arg with
		| "files" -> true
		| _ -> false
		)
	    )
	    args
	with
	  Not_found -> "none"
      in
      (match show_files with
      | "files" -> true
      | "none"
      | _ -> false
      )
    )

  method parse_jsonfile () : unit =
    try
      (
	Printf.printf "Read callgraph's json file \"%s\"...\n" json_filepath;
	(* Read JSON file into an OCaml string *)
	let content = Core.Std.In_channel.read_all json_filepath in
	(* Read the input callgraph's json file *)
	json_rootdir <- Some (Callgraph_j.dir_of_string content)
      )
    with
    | Sys_error msg -> 
       (
	 Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE";
	 Printf.printf "class function_callgraph::parse_jsonfile:ERROR: Ignore not found file \"%s\"" json_filepath;
	 Printf.printf "Sys_error msg: %s\n" msg;
	 Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE";
	 json_rootdir <- None
       )

  method get_file_path (file:Callgraph_t.file) : string =
    "unknownFilePath"

end

(* Dot function callgraph *)
class function_callgraph_to_dot (callgraph_jsonfile:string)
				(other:string list option)
  = object(self)

  inherit function_callgraph callgraph_jsonfile other

  val mutable dot_fcg : Graph_func.G.t = Graph_func.G.empty

  method rootdir_to_dot () = 
    
    (match json_rootdir with
    | None -> ()
    | Some rootdir -> self#dir_to_dot rootdir
    )

  method dir_to_dot (dir:Callgraph_t.dir) =
    
    Printf.printf "callgraph_to_dot.ml::INFO::callgraph_dir_to_dot: dir=\"%s\"...\n" dir.name;

    (* Parse files located in dir *)
    (match dir.files with
     | None -> ()
     | Some files -> 
	List.iter
	  ( 
	    fun (file:Callgraph_t.file) ->  self#file_to_dot file
	  )
	  files
    );

    (* Parse children directories *)
    (match dir.children with
     | None -> ()
     | Some children -> 
	List.iter
	  ( 
	    fun (child:Callgraph_t.dir) ->  self#dir_to_dot child
	  )
	  children
    )

  method file_to_dot (file:Callgraph_t.file) = 

    Printf.printf "callgraph_to_dot.ml::INFO::callgraph_file_to_dot: name=\"%s\"...\n" file.name;

    let filepath : string = self#get_file_path file in

    (* Parse functions declared in file *)
    (match file.declared with
     | None -> ()
     | Some declared -> 
	List.iter
	  ( 
	    fun (fct_decl:Callgraph_t.fonction) ->  self#function_to_dot fct_decl filepath
	  )
	  declared
    );

    (* Parse functions defined in file *)
    (match file.defined with
     | None -> ()
     | Some defined -> 
	List.iter
	  ( 
	    fun (fct_decl:Callgraph_t.fonction) ->  self#function_to_dot fct_decl filepath
	  )
	  defined
    );

    ()

  method function_to_dot (fonction:Callgraph_t.fonction) (filepath:string) = 
    
    Printf.printf "callgraph_to_dot.ml::INFO::callgraph_function_to_dot: sign=\"%s\"...\n" fonction.sign;

    let vfct : Graph_func.function_decl = self#function_create_dot_vertex fonction.sign filepath in

    dot_fcg <- Graph_func.G.add_vertex dot_fcg vfct

  (* adapted from class function_callers_json_parser::dump_fct defined in file function_callgraph.ml *)
  method function_create_dot_vertex (fct_sign:string) (fct_file:string) : Graph_func.function_decl =

    (* Replace all / by _ in the file path *)
    let fpath : string = Str.global_replace (Str.regexp "\\/") "_" fct_file in

    (* Replace all '.' by '_' in the file path *)
    let fpath : string = Str.global_replace (Str.regexp "\\.") "_" fpath in

    (* Replace all '-' by '_' in the file path *)
    let fpath : string = Str.global_replace (Str.regexp "\\-") "_" fpath in

    (* Replace all '+' by 'p' in the file path *)
    let fpath : string = Str.global_replace (Str.regexp "\\+") "p" fpath in

    let filename : string = Filename.basename fct_file in

    let file : Graph.Graphviz.DotAttributes.subgraph option = 
      if show_files then
	Some
    	  {
    	    sg_name = fpath;
    	    sg_attributes = [ `Label filename ];
    	    (* sg_parent = Some class_memberdef_factory.file.sg_name; *)
    	    sg_parent = None;
    	  }
      else
	None
    in
    let v : Graph_func.function_decl =
      {
	id = Printf.sprintf "\"%s\"" fct_sign;
	name = Printf.sprintf "\"%s\"" fct_sign;
	file_path = fct_file;
	line = "unknownFunctionLine";
	bodyfile = fct_file;
	bodystart = "unknownBodyStart";
	bodyend = "unknownBodyEnd";
	return_type = "unknownFunctionReturnType";
	argsstring = "unknownFunctionArgs";
	params = [];
	callers = [];
	callees = [];
	file = file
      }
    in
    v

end
;;

(* Anonymous argument *)
let spec =
  let open Core.Std.Command.Spec in
  empty
  +> anon (maybe(sequence("other" %: string)))

(* Basic command *)
let command =
  Core.Std.Command.basic
    ~summary:"Dot backend for callgraph's json files"
    ~readme:(fun () -> "More detailed information")
    spec
    (
      fun other () -> 
      
      let jsoname_file : String.t = "test.dir.callgraph.gen.json" in

      let dot_callgraph : function_callgraph_to_dot = new function_callgraph_to_dot jsoname_file other in

      dot_callgraph#parse_jsonfile();

      dot_callgraph#rootdir_to_dot()
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread callgraph_to_dot.native" *)
(* End: *)
