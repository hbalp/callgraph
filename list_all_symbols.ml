(* Copyright (C) 2015 Thales Communication & Security *)
(*   - All Rights Reserved *)
(* author: Hugues Balp *)
(* This program generates a json file listing all the symbols defined in json file generated by the callers's analysis *)
(* adapted from callgraph_from_json.ml *)

exception File_Not_Found
exception Usage_Error
exception Unexpected_Json_File_Format
exception Unexpected_Error

let read_json_file (filename:string) : Yojson.Basic.json option =
  try
    Printf.printf "In_channel read file %s...\n" filename;
    (* Read JSON file into an OCaml string *)
    let buf : string = Core.Std.In_channel.read_all filename in
    if ( String.length buf != 0 ) then
      (* Use the string JSON constructor *)
      let json = Yojson.Basic.from_string buf in
      Some json
    else
      None
  with
  | Sys_error msg -> 
    (
      Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
      Printf.printf "list_all_symbols::ERROR::File_Not_Found::%s\n" filename;
      Printf.printf "You need first to list all the application's directories by executing the list_json_files_in_dirs ocaml program\n";
      Printf.printf "Sys_error msg: %s\n" msg;
      Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
      raise File_Not_Found
    )
  | Yojson.Json_error msg ->
    (
      Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
      Printf.printf "list_all_symbols::ERROR::unexpected error when reading file::%s\n" filename;
      Printf.printf "Yojson.Json_error msg: %s\n" msg;
      Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
      raise Unexpected_Error
    )
    
let parse_json_file (filename:string) (content:string) : Callgraph_t.file =

  try
    (* Printf.printf "atdgen parsed json file is :\n"; *)
    (* Use the atdgen JSON parser *)
    let file : Callgraph_t.file = Callgraph_j.file_of_string content in
    (* print_endline (Callgraph_j.string_of_file file); *)
    file
  with
    Yojson.Json_error msg ->
      (
  	Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
  	Printf.printf "list_all_symbols::ERROR::Unexpected_Json_File_Format::%s\n" filename;
  	Printf.printf "This json file is not compatible with Caller's generated json files\n";
  	Printf.printf "Sys_error msg: %s\n" msg;
  	Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
  	raise Unexpected_Json_File_Format
      )

let filter_file_content (full_file_content:Callgraph_t.file) : Callgraph_t.file = 

  let defined_symbols =
    match full_file_content.defined with
    | None -> None
    | Some symbols ->
      Some
	(
	  List.map
	    (
	      fun (fct:Callgraph_t.fct) -> 
		let defined_symbol : Callgraph_t.fct = 
		  {
		    sign = fct.sign;
		    line = fct.line;
		    locallers = None;
		    locallees = None;
		    extcallers = None;
		    extcallees = None;
		    builtins = None;
		  }
		in
		defined_symbol
	    )
	    symbols
	)
  in
  let filtered_file_content : Callgraph_t.file =
    {
      file = full_file_content.file;
      path = None;
      defined = defined_symbols
    }
  in
  filtered_file_content

let rec parse_json_dir (dir:Callgraph_t.dir) (dirfullpath:string) : unit =

  Printf.printf "Parse dir: %s\n" dirfullpath;
  Printf.printf "================================================================================\n";

  let defined_symbols_filename : string = "defined_symbols.dir.callers.gen.json" in

  let defined_symbols_filepath : string = Printf.sprintf "%s/%s" dirfullpath defined_symbols_filename in

  Printf.printf "Generate defined symbols: %s\n" defined_symbols_filepath;

  let defined_symbols_files : Callgraph_t.file list =
    
    (match dir.files with
    | None -> []
    | Some files -> 
      List.map
	( fun (f:string) -> 

	  let jsoname_file : string = Printf.sprintf "%s/%s" dirfullpath f in
	  Printf.printf "Parse file: %s\n" jsoname_file;
	  Printf.printf "--------------------------------------------------------------------------------\n";

	      let read_json : Yojson.Basic.json option = read_json_file jsoname_file in
	      
	      (match read_json with

	      | Some json ->

		let content : string = Yojson.Basic.to_string json in
		(* Printf.printf "Read %s content is:\n %s: \n" f content; *)
		let full_file_content : Callgraph_t.file = parse_json_file jsoname_file content in

		(* Keep only symbols signatures and locations *)
		let filtered_file_content : Callgraph_t.file = filter_file_content full_file_content in

		filtered_file_content

	      | None ->
		(* Return a callgraph file structure without any functions defined *)
		let empty_file : Callgraph_t.file = 
		  {
		    file = f;
		    path = None;
		    defined = None;
		  } 
		in
		empty_file
	      )
	)
	files
    )
  in

  let subdirs : string list option = 
    (match dir.childrens with
    | None -> None
    | Some subdirs -> 
      Some (
	List.map
	(
	  fun (d:Callgraph_t.dir) -> 
	    let dirpath : string = Printf.sprintf "%s/%s" dirfullpath d.dir in
	    parse_json_dir d dirpath;
	    d.dir
	)
	subdirs
      )
    )
  in

  (* Write the list of defined symbols to the JSON output file *)
  let defined_symbols : Callgraph_t.dir_symbols =
    {
      directory = dir.dir;
      path = Filename.dirname dirfullpath;
      depth = -1;
      file_symbols = defined_symbols_files;
      subdirs = subdirs;
    }
  in
  
  (* Serialize the json file with atdgen. *)
  let jfile = Callgraph_j.string_of_dir_symbols defined_symbols in
  Core.Std.Out_channel.write_all defined_symbols_filepath jfile;
  Printf.printf "Generated file: %s\n" defined_symbols_filepath

let list_all_symbols (content:string) (dirfullpath:string) (output_json_filename:string) : unit =

  Printf.printf "atdgen parsed json directory is :\n";
  (* Use the atdgen JSON parser *)
  let dir : Callgraph_t.dir = Callgraph_j.dir_of_string content in
  (* print_endline (Callgraph_j.string_of_dir dir); *)

  (* Parse the json files contained in the current directory *)
  parse_json_dir dir dirfullpath

(* Anonymous argument *)
let spec =
  let open Core.Std.Command.Spec in
  empty
  +> anon ("defined_symbols_jsonfile" %: string)
  +> anon ("rootdir_fullpath" %: string)
  +> anon (maybe("jsondirext" %: string))

(* Basic command *)
let command =
  Core.Std.Command.basic
    ~summary:"This program concatenates all the symbols defined in the application."
    ~readme:(fun () -> "More detailed information")
    spec
    (
      fun defined_symbols_jsonfile rootdir_fullpath jsondirext () -> 

	try
	  let dirname : string = Filename.basename rootdir_fullpath
	  in
	  let jsoname_dir : string = 
	    (match jsondirext with
	    | None -> 
	      (
		let jsondirext = ".dir.callers.gen.json" in
		Printf.sprintf "%s/%s%s" rootdir_fullpath dirname jsondirext
	      )
	    | Some dirext -> Printf.sprintf "%s/%s.%s" rootdir_fullpath dirname dirext
	    )
	  in
	  let read_json : Yojson.Basic.json option = read_json_file jsoname_dir in
	  (match read_json with
	  | Some json ->
	    let content : string = Yojson.Basic.to_string json in
	    Printf.printf "Start generation of defined symbols' json file from the json root directory...\n";
	    (* Printf.printf "parsed content:\n %s: \n" content; *)
	    Printf.printf "--------------------------------------------------------------------------------\n";
	    list_all_symbols content rootdir_fullpath defined_symbols_jsonfile
	  | None -> Printf.printf "list_all_symbols::Usage_Error:empty_input_dir_json_file!\n")
	with
	| File_Not_Found -> 
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "File_Not_Found error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| Unexpected_Json_File_Format -> 
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "Unexpected_Json_File_Format error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| Usage_Error -> 
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "Usage_Error error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| Unexpected_Error ->
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "Unexpected error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| Yojson.Json_error _ ->
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "Yojson.Json_error error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| Sys_error msg -> 
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "System error %s \n" msg;
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
	| _ -> 
	    (
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	      Printf.printf "Unknown error ! \n";
	      Printf.printf "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF\n";
	    )
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread list_all_symbols.native" *)
(* End: *)
