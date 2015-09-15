
let read_json_file (filename:string) (jsonfileext:string option) : Yojson.Basic.json =

  let filepath : string = 
    (match jsonfileext with
    | None -> Printf.sprintf "%s" filename
    | Some dirext -> Printf.sprintf "%s.%s" filename dirext
    )
  in
  Printf.printf "In_channel read file %s...\n" filepath;
  (* Read JSON file into an OCaml string *)
  let buf = Core.Std.In_channel.read_all filepath in
  (* Use the string JSON constructor *)
  let json = Yojson.Basic.from_string buf in
  json

let parse_json_file (content:string) : unit =

  Printf.printf "atdgen parsed json file is :\n";
  (* Use the atdgen JSON parser *)
  let file : Callgraph_t.file = Callgraph_j.file_of_string content in
  print_endline (Callgraph_j.string_of_file file)

let parse_json_dir (content:string) (dirfullpath:string) (jsonfileext:string option): unit =

  Printf.printf "atdgen parsed json directory is :\n";
  (* Use the atdgen JSON parser *)
  let symbols : Callgraph_t.dir_symbols = Callgraph_j.dir_symbols_of_string content in
  print_endline (Callgraph_j.string_of_dir_symbols symbols);

  (* Parse the json files contained in the current directory *)
  List.iter
    ( fun (file : Callgraph_t.file) -> 
      (* let jsoname_file = String.concat "" [ f; ".file.callers.json" ] in *)
      let dirpath : string = Filename.basename dirfullpath in
      let jsoname_file = 
	if String.compare dirpath dirfullpath == 0
	then file.file
	else String.concat "" [ dirpath; "/"; file.file ]
      in
      let json : Yojson.Basic.json = read_json_file jsoname_file jsonfileext in
      let content : string = Yojson.Basic.to_string json in
      (* Printf.printf "Read %s content is:\n %s: \n" file.file content; *)
      parse_json_file content
    )
    symbols.file_symbols

(* Anonymous argument *)
let spec =
  let open Core.Std.Command.Spec in
  empty
  +> anon ("defined_symbols_jsonfilepath" %: string)
  +> anon (maybe("jsonfileext" %: string))

(* Basic command *)
let command =
  Core.Std.Command.basic
    ~summary:"Parses with the atdgen library the defined symbols json files generated by the script \"list_defined_symbols\""
    ~readme:(fun () -> "More detailed information")
    spec
    (
      fun defined_symbols_jsonfilepath jsonfileext () -> 

	let json : Yojson.Basic.json = read_json_file defined_symbols_jsonfilepath None in
	let content : string = Yojson.Basic.to_string json in
	(* Printf.printf "Read directory content is:\n %s: \n" content; *)
	parse_json_dir content defined_symbols_jsonfilepath jsonfileext
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread read_defined_symbols.native" *)
(* End: *)
