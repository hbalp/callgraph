(******************************************************************************)
(*   Copyright (C) 2014-2015 THALES Communication & Security                  *)
(*   All Rights Reserved                                                      *)
(*   KTD SCIS 2014-2015                                                       *)
(*   Use Case Legacy TOSA                                                     *)
(*   author: Hugues Balp                                                      *)
(*                                                                            *)
(* This file completes json files generated by Callers with extcallees to redefined virtual functions for each virtual method *)
(******************************************************************************)

exception Debug
exception Internal_Error
(* exception Unexpected_Case *)
exception Usage_Error
exception File_Not_Found
exception Empty_File
(* exception TBC *)
exception Unexpected_Error
exception Missing_File_Path
exception Malformed_Inheritance

module Callers = Map.Make(String);;
module Callees = Map.Make(String);;

type callee = LocCallee of string | ExtCallee of Callgraph_t.extfct;;

class virtual_functions_json_parser (callee_json_filepath:string) = object(self)

  val callee_file_path : string = callee_json_filepath

  method read_json_file (filename:string) : Yojson.Basic.json =
    try
      Printf.printf "In_channel read file %s...\n" filename;
      (* Read JSON file into an OCaml string *)
      let buf = Core.Std.In_channel.read_all filename in
      if ( String.length buf != 0 ) then
	(* Use the string JSON constructor *)
	let json = Yojson.Basic.from_string buf in
	json
      else
	(
	  Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	  Printf.printf "add_virtual_function_calls::ERROR::Empty_File::%s\n" filename;
	  Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	  raise Empty_File
	)
    with
      Sys_error _ -> 
	(
	  Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	  Printf.printf "add_virtual_function_calls::ERROR::File_Not_Found::%s\n" filename;
	  Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	  raise File_Not_Found
	)
      
  method print_edited_file (edited_file:Callgraph_t.file) (json_filename:string) =

    let jfile = Callgraph_j.string_of_file edited_file in
    (* print_endline jfile; *)
    (* Write the new_file serialized by atdgen to a JSON file *)
    (* let new_jsonfilepath:string = Printf.sprintf "%s.new.json" json_filename in *)
    (* Core.Std.Out_channel.write_all new_jsonfilepath jfile *)
    Core.Std.Out_channel.write_all json_filename jfile

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

  method get_inherited_class (child_record_filepath:string) (child_record_name:string) : (Callgraph_t.file * Callgraph_t.record) option =

    let dirpath : string = Common.read_before_last '/' child_record_filepath in
    let filename : string = Common.read_after_last '/' 1 child_record_filepath in
    let jsoname_file = String.concat "" [ dirpath; "/"; filename; ".file.callers.gen.json" ] in
    let json : Yojson.Basic.json = self#read_json_file jsoname_file in
    let content : string = Yojson.Basic.to_string json in
    (* Printf.printf "Read %s content is:\n %s: \n" filename content; *)
    (* Printf.printf "atdgen parsed json file is :\n"; *)
    (* Use the atdgen JSON parser *)
    let file : Callgraph_t.file = Callgraph_j.file_of_string content in
    (* print_endline (Callgraph_j.string_of_file file); *)
    
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
  		  fun (r:Callgraph_t.record) -> String.compare child_record_name r.fullname == 0
		)
		records
	    in
	    Printf.printf "get_inherited_class: %s\n" inherited_class.fullname;
	    Some ( file, inherited_class)
	  )
	with
	  Not_found -> None
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

  method get_redeclared_method (child_record_filepath:string)
			       (child_record_name:string) 
			       (redeclared_method_sign:string) : (Callgraph_t.file * Callgraph_t.fct_decl) option = 

    let print_warning redeclared_method_sign child_file = 

      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
      Printf.printf "add_virtual_function_calls::WARNING::The method \"%s\" is not redeclared in child file \"%s\"\n" redeclared_method_sign child_file;
      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
    in

    let child_class : (Callgraph_t.file * Callgraph_t.record) option = 
      self#get_inherited_class child_record_filepath child_record_name 
    in
    (match child_class with
       | None -> None
       | Some ( child_file, child_record ) ->
	  
	  let redeclared_method : (Callgraph_t.file * Callgraph_t.fct_decl) option = 

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
		    let redeclared_method : Callgraph_t.fct_decl = 
		      List.find
  			(
  			  fun (f:Callgraph_t.fct_decl) -> String.compare redeclared_method_sign f.sign == 0
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

  method get_redefined_method (child_record_filepath:string)
			      (child_record_name:string) 
			      (redefined_method_sign:string) : (Callgraph_t.file * Callgraph_t.fct_def) option = 

    let print_warning redefined_method_sign child_file = 

      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
      Printf.printf "add_virtual_function_calls::WARNING::The method \"%s\" is not redefined in child file \"%s\"\n" redefined_method_sign child_file;
      Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
    in

    let child_class : (Callgraph_t.file * Callgraph_t.record) option = 
      self#get_inherited_class child_record_filepath child_record_name 
    in
    (match child_class with
       | None -> None
       | Some ( child_file, child_record ) ->
	  
	  let redefined_method : (Callgraph_t.file * Callgraph_t.fct_def) option = 

	    (* Parse the json defined functions contained in the child file *)
	    (match child_file.defined with
	     | None -> 
		(
		  print_warning redefined_method_sign child_file.file;
		  None
		)
	     | Some fcts ->
		
		(* Look for the virtual method among all the functions defined in file *)
		try
		  (
		    let redefined_method : Callgraph_t.fct_def = 
		      List.find
  			(
  			  fun (f:Callgraph_t.fct_def) -> String.compare redefined_method_sign f.sign == 0
			)
			fcts
		    in
		    Printf.printf "add_virtual_function_calls::get_redefined_method::INFO::Found redefined method: \"%s\" in child file \"%s\"\n" 
				  redefined_method.sign child_file.file;
		    Some (child_file, redefined_method)
		  )
		with
		  Not_found -> 
		  (
		    print_warning redefined_method_sign child_file.file;
		    None
		  )
	    )
	  in
	  redefined_method
    )

  (* For each declared virtual function, look for its redeclared virtual methods. *)
  (* TODO: If the redeclared virtual method is in fact located in the virtual method file, *)
  (* then add a local callee to this redeclared method. *)
  (* TODO: If the redeclared virtual method is in fact located in another file as the virtual method, *)
  (* then add an external callee to the redeclared method. *)
  method add_redeclared_methods_to_virtual_declared_method (fct:Callgraph_t.fct_decl) (file:Callgraph_t.file) : Callgraph_t.fct_decl =

    Printf.printf "Lookup for redeclared methods for the virtual method \"%s\" declared in file \"%s\"...\n" 
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
    let redeclared_methods : (Callgraph_t.file * Callgraph_t.fct_decl) list =
      (match file.records with
       | None -> []
       | Some records ->
          List.fold_left
            (fun (all_redeclared_methods:(Callgraph_t.file * Callgraph_t.fct_decl) list) (record:Callgraph_t.record) -> 
             Printf.printf "record: %s, kind: %s\n" record.fullname record.kind;
             (* Navigate through child classes *)
             (match record.inherited with
              | None -> all_redeclared_methods
              | Some inherited ->
		 
                 let redeclared_methods : (Callgraph_t.file * Callgraph_t.fct_decl ) list =
		   
                   List.fold_left
                     (fun (red_methods:(Callgraph_t.file * Callgraph_t.fct_decl) list) (child:Callgraph_t.inheritance) -> 
		      
                      Printf.printf "child record: %s, loc: %s\n" child.record child.decl;
                      (* Get child record definition *)
                      let loc : string list = Str.split_delim (Str.regexp ":") child.decl in
                      let child_file = 
                        (match loc with
                         | [ file; _ ] ->  file
                         | _ -> raise Malformed_Inheritance
                        )
                      in
                      let redeclared_method_sign = self#get_redeclared_method_sign record.fullname child.record fct.sign in
                      let redeclared_method = self#get_redeclared_method child_file child.record redeclared_method_sign in
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
			       | (redef_file, redef_fct) ->
				  Printf.printf "add_virtual_function_calls::INFO::Found redeclared method \"%s\" in file \"%s\" for virtual method \"%s\" declared in file \"%s\"\n" redef_fct.sign redef_file.file fct.sign file.file
			    );
			    redeclared_method :: red_methods
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
    let redeclarations : Callgraph_t.extfct list = 
      (match fct.redeclarations with
       | None -> []
       | Some redeclarations -> redeclarations
      )
    in
    (* For each redeclared method, add a new redeclaration to the virtual method *)
    let edited_redeclarations = 
      List.fold_left
        (fun all_redeclarations (redeclared_method: Callgraph_t.file * Callgraph_t.fct_decl) ->
         match redeclared_method with
         | (child_file, child_method) ->
            (
              let child_redeclaration : Callgraph_t.extfct = 
                {
                  sign = child_method.sign;
                  decl = 
                    (match child_file.path with
                     | None -> raise Missing_File_Path
                     | Some path -> Printf.sprintf "%s/%s:%d" path child_file.file child_method.line
                    );
                  def = "unknownVirtualChildMethodDef";
                }
              in
              child_redeclaration::all_redeclarations
            )
        )
        redeclarations
        redeclared_methods
    in
    let edited_function : Callgraph_t.fct_decl =
      {
	(* eClass = Config.get_type_fct_decl(); *)
        sign = fct.sign;
        line = fct.line;
        virtuality = fct.virtuality;
        redeclarations = Some edited_redeclarations;
        definitions = fct.definitions;
        redefinitions = fct.redefinitions;
        locallers = fct.locallers;
        extcallers = fct.extcallers;
      }
    in
    edited_function

  (* For each declared virtual function, look for its redefined virtual methods. *)
  (* TODO: If the redefined virtual method is in fact located in the virtual method file, *)
  (* then add a local callee to this redefined method. *)
  (* TODO: If the redefined virtual method is in fact located in another file as the virtual method, *)
  (* then add an external callee to the redefined method. *)
  method add_redefined_methods_to_virtual_declared_method (fct:Callgraph_t.fct_decl) (file:Callgraph_t.file) : Callgraph_t.fct_decl =

    Printf.printf "Lookup for redefined methods for the virtual method \"%s\" declared in caller file \"%s\"...\n" 
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
    let redefined_methods : (Callgraph_t.file * Callgraph_t.fct_def) list =
      (match file.records with
       | None -> []
       | Some records ->
          List.fold_left
            (fun (all_redefined_methods:(Callgraph_t.file * Callgraph_t.fct_def) list) (record:Callgraph_t.record) -> 
             Printf.printf "record: %s, kind: %s\n" record.fullname record.kind;
             (* Navigate through child classes *)
             (match record.inherited with
              | None -> all_redefined_methods
              | Some inherited ->
		 
                 let redefined_methods : (Callgraph_t.file * Callgraph_t.fct_def ) list =
		   
                   List.fold_left
                     (fun (red_methods:(Callgraph_t.file * Callgraph_t.fct_def) list) (child:Callgraph_t.inheritance) -> 
		      
                      Printf.printf "child record: %s, loc: %s\n" child.record child.decl;
                      (* Get child record definition *)
                      let loc : string list = Str.split_delim (Str.regexp ":") child.decl in
                      let child_file = 
                        (match loc with
                         | [ file; _ ] ->  file
                         | _ -> raise Malformed_Inheritance
                        )
                      in
                      let redefined_method_sign = self#get_redeclared_method_sign record.fullname child.record fct.sign in
                      let redefined_method = self#get_redefined_method child_file child.record redefined_method_sign in
                      (match redefined_method with
                       | None -> 
			  (
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    Printf.printf "add_virtual_function_calls::WARNING::Not found redefined method for virtual method \"%s\" declared in file \"%s\"\n" fct.sign file.file;
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    red_methods
			  )
                       | Some redefined_method -> 
			  (
			    (match redefined_method with
			       | (redef_file, redef_fct) ->
				  Printf.printf "add_virtual_function_calls::INFO::Found redefined method \"%s\" in file \"%s\" for virtual method \"%s\" declared in file \"%s\"\n" redef_fct.sign redef_file.file fct.sign file.file
			    );
			    redefined_method :: red_methods
			  )
                      )
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
    (* Get the current list of redefinitions *)
    let redefinitions : Callgraph_t.extfct list = 
      (match fct.redefinitions with
       | None -> []
       | Some redefinitions -> redefinitions
      )
    in
    (* For each redefined method, add a new redefinition to the virtual method *)
    let edited_redefinitions = 
      List.fold_left
        (fun all_redefinitions (redefined_method: Callgraph_t.file * Callgraph_t.fct_def) ->
         match redefined_method with
         | (child_file, child_method) ->
            (
              let child_redefinition : Callgraph_t.extfct = 
                {
                  sign = child_method.sign;
                  decl = "unknownVirtualChildMethodDecl";
                  def = 
                    (match child_file.path with
                     | None -> raise Missing_File_Path
                     | Some path -> Printf.sprintf "%s/%s:%d" path child_file.file child_method.line
                    )
                }
              in
              child_redefinition::all_redefinitions
            )
        )
        redefinitions
        redefined_methods
    in
    let edited_function : Callgraph_t.fct_decl =
      {
	(* eClass = Config.get_type_fct_decl(); *)
        sign = fct.sign;
        line = fct.line;
        virtuality = fct.virtuality;
        redeclarations = fct.redeclarations;
        definitions = fct.definitions;
        redefinitions = Some edited_redefinitions;
        locallers = fct.locallers;
        extcallers = fct.extcallers;
      }
    in
    edited_function

  (* For each defined virtual function, look for its redefined virtual methods. *)
  (* TODO: If the redefined virtual method is in fact located in the virtual method file, *)
  (* then add a local callee to this redefined method. *)
  (* TODO: If the redefined virtual method is in fact located in another file as the virtual method, *)
  (* then add an external callee to the redefined method. *)
  method add_redefined_methods_to_virtual_defined_method (fct:Callgraph_t.fct_def) (file:Callgraph_t.file) : Callgraph_t.fct_def =

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
    let redefined_methods : (Callgraph_t.file * Callgraph_t.fct_def) list =
      (match file.records with
       | None -> []
       | Some records ->
          List.fold_left
            (fun (all_redefined_methods:(Callgraph_t.file * Callgraph_t.fct_def) list) (record:Callgraph_t.record) -> 
             Printf.printf "record: %s, kind: %s\n" record.fullname record.kind;
             (* Navigate through child classes *)
             (match record.inherited with
              | None -> all_redefined_methods
              | Some inherited ->
		 
                 let redefined_methods : (Callgraph_t.file * Callgraph_t.fct_def ) list =
		   
                   List.fold_left
                     (fun (red_methods:(Callgraph_t.file * Callgraph_t.fct_def) list) (child:Callgraph_t.inheritance) -> 
		      
                      Printf.printf "child record: %s, loc: %s\n" child.record child.decl;
                      (* Get child record definition *)
                      let loc : string list = Str.split_delim (Str.regexp ":") child.decl in
                      let child_file = 
                        (match loc with
                         | [ file; _ ] ->  file
                         | _ -> raise Malformed_Inheritance
                        )
                      in
                      let redeclared_method_sign = self#get_redeclared_method_sign record.fullname child.record fct.sign in
                      let redefined_method = self#get_redefined_method child_file child.record redeclared_method_sign in
                      (match redefined_method with
                       | None -> 
			  (
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    Printf.printf "add_virtual_function_calls::WARNING::Not found redefined method for virtual method \"%s\" defined in file \"%s\"\n" fct.sign file.file;
			    Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
			    red_methods
			  )
                       | Some redefined_method -> 
			  (
			    (match redefined_method with
			     | (redef_file, redef_fct) ->
				Printf.printf "add_virtual_function_calls::INFO::Found redefined method \"%s\" in file \"%s\" for virtual method \"%s\" defined in file \"%s\"\n" redef_fct.sign redef_file.file fct.sign file.file
			    );
			    (*TBC Get redefined_method from redefined method *)
			    redefined_method :: red_methods
			  )
                      )
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
    let extcallees : Callgraph_t.extfct list = 
      (match fct.extcallees with
       | None -> []
       | Some extcallees -> extcallees
      )
    in
    (* For each redefined method, add a new extcallee to the virtual method *)
    let edited_extcallees = 
      List.fold_left
        (fun all_extcallees (redefined_method: Callgraph_t.file * Callgraph_t.fct_def) ->
         match redefined_method with
         | (child_file, child_method) ->
            (
              let child_extcallee : Callgraph_t.extfct = 
                {
                  sign = child_method.sign;
                  decl = "unknownVirtualChildMethodDecl";
                  def = 
                    (match child_file.path with
                     | None -> raise Missing_File_Path
                     | Some path -> Printf.sprintf "%s/%s:%d" path child_file.file child_method.line
                    )
                }
              in
              child_extcallee::all_extcallees
            )
        )
        extcallees
        redefined_methods
    in
    let edited_function : Callgraph_t.fct_def =
      {
	(* eClass = Config.get_type_fct_def(); *)
        sign = fct.sign;
        line = fct.line;
	decl = fct.decl;
        virtuality = fct.virtuality;
        locallers = fct.locallers;
        locallees = fct.locallees;
        extcallees = Some edited_extcallees;
        extcallers = fct.extcallers;
        builtins = fct.builtins;
      }
    in
    edited_function
      
  method parse_caller_file (json_filepath:string) (root_dir_fullpath:string) : Callgraph_t.file option =

    (* Use the atdgen Yojson parser *)
    let dirpath : string = Common.read_before_last '/' json_filepath in
    let filename : string = Common.read_after_last '/' 1 json_filepath in
    let jsoname_file = String.concat "" [ dirpath; "/"; filename; ".file.callers.gen.json" ] in
    let read_json : Yojson.Basic.json = self#read_json_file jsoname_file in
    let content : string = Yojson.Basic.to_string read_json in
    (* Printf.printf "Read caller file \"%s\" content is:\n %s: \n" filename content; *)
    (* Printf.printf "atdgen parsed json file is :\n"; *)
    let file : Callgraph_t.file = Callgraph_j.file_of_string content in
    (* print_endline (Callgraph_j.string_of_file file); *)

    (* Parse the functions declared in the current file *)
    let edited_declared_functions:Callgraph_t.fct_decl list =

      (match file.declared with
       | None -> []
       | Some fcts ->
	  (
	    (* Edit all redeclared functions *)
	    let edited_redeclared_functions : Callgraph_t.fct_decl list =
              List.map
                (
                  fun (fct:Callgraph_t.fct_decl) -> 
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
	    (* Edit all redefined functions *)
	    let edited_redefined_functions : Callgraph_t.fct_decl list =
              List.map
                (
                  fun (fct:Callgraph_t.fct_decl) -> 
                  (
                    (match fct.virtuality with
                     | None -> fct
                     | Some "no" -> fct
                     | Some virtuality ->
			Printf.printf "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\n";
			Printf.printf "add_virtual_function_calls::DEBUG2::add_redefined_methods_to_virtual_declared_method()\n";
			Printf.printf "DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD\n";
                        self#add_redefined_methods_to_virtual_declared_method fct file
                    )
		  )
		)
		edited_redeclared_functions
	    in
	    (* Edit all redefined function *)
	    edited_redefined_functions
	  )
      )
    in

    (* Parse the functions defined in the current file *)
    let edited_defined_functions:Callgraph_t.fct_def list =

      (match file.defined with
       | None -> []
       | Some fcts ->
	  (
	    (* Parses all defined function *)
	    let edited_functions : Callgraph_t.fct_def list =
              List.map
                (
                  fun (fct:Callgraph_t.fct_def) -> 
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
    let edited_file : Callgraph_t.file = 
      {
	(* eClass = Config.get_type_file(); *)
	file = file.file;
	path = file.path;
	namespaces = file.namespaces;
	records = file.records;
	declared = Some edited_declared_functions;
	defined = Some edited_defined_functions;
      }
    in
    Some edited_file
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
		parser#print_edited_file edited_file jsoname_file
	      )
	    )
	  )
	with
	| File_Not_Found _ -> raise Usage_Error
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
	(*     raise Unexpected_Error *)
	(*   ) *)
    )

(* Running Basic Commands *)
let () =
  Core.Std.Command.run ~version:"1.0" ~build_info:"RWO" command

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_virtual_function_calls.native" *)
(* End: *)
