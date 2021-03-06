(******************************************************************************)
(*   Copyright (C) 2014-2015 THALES Communication & Security                  *)
(*   All Rights Reserved                                                      *)
(*   European IST STANCE project (2011-2015)                                  *)
(*   author: Hugues Balp                                                      *)
(*                                                                            *)
(* This file completes json files generated by Callers with extcallees to redefined virtual functions for each virtual method *)
(******************************************************************************)

type callee = LocCallee of string | ExtCallee of Callers_t.extfctdecl;;

class virtual_functions_json_parser (callee_json_filepath:string) = object(self)

  val callee_file_path : string = callee_json_filepath

  (* Keep the function qualified name and filter the returned type and parameters in function signature *)
  method extract_fct_qualified_name_from_sign (fct_sign:string) : string =

    (* Filter the returned type in function signature *)
    let fct_name : string = Str.global_replace (Str.regexp "^[^ ]+ ") "" fct_sign in
    (* Filter the parameters in function signature *)
    let fct_name : string = Str.global_replace (Str.regexp "(.*)") "" fct_name in
    Printf.printf "virtual method qualified name: %s\n" fct_name;
    fct_name

  (* Extract the function base name from the function qualified name *)
  method extract_fct_name_from_qualified_name (fct_qualified_name:string) : string =

    (* Filter the qualifier from the function qualified name to keep only the base function name *)
    let fct_name : string = Str.global_replace (Str.regexp "^.*::") "" fct_qualified_name in
    Printf.printf "virtual method name: %s\n" fct_name;
    fct_name

  (* Extract the class qualifier if any from the function name or return "none" *)
  method extract_class_qualifier (fct_name:string) : string =

    (* Filter the function name and keep only the qualifier *)
    let qualifier : string = Str.global_replace (Str.regexp "::[^:]+$") "" fct_name in
    Printf.printf "virtual method qualifier: %s\n" qualifier;
    qualifier

  method get_inherited_class (child_record_filepath:string) (child_record_name:string)
         : (Callers_t.file * Callers_t.record) option =

    let dirpath : string = Common.read_before_last '/' child_record_filepath in
    let filename : string = Common.read_after_last '/' 1 child_record_filepath in
    let jsoname_file = String.concat "" [ dirpath; "/"; filename; ".file.callers.gen.json" ] in
    let content = Common.read_json_file jsoname_file in
    (match content with
     | None -> None
     | Some content ->
       (
         (* Printf.printf "Read %s content is:\n %s: \n" filename content; *)
         (* Printf.printf "atdgen parsed json file is :\n"; *)
         (* Use the atdgen JSON parser *)
         let file : Callers_t.file = Callers_j.file_of_string content in
         (* print_endline (Callers_j.string_of_file file); *)

         (* Parse the json records contained in the current file *)
         (match file.records with
          | None -> None
          | Some records ->

	     (* Look for the record "child_record_name" among all the records defined in file *)
	     try
	       (
	         let inherited_class =
	           List.find
  		     (
  		       fun (r:Callers_t.record) -> String.compare child_record_name r.name == 0
		     )
		     records
	         in
	         Printf.printf "get_inherited_class: %s\n" inherited_class.name;
	         Some ( file, inherited_class)
	       )
	     with
	       Not_found -> None
         )
       )
    )

  method get_redeclared_method_sign (parent_record_name:string)
        			    (child_record_name:string)
        			    (virtual_method_sign:string) : string =

    let parent_qualifier : string = String.concat "" [ parent_record_name; "::" ] in
    let child_qualifier : string = String.concat "" [ child_record_name; "::" ] in
    let redefined_method_sign : string =
      Str.global_replace (Str.regexp parent_qualifier) child_qualifier virtual_method_sign
    in
    Printf.printf "redeclared_method_sign: %s\n" redefined_method_sign;
    redefined_method_sign

  method get_redeclared_method_sign_with_trema (parent_record_name:string)
        			               (child_record_name:string)
        			               (virtual_method_sign:string) : string =

    let parent_qualifier : string = String.concat "" [ parent_record_name; "::" ] in
    let child_qualifier : string = String.concat "" [ "::"; child_record_name; "::" ] in
    let redefined_method_sign : string =
      Str.global_replace (Str.regexp parent_qualifier) child_qualifier virtual_method_sign
    in
    Printf.printf "redeclared_method_sign_with_trema: %s\n" redefined_method_sign;
    redefined_method_sign

  method get_redeclared_method (child_record_filepath:string)
        		       (child_record_name:string)
        		       (redeclared_method_sign:string)
                               (redeclared_method_sign_with_trema:string) : (Callers_t.file * Callers_t.fct_decl) option =

    Printf.printf "add_virtual_function_calls.get_redeclared_method:BEGIN: child record name=\"%s\", file=\"%s\", redeclared method sign=\"%s\"\n"
        	  child_record_name child_record_filepath redeclared_method_sign;

    let print_warning redeclared_method_sign child_file =

      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
      Printf.printf "add_virtual_function_calls::WARNING::The method \"%s\" is not redeclared in child file \"%s\"\n" redeclared_method_sign child_file;
      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
    in

    let child_class : (Callers_t.file * Callers_t.record) option =
      self#get_inherited_class child_record_filepath child_record_name
    in
    let redeclared_method =
      (match child_class with
       | None -> None
       | Some ( child_file, child_record ) ->

          let redeclared_method : (Callers_t.file * Callers_t.fct_decl) option =

            (* Parse the json declared functions contained in the child file *)
            (match child_file.declared with
             | None ->
        	(
        	  print_warning redeclared_method_sign child_file.file;
        	  None
        	)
             | Some fcts ->

        	(* Look for the virtual method among all the functions declared in file *)
        	try
        	  (
        	    let redeclared_method : Callers_t.fct_decl =
        	      List.find
  			(
  			  fun (f:Callers_t.fct_decl) ->
                          (
                            (String.compare redeclared_method_sign f.sign == 0)
                            ||(String.compare redeclared_method_sign_with_trema f.sign == 0)
                          )
                        )
        		fcts
        	    in
        	    Printf.printf "add_virtual_function_calls::get_redeclared_method::INFO::Found redeclared method: \"%s\" in child file \"%s\"\n"
        			  redeclared_method.sign child_file.file;
        	    Some (child_file, redeclared_method)
        	  )
        	with
        	  Not_found ->
        	  (
        	    print_warning redeclared_method_sign child_file.file;
        	    None
        	  )
            )
          in
          redeclared_method
      )
    in
    Printf.printf "add_virtual_function_calls.get_redeclared_method:END: child record name=\"%s\", file=\"%s\", redeclared method sign=\"%s\"\n"
        	  child_record_name child_record_filepath redeclared_method_sign;
    redeclared_method

  (* For each declared virtual function, look for its redeclared virtual methods. *)
  (* TODO: If the redeclared virtual method is in fact located in the virtual method file, *)
  (* then add a local callee to this redeclared method. *)
  (* TODO: If the redeclared virtual method is in fact located in another file as the virtual method, *)
  (* then add an external callee to the redeclared method. *)
  method add_redeclared_methods_to_virtual_declared_method (fct:Callers_t.fct_decl) (file:Callers_t.file) : Callers_t.fct_decl =

    Printf.printf "add_virtual_function_calls.add_redeclared_methods_to_virtual_declared_method:BEGIN: Lookup for redeclared methods for the virtual method \"%s\" declared in file \"%s\"...\n"
		  fct.sign file.file;
    (* Get the function name *)
    let fct_qualified_name : string = self#extract_fct_qualified_name_from_sign fct.sign in

    (* Retrieve the class qualifier if well present *)
    let record_qualifier : string = self#extract_class_qualifier fct_qualified_name in

    (* Retrieve the base virtual method name *)
    let fct_name = self#extract_fct_name_from_qualified_name fct_qualified_name in

    Printf.printf "virtual function name: %s, qualified name: %s, qualifier: %s\n"
                  fct_name fct_qualified_name record_qualifier;

    (* Lookup for redeclared virtual methods in the inherited classes *)
    let redeclared_methods : (Callers_t.file * Callers_t.fct_decl) list =
      (match file.records with
       | None -> []
       | Some records ->
          List.fold_left
            (fun (all_redeclared_methods:(Callers_t.file * Callers_t.fct_decl) list) (record:Callers_t.record) ->
             Printf.printf "record: %s, kind: %s\n" record.name record.kind;
             (* Navigate through child classes *)
             (match record.inherited with
              | None -> all_redeclared_methods
              | Some inherited ->

                 let redeclared_methods : (Callers_t.file * Callers_t.fct_decl ) list =

                   List.fold_left
                     (fun (red_methods:(Callers_t.file * Callers_t.fct_decl) list) (child:Callers_t.inheritance) ->

                      Printf.printf "child record: %s, loc: %s\n" child.record child.file;
                      (* Get child record definition *)
                      let redeclared_method_sign = self#get_redeclared_method_sign record.name child.record fct.sign in
                      let redeclared_method_sign_with_trema = self#get_redeclared_method_sign_with_trema record.name child.record fct.sign in
                      let redeclared_method = self#get_redeclared_method child.file child.record redeclared_method_sign redeclared_method_sign_with_trema in
                      (match redeclared_method with
                       | None ->
			  (
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    Printf.printf "add_virtual_function_calls::WARNING::Not found redeclared method for virtual method \"%s\" declared in file \"%s\"\n" fct.sign file.file;
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    red_methods
			  )
                       | Some redeclared_method ->
			  (
			    (match redeclared_method with
			       | (redecl_file, redecl_fct) ->
                                  let child_filepath =
                                    (match redecl_file.path with
                                     | None -> "DEBUG1_TBC"
                                     | Some path -> path
                                    )
                                  in
                                  let base_filepath =
                                    (match file.path with
                                     | None -> "DEBUG2_TBC"
                                     | Some path -> path
                                    )
                                  in
				  Printf.printf "add_virtual_function_calls::INFO::Found redeclared method \"%s\" in file \"%s.#.%s\" for virtual method \"%s\" declared in file \"%s\"\n" redecl_fct.sign child_filepath redecl_file.file fct.sign file.file;
                                  (* Edit the "redeclared" field of the redeclared method *)
                                  let base_decl : Callers_t.extfctdecl =
                                    {
                                      sign = fct.sign;
                                      decl = Printf.sprintf "%s/%s:%d" base_filepath file.file fct.line;
                                      mangled = fct.mangled;
                                    }
                                  in
                                  (* Callers.add_base_virtual_decl redecl_fct base_decl; *)
                                  let redecl_jsonfilepath = Printf.sprintf "%s/%s" child_filepath redecl_file.file in
                                  Callers.file_edit_redeclared_fct redecl_fct.sign base_decl redecl_jsonfilepath;
			          redeclared_method :: red_methods
			    )
			  )
                      )
                     )
                     all_redeclared_methods
                     inherited
                 in
                 redeclared_methods
             )
            )
            []
            records
      )
    in
    (* Get the current list of redeclarations *)
    let redeclarations : Callers_t.extfctdecl list =
      (match fct.redeclarations with
       | None -> []
       | Some redeclarations -> redeclarations
      )
    in
    (* For each redeclared method, add a new redeclaration to the virtual method *)
    let edited_redeclarations =
      List.fold_left
        (fun all_redeclarations (redeclared_method: Callers_t.file * Callers_t.fct_decl) ->
         match redeclared_method with
         | (child_file, child_method) ->
            (
              (* Add the redeclaration only if not already present in the input json file *)
              let redecl = Callers.search_redeclaration all_redeclarations child_method.sign in
              let redecls =
                (match redecl with
                 | Some _ ->
                    (
                      Printf.printf "add_virtual_function_calls.add_redeclared_methods_to_virtual_declared_method:INFO: already present redeclaration of function \"%s\" in file \"%s\"\n"
                                    child_method.sign child_file.file;
                      all_redeclarations
                    )
                 | None ->
                    (
                      let child_redeclaration : Callers_t.extfctdecl =
                        {
                          sign = child_method.sign;
                          decl =
                            (match child_file.path with
                             | None -> raise Common.Missing_File_Path
                             | Some path -> Printf.sprintf "%s/%s:%d" path child_file.file child_method.line
                            );
                          mangled = child_method.mangled;
                        }
                      in
                      child_redeclaration::all_redeclarations
                    )
                )
              in
              redecls
            )
        )
        redeclarations
        redeclared_methods
    in

    let edited_function : Callers_t.fct_decl =
      {
	(* eClass = Config.get_type_fct_decl(); *)
        sign = fct.sign;
        line = fct.line;
        virtuality = fct.virtuality;
        mangled = fct.mangled;
        redeclarations = Some edited_redeclarations;
        definitions = fct.definitions;
        redeclared = fct.redeclared;
        locallers = fct.locallers;
        extcallers = fct.extcallers;
        recordName = fct.recordName;
        recordPath = fct.recordPath;
        threads = fct.threads;
      }
    in
    edited_function

  (* For each defined virtual function, look for its redefined virtual methods. *)
  (* TODO: If the redefined virtual method is in fact located in the virtual method file, *)
  (* then add a local callee to this redefined method. *)
  (* TODO: If the redefined virtual method is in fact located in another file as the virtual method, *)
  (* then add an external callee to the redefined method. *)
  method add_redefined_methods_to_virtual_defined_method (fct:Callers_t.fct_def) (file:Callers_t.file) : Callers_t.fct_def =

    Printf.printf "Lookup for redefined methods for the virtual method \"%s\" defined in caller file \"%s\"...\n"
		  fct.sign file.file;
    (* Get the function name *)
    let fct_qualified_name : string = self#extract_fct_qualified_name_from_sign fct.sign in

    (* Retrieve the class qualifier if well present *)
    let record_qualifier : string = self#extract_class_qualifier fct_qualified_name in

    (* Retrieve the base virtual method name *)
    let fct_name = self#extract_fct_name_from_qualified_name fct_qualified_name in

    Printf.printf "virtual function name: %s, qualified name: %s, qualifier: %s\n"
                  fct_name fct_qualified_name record_qualifier;

    (* Lookup for redefined virtual methods in the inherited classes *)
    let redefined_methods : (string * Callers_t.fct_def) list =
      (match file.records with
       | None -> []
       | Some records ->
          List.fold_left
            (fun (all_redefined_methods:(string * Callers_t.fct_def) list) (record:Callers_t.record) ->
             Printf.printf "record: %s, kind: %s\n" record.name record.kind;
             (* Navigate through child classes *)
             (match record.inherited with
              | None -> all_redefined_methods
              | Some inherited ->

                 let redefined_methods : (string * Callers_t.fct_def ) list =

                   List.fold_left
                     (fun (red_methods:(string * Callers_t.fct_def) list) (child:Callers_t.inheritance) ->

                      Printf.printf "child record: %s, loc: %s\n" child.record child.file;
                      (* Get child record definition *)
                      let redeclared_method_sign = self#get_redeclared_method_sign record.name child.record fct.sign in
                      let redeclared_method_sign_with_trema = self#get_redeclared_method_sign_with_trema record.name child.record fct.sign in
                      let redeclared_method = self#get_redeclared_method child.file child.record redeclared_method_sign redeclared_method_sign_with_trema in

                      let redefined_methods =
                        (
                          match redeclared_method with
                          | Some (redecl_file, redeclared_method) ->
                             (
                               let redefined_method = Callers.fct_decl_get_used_fct_def redeclared_method child.file in
                               (match redefined_method with
                                | None ->
			           (
			             Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			             Printf.printf "add_virtual_function_calls.add_redefined_methods_to_virtual_defined_method::WARNING::Not found redefined method for virtual method \"%s\" defined in file \"%s\"\n" fct.sign redecl_file.file;
			             Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			             red_methods
			           )
                                | Some redefined_method ->
			           (
			             (match redefined_method with
			              | (redef_file, redef_fct) ->
				         Printf.printf "add_virtual_function_calls::INFO::Found redefined method \"%s\" in file \"%s\" for virtual method \"%s\" declared in file \"%s\"\n" redef_fct.sign redef_file fct.sign file.file
			             );
			             redefined_method :: red_methods
			           )
                               )
                             )
                          | None ->
			     (
			       Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			       Printf.printf "add_virtual_function_calls.add_redefined_methods_to_virtual_defined_method::WARNING::Not found redeclared method for virtual method \"%s\" defined in file \"%s\"\n" fct.sign file.file;
			       Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			       red_methods
			     )
                        )
                      in
                      redefined_methods
                     )
                     all_redefined_methods
                     inherited
                 in
                 redefined_methods
             )
            )
            []
            records
      )
    in
    (* Get the current list of extcallees *)
    let extcallees : Callers_t.extfctdecl list =
      (match fct.extcallees with
       | None -> []
       | Some extcallees -> extcallees
      )
    in
    (* For each redefined method, add a new extcallee to the virtual method *)
    let edited_extcallees =
      List.fold_left
        (fun all_extcallees (redefined_method: string * Callers_t.fct_def) ->
         match redefined_method with
         | (child_filepath, child_method) ->
            (
              let child_extcallee : Callers_t.extfctdecl =
                {
                  sign = child_method.sign;
                  (* decl =Printf.sprintf "%s:%d" child_filepath child_method.line; *)
                  decl =Printf.sprintf "WARNING_TO_BE_VALIDATED_%s:%d" child_filepath child_method.line;
                  mangled = child_method.mangled;
                }
              in
              child_extcallee::all_extcallees
            )
        )
        extcallees
        redefined_methods
    in
    let edited_function : Callers_t.fct_def =
      {
	(* eClass = Config.get_type_fct_def(); *)
        sign = fct.sign;
        line = fct.line;
	decl = fct.decl;
        mangled = fct.mangled;
        virtuality = fct.virtuality;
        locallees = fct.locallees;
        extcallees = Some edited_extcallees;
        builtins = fct.builtins;
        recordName = fct.recordName;
        recordPath = fct.recordPath;
        threads = fct.threads;
      }
    in
    edited_function

  method parse_caller_file (json_filepath:string) (root_dir_fullpath:string) : Callers_t.file option =

    (* Use the atdgen Yojson parser *)
    let dirpath : string = Common.read_before_last '/' json_filepath in
    let filename : string = Common.read_after_last '/' 1 json_filepath in
    let jsoname_file = String.concat "" [ dirpath; "/"; filename; ".file.callers.gen.json" ] in
    let content = Common.read_json_file jsoname_file in
    let edited_content =
      (match content with
       | None -> None
       | Some content ->
          (
            let file : Callers_t.file = Callers_j.file_of_string content in

            (* Parse the functions declared in the current file *)
            let edited_declared_functions:Callers_t.fct_decl list =

              (match file.declared with
               | None -> []
               | Some fcts ->
	          (
	            (* Edit all redeclared functions *)
	            let edited_redeclared_functions : Callers_t.fct_decl list =
                      List.map
                        (
                          fun (fct:Callers_t.fct_decl) ->
                          (
                            (match fct.virtuality with
                             | None -> fct
                             | Some "no" -> fct
                             | Some virtuality ->
			        Printf.printf "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\n";
			        Printf.printf "add_virtual_function_calls::DEBUG1::add_redeclared_methods_to_virtual_declared_method()\n";
			        Printf.printf "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\n";
                                self#add_redeclared_methods_to_virtual_declared_method fct file
                            )
		          )
		        )
		        fcts
	            in
	            edited_redeclared_functions
	          )
              )
            in

            (* Parse the functions defined in the current file *)
            let edited_defined_functions:Callers_t.fct_def list =

              (match file.defined with
               | None -> []
               | Some fcts ->
	          (
	            (* Parses all defined function *)
	            let edited_functions : Callers_t.fct_def list =
                      List.map
                        (
                          fun (fct:Callers_t.fct_def) ->
                          (
                            (match fct.virtuality with
                             | None -> fct
                             | Some "no" -> fct
                             | Some virtuality ->
                                self#add_redefined_methods_to_virtual_defined_method fct file
                            )
		          )
		        )
		        fcts
	            in
	            edited_functions
	          )
              )
            in
            let edited_file : Callers_t.file =
              {
	        file = file.file;
                kind = file.kind;
	        path = file.path;
	        namespaces = file.namespaces;
	        records = file.records;
                threads = file.threads;
	        declared = Some edited_declared_functions;
	        defined = Some edited_defined_functions;
              }
            in
            Some edited_file
          )
      )
    in
    edited_content
end

(* Anonymous argument *)
let spec =
  let open Core.Std.Command.Spec in
  empty
  +> anon ("file_json" %: string)
  +> anon ("root_dir_fullpath" %: string)

(* Basic command *)
let command =
  Core.Std.Command.basic
    ~summary:"Completes virtual function calls in callers's generated json files"
    ~readme:(fun () -> "More detailed information")
    spec
    (
      fun file_json root_dir_fullpath () ->
	try
	  (
	    let parser = new virtual_functions_json_parser file_json in
	    let edited_file = parser#parse_caller_file file_json root_dir_fullpath in
	    (match edited_file with
	    | None -> ()
	    | Some edited_file ->
	      (
		(* let jsoname_file = String.concat "." [ file_json; "edited.debug.json" ] in *)
		let jsoname_file = String.concat "" [ file_json; ".file.callers.gen.json" ] in
		Callers.print_callers_file edited_file jsoname_file
	      )
	    )
	  )
	with
	| Common.File_Not_Found _ -> raise Common.Usage_Error
	| Sys_error msg ->
	   (
	    Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	    Printf.printf "add_virtual_function_calls::ERROR::sys_error:%s\n" msg;
	    Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n"
	   )
	(* | _ -> *)
	(*   ( *)
	(*     Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n"; *)
	(*     Printf.printf "add_virtual_function_calls::ERROR::unexpected error\n"; *)
	(*     Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n"; *)
	(*     raise Common.Unexpected_Error *)
	(*   ) *)
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -package batteries -tag thread add_virtual_function_calls.native" *)
(* End: *)
