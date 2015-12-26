(******************************************************************************)
(*   Copyright (C) 2014-2015 THALES Communication & Security                  *)
(*   All Rights Reserved                                                      *)
(*   European IST STANCE project (2011-2015)                                  *)
(*   author: Hugues Balp                                                      *)
(*                                                                            *)
(******************************************************************************)

(* Function callgraph *)
class function_callgraph
  = object(self)

  val mutable json_rootdir : Callgraph_t.dir option = None

  val mutable cdir : Callgraph_t.dir =
    let dir : Callgraph_t.dir =
      {
        name = "tmpCurrDir";
        uses = None;
        children = None;
        files = None
      }
    in
    dir

  val mutable rdir : Callgraph_t.dir =
    let dir : Callgraph_t.dir =
      {
        name = "tmpRootDir";
        uses = None;
        children = None;
        files = None
      }
    in
    dir

  method init_dir (name:string) : Callgraph_t.dir =

    let dir : Callgraph_t.dir =
      {
        name = name;
        uses = None;
        children = None;
        files = None
      }
    in
    dir

  method copy_dir (org:Callgraph_t.dir) : Callgraph_t.dir =

    let dest : Callgraph_t.dir =
      {
        name = org.name;
        uses = org.uses;
        children = org.children;
        files = org.files
      }
    in
    dest

  method add_child_dir (parent:Callgraph_t.dir) (child:Callgraph_t.dir) : unit =

    let children : Callgraph_t.dir list option =
      (match parent.children with
       | None -> Some [child]
       | Some ch -> Some (child::ch)
      )
    in
    Printf.printf "Add child \"%s\" to parent dir \"%s\"\n" child.name parent.name;
    parent.children <- children

  method add_uses_dir (dir:Callgraph_t.dir) (dirpath:string) : unit =

    let uses : string list option =
      (match dir.uses with
       | None -> Some [dirpath]
       | Some uses -> Some (dirpath::uses)
      )
    in
    Printf.printf "Add uses reference of dir \"%s\" in dir \"%s\"\n" dirpath dir.name;
    dir.uses <- uses

  (* This method checks whether the input file is already registered in the directory *)
  method add_file (dir:Callgraph_t.dir) (file:Callgraph_t.file) : unit =

    Printf.printf "fcg.add_file:BEGIN: add the file \"%s\" only if not already present in dir \"%s\"\n" file.name dir.name;

    let present = self#get_file_in_dir dir file.name in
    (match present with
    | Some f -> Printf.printf "File \"%s\" is already present in dir \"%s\"\n" file.name dir.name;
    | None ->
       (
         Printf.printf "Add file \"%s\" to dir \"%s\"\n" file.name dir.name;
         let files : Callgraph_t.file list option =
           (match dir.files with
            | None -> Some [file]
            | Some files -> Some (file::files)
           )
         in
         dir.files <- files
       )
    )

  method add_uses_file (file:Callgraph_t.file) (filepath:string) : unit =

    let uses : string list option =
      (match file.uses with
       | None -> Some [filepath]
       | Some uses -> Some (filepath::uses)
      )
    in
    Printf.printf "Add uses reference of file \"%s\" in file \"%s\"\n" filepath file.name;
    file.uses <- uses

  method get_fct_decl (file:Callgraph_t.file) (fct_sign:string) : Callgraph_t.fonction option =

    try
      (
        (match file.declared with
         | None -> None
         | Some declared ->
           (
             let fct =
               List.find
                 (
                   fun (fct:Callgraph_t.fonction) -> (String.compare fct.sign fct_sign == 0)
                 )
                 declared
             in
             Some fct
           )
        )
      )
    with
      Not_found -> None

  method add_fct_decls (file:Callgraph_t.file) (fct_decls:Callgraph_t.fonction list) : unit =

    let decls : Callgraph_t.fonction list option =
      (match file.declared with
       | None -> Some fct_decls
       | Some decls ->
          Some
            (
              List.fold_left
                (
                  fun (decls:Callgraph_t.fonction list)
                      (def:Callgraph_t.fonction) ->
                  def::decls
                )
                decls
                fct_decls
            )
      )
    in
    Printf.printf "Add the following fonction declarations in file \"%s\":\n" file.name;
    List.iter
      (fun (def:Callgraph_t.fonction) -> Printf.printf " %s\n" def.sign )
      fct_decls;
    file.declared <- decls

  method get_fct_def (file:Callgraph_t.file) (fct_sign:string) : Callgraph_t.fonction option =

    try
      (
        (match file.defined with
         | None -> None
         | Some defined ->
           (
             let fct =
               List.find
                 (
                   fun (fct:Callgraph_t.fonction) -> (String.compare fct.sign fct_sign == 0)
                 )
                 defined
             in
             Some fct
           )
        )
      )
    with
      Not_found -> None

  method add_fct_defs (file:Callgraph_t.file) (fct_defs:Callgraph_t.fonction list) : unit =

    let defs : Callgraph_t.fonction list option =
      (match file.defined with
       | None -> Some fct_defs
       | Some defs ->
         (
           Printf.printf "Preexisting fonction definitions in file \"%s\" are:\n" file.name;
           List.iter
             (fun (def:Callgraph_t.fonction) -> Printf.printf " %s\n" def.sign )
             defs;

           Some
             (
               List.fold_left
                 (
                   fun (defs:Callgraph_t.fonction list)
                       (def:Callgraph_t.fonction) ->
                   def::defs
                 )
                 defs
                 fct_defs
             )
         )
      )
    in
    Printf.printf "Add the following fonction definitions in file \"%s\":\n" file.name;
    List.iter
      (fun (def:Callgraph_t.fonction) -> Printf.printf " %s\n" def.sign )
      fct_defs;
    file.defined <- defs

  (* exception: Usage_Error in case "fct.sign == locallee_sign" *)
  method add_fct_locallee (fct:Callgraph_t.fonction) (locallee_sign:string) : unit =

    Printf.printf "fcg.add_fct_locallee: fct=\"%s\", locallee=\"%s\"\n" fct.sign locallee_sign;

    if (String.compare fct.sign locallee_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_locallee:ERROR: caller = callee = %s\n" locallee_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.locallees with
     | None -> (fct.locallees <- Some [locallee_sign])
     | Some locallees ->
        (* Add the locallee only if it is not already present. *)
        (
          try
           let l =
              List.find
               ( fun l -> String.compare l locallee_sign == 0)
              locallees
           in ()
          with
            Not_found -> (fct.locallees <- Some (locallee_sign::locallees))
        )
    )

  (* exception: Usage_Error in case "fct.sign == localler_sign" *)
  method add_fct_localler (fct:Callgraph_t.fonction) (localler_sign:string) : unit =

    Printf.printf "fcg.add_fct_localler: fct=\"%s\", localler=\"%s\"\n" fct.sign localler_sign;

    if (String.compare fct.sign localler_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_localler:ERROR: caller = callee = %s\n" localler_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.locallers with
     | None -> (fct.locallers <- Some [localler_sign])
     | Some locallers -> (fct.locallers <- Some (localler_sign::locallers))
    )

  (* exception: Usage_Error in case "fct.sign == extcallee_sign" *)
  method add_fct_extcallee (fct:Callgraph_t.fonction) (extcallee_sign:string) : unit =

    Printf.printf "fcg.add_fct_extcallee: fct=\"%s\", extcallee=\"%s\"\n" fct.sign extcallee_sign;

    if (String.compare fct.sign extcallee_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_extcallee:ERROR: caller = callee = %s\n" extcallee_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.extcallees with
     | None -> (fct.extcallees <- Some [extcallee_sign])
     | Some extcallees ->
        (* Add the extcallee only if it is not already present. *)
        (
          try
           let l =
              List.find
               ( fun l -> String.compare l extcallee_sign == 0)
              extcallees
           in ()
          with
            Not_found -> (fct.extcallees <- Some (extcallee_sign::extcallees))
        )
    )

  (* exception: Usage_Error in case "fct.sign == extcaller_sign" *)
  method add_fct_extcaller (fct:Callgraph_t.fonction) (extcaller_sign:string) : unit =

    Printf.printf "fcg.add_fct_extcaller: fct=\"%s\", extcaller=\"%s\"\n" fct.sign extcaller_sign;

    if (String.compare fct.sign extcaller_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_extcaller:ERROR: caller = callee = %s\n" extcaller_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.extcallers with
     | None -> (fct.extcallers <- Some [extcaller_sign])
     | Some extcallers ->
        (* Add the extcaller only if it is not already present. *)
        (
          try
           let l =
              List.find
               ( fun l -> String.compare l extcaller_sign == 0)
              extcallers
           in ()
          with
            Not_found -> (fct.extcallers <- Some (extcaller_sign::extcallers))
        )
    )

  (* exception: Usage_Error in case "fct.sign == virtcallee_sign" *)
  method add_fct_virtcallee (fct:Callgraph_t.fonction) (virtcallee_sign:string) : unit =

    Printf.printf "fcg.add_fct_virtcallee: fct=\"%s\", virtcallee=\"%s\"\n" fct.sign virtcallee_sign;

    if (String.compare fct.sign virtcallee_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_virtcallee:ERROR: caller = callee = %s\n" virtcallee_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.virtcallees with
     | None -> (fct.virtcallees <- Some [virtcallee_sign])
     | Some virtcallees -> (fct.virtcallees <- Some (virtcallee_sign::virtcallees))
    )

  (* exception: Usage_Error in case "fct.sign == virtcaller_sign" *)
  method add_fct_virtcaller (fct:Callgraph_t.fonction) (virtcaller_sign:string) : unit =

    Printf.printf "fcg.add_fct_virtcaller: fct=\"%s\", virtcaller=\"%s\"\n" fct.sign virtcaller_sign;

    if (String.compare fct.sign virtcaller_sign == 0) then
      (
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        Printf.printf "fcg: add_fct_virtcaller:ERROR: caller = callee = %s\n" virtcaller_sign;
        Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
        raise Common.Usage_Error
      );

    (match fct.virtcallers with
     | None -> (fct.virtcallers <- Some [virtcaller_sign])
     | Some virtcallers -> (fct.virtcallers <- Some (virtcaller_sign::virtcallers))
    )

  method create_dir_tree (dirpaths:string) : Callgraph_t.dir =

    Printf.printf "fcg.create_dir_tree:BEGIN dirpaths=\"%s\"\n" dirpaths;

    let dirs = Batteries.String.nsplit dirpaths "/" in

    let dir : Callgraph_t.dir =

      (match dirs with
       | ignored::dirs ->
        (
          Printf.printf "fcg.create_dir_tree:DEBUG: ignore first dir \"%s\" !\n" ignored;

          let dir : Callgraph_t.dir option =
            List.fold_right
            (
              fun (dir:string) (child:Callgraph_t.dir option) ->

               let child : Callgraph_t.dir list option =
                 (match child with
                  | None -> (* Printf.printf "dir: %s\n" dir;*) None (**)
                  | Some ch -> (* Printf.printf "dir: %s, child: %s\n" dir ch.name;*) Some [ch] (**)
                 )
               in
               let parent : Callgraph_t.dir =
               {
                 name = dir;
                 uses = None;
                 children = child;
                 files = None
               }
               in
               (* Printf.printf "fcg.create_dir_tree:INFO: create dir \"%s\"\n" dir; *)
               Some parent
            )
            dirs
            None
          in
          (match dir with
           | None -> raise Common.Internal_Error
           | Some dir -> dir
          )
        )
       | _ -> raise Common.Internal_Error
      )
    in
    dir

  (* Check whether a child exists in dir with the input child_path. *)
  (* If true, return it, else return the nearest child leaf of dir and its path *)
  method get_leaf (rdir:Callgraph_t.dir) (child_path:string) : (string * Callgraph_t.dir) option =

    let child_path = Common.check_root_dir child_path in
    Printf.printf "fcg.get_leaf:BEGIN: rdir=\"%s\", child_path=\"%s\"\n" rdir.name child_path;

    let dirname = rdir.name in
    let (dirpath, child_rpath) = Batteries.String.split child_path dirname in
    let dirpath = Printf.sprintf "%s%s" dirpath dirname in
    let childpath = Printf.sprintf "%s%s" dirname child_rpath in

    (* In case rdir has no child, return it directly with the same chil_path as the one in input *)
    (match rdir.children with
     | None ->
        (
          Printf.printf "fcg.get_leaf:END: no children found in rdir=%s, so return rdir with child_path=%s\n" rdir.name childpath;
          Some(dirpath, rdir)
        )
     | Some _ ->
        (
          (* Printf.printf "fcg.get_leaf:DEBUG: Lookup for child dir \"%s\" in parent dir=\"%s\"...\n" childpath dirpath; *)

          let dirs = Batteries.String.nsplit childpath "/" in

          let leaf : (string * Callgraph_t.dir) option =
            (
              (* (match dirs with *)
              (*  | ignored::dirs -> *)
              (*     ( *)
              (*       Printf.printf "fcg.get_leaf:DEBUG: ignore child path first header=\"%s\"\n" ignored; *)

                    let cdir : (string * Callgraph_t.dir) option * (string * Callgraph_t.dir) option =
                      List.fold_left
                        (
                          fun (context:(string * Callgraph_t.dir) option * (string * Callgraph_t.dir) option) (dir:string) ->

                          if (String.compare dir rdir.name == 0) then
                            (
                              (Some (dir, rdir), None)
                            )
                          else
                            (
                              (* Get the child belonging to the child_rpath if any *)
                              let child : (string * Callgraph_t.dir) option * (string * Callgraph_t.dir) option =
                                (match context with
                                 | (None, leaf) ->
                                    (
                                      (* Printf.printf "fcg.get_leaf:DEBUG: Skip child \"%s\" not found in dir \"%s\"\n" dir rdir.name; *)
                                      (None, leaf)
                                    )
                                 | (Some (lpath, parent), _) ->
                                    (
                                      (* Printf.printf "fcg.get_leaf: dir: %s, parent: %s, lpath: %s/%s\n" dir parent.name lpath dir; *)
                                      let cdir = self#get_child parent dir in
                                      (match cdir with
                                       | None ->
                                          (
                                            Printf.printf "Return the leaf \"%s\" of rdir \"%s\" located in \"%s\"\n" parent.name rdir.name lpath;
                                            (None, Some(lpath, parent))
                                          )
                                       | Some child ->
                                          (
                                            let cpath = Printf.sprintf "%s/%s" lpath dir in
                                            (* Printf.printf "fcg.get_leaf:DEBUG: Found child \"%s\" of rdir \"%s\" located in \"%s\"\n" dir rdir.name cpath; *)
                                            (Some (cpath, child), Some (cpath, child))
                                          )
                                      )
                                    )
                                )
                              in
                              child
                            )
                        )
                        (None, None)
                        dirs
                    in
                    (match cdir with
                     | (_, None) ->
                        (
                          Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
                          Printf.printf "fcg.get_leaf:WARNING:1: not found any leaf for child path \"%s\" in dir \"%s\"\n" child_rpath rdir.name;
                          Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
                          None
                        )
                     | (_, leaf) -> leaf
                    )
                  )
            (*    | _ -> *)
            (*       ( *)
            (*         Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n"; *)
            (*         Printf.printf "fcg.get_leaf:WARNING:2: not found child path \"%s\" in dir \"%s\"\n" child_path rdir.name; *)
            (*         Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n"; *)
            (*         None *)
            (*       ) *)
            (*   ) *)
            (* ) *)
          in
          Printf.printf "fcg.get_leaf:END: rdir=%s, child_path=%s\n" rdir.name child_path;
          leaf
        )
    )

  method get_file_in_dir (dir:Callgraph_t.dir) (filename:string) : Callgraph_t.file option =

    (* Printf.printf "fcg.get_file_in_dir:BEGIN: dir=%s, file=%s\n" dir.name filename; *)

    let file =

      (match dir.files with

       | None ->
          (
            Printf.printf "fcg.get_file_in_dir:WARNING: Not_Found_Files: no files in dir \"%s\"\n" dir.name;
            None
          )

       | Some files ->

          try
            (
              let file =
                List.find
                  (fun ( f : Callgraph_t.file ) -> String.compare f.name filename == 0)
                  files
              in
              Printf.printf "Found file \"%s\" in dir \"%s\"\n" file.name dir.name;
              Some file
            )
          with
          | Not_found ->
             (
               Printf.printf "fcg.get_file_in_dir:WARNING: Not_Found_File: not found file \"%s\" in dir \"%s\"\n" filename dir.name;
               None
             )
      )
    in
    (* Printf.printf "fcg.get_file_in_dir:END: dir=%s, file=%s\n" dir.name filename; *)
    file

  (* Lookup for a specific file with already known relative filepath in a given directory *)
  (* warnings: Not_Found_File, Not_Found_Dir *)
  (* exceptions: Usage_Error *)
  method get_file (dir:Callgraph_t.dir) (filepath:string) : Callgraph_t.file option =

    (* Printf.printf "fcg.get_file:BEGIN: dir=%s, filepath=%s\n" dir.name filepath; *)

    let file =
      (
        try
          (
            (* First lookup for the parent directory where the file is located *)
            let fdir = self#get_leaf dir filepath in
            (match fdir with
             | None ->
                (
                  Printf.printf "fcg.get_file:WARNING: Not_Found_Dir: not found file directory path \"%s\"\n" filepath;
                  None
                )
             (* A leaf dir has been found *)
             | Some (lpath, ldir) ->
                (
                  (* Check whether the leaf directory is the files's directory or not *)
                  let (filedir, filename) = Batteries.String.rsplit filepath "/" in
                  let (dirpath, dirname) = Batteries.String.rsplit filedir "/" in
                  if (String.compare dirname ldir.name == 0) then
                    (
                      Printf.printf "fcg.get_file:INFO: Found parent directory \"%s\" of file \"%s\"located in lpath=\"%s\" while dirpath=\"%s\"\n" ldir.name filename lpath filedir;
                      self#get_file_in_dir ldir filename
                    )
                  else
                    (
                      Printf.printf "fcg.get_file:INFO: Not found directory of file \"%s\" located in \"%s\"...\n" filename filedir;
                      Printf.printf "... but found leaf directory \"%s\" in path \"%s\"\n" ldir.name lpath;
                      None
                    )
                )
            )
          )
        with
          Not_found ->
          (
            Printf.printf "fcg.get_file:WARNING: the parent dir name \"%s\" is not contained in the filepath \"%s\" !\n" dir.name filepath;
            None
          )
      )
    in
    (* Printf.printf "fcg.get_file:END: dir=%s, filepath=%s\n" dir.name filepath; *)
    file

  (* Lookup for a specific subdir in a directory *)
  (* warnings: Not_Found_File, Not_Found_Dir *)
  (* exceptions: Usage_Error *)
  method get_dir (dir:Callgraph_t.dir) (childpath:string) : Callgraph_t.dir option =

    Printf.printf "fcg.get_dir:BEGIN: Lookup for child dir \"%s\" in dir=\"%s\"\n" childpath dir.name;

    let subdir =self#get_leaf dir childpath in

    (match subdir with
     | None ->
        (
          Printf.printf "fcg.get_dir:WARNING: Not_Found_Dir: not found child directory path \"%s\"\n" childpath;
          None
        )
     | Some (cpath, child) ->
        (
          (* Printf.printf "Found child \"%s\" in dir \"%s\"\n" childpath dir.name; *)
          Some child
        )
    )

  (* Lookup for a specific subdir in a directory *)
  method get_child (dir:Callgraph_t.dir) (child:string) : Callgraph_t.dir option =

    (* Printf.printf "fcg.get_child:BEGIN: Lookup for child dir \"%s\" in dir=\"%s\"\n" child dir.name; *)

    let subdir =

      (match dir.children with
       | None ->
         (
           Printf.printf "fcg.get_child:INFO: No children in dir \"%s\"\n" dir.name;
           None
         )
       | Some children ->
        try
        (
          let subdir =
            List.find
             (fun (ch:Callgraph_t.dir) -> String.compare ch.name child == 0)
             children
          in
          (* Printf.printf "fcg.get_child:INFO: Found child \"%s\" in dir \"%s\"\n" child dir.name; *)
          Some subdir
        )
        with
        | Not_found ->
         (
           Printf.printf "fcg.get_child:INFO: Not found child \"%s\" in dir \"%s\"\n" child dir.name;
           None
         )
      )
    in
    (* Printf.printf "fcg.get_child:END: Lookup for child dir \"%s\" in dir=\"%s\"\n" child dir.name; *)
    subdir

  (* Returns a reference to the callgraph rootdir *)
  (* exception: Usage_Error in case of inexistent or invalid reference. *)
  method get_fcg_rootdir : Callgraph_t.dir =

    Printf.printf "fcg.get_fcg_rootdir:INFO:...\n";
    (match json_rootdir with
     | None ->
       (
         Printf.printf "WARNING: No root node is yet attached to this callgraph\n";
         raise Common.Usage_Error
       )
     | Some rootdir ->
       (
         Printf.printf "The name of the callgraph root dir is \"%s\"\n" rootdir.name;
         rootdir
       )
    )

  method update_fcg_rootdir (rootdir:Callgraph_t.dir) : unit =

    Printf.printf "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n";
    Printf.printf "fcg.update_fcg_rootdir:INFO: rootdir=%s\n" rootdir.name;
    (match json_rootdir with
    | None -> Printf.printf "old rootdir: none\n";
    | Some rd -> Printf.printf "old rootdir: %s\n" rd.name;
    );
    Printf.printf "new rootdir: %s\n" rootdir.name;
    Printf.printf "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n";
    json_rootdir <- Some rootdir

  (* Complete the input dir with the input file and all its contained directories *)
  (* Warning: here, the filepath does not include the filename itself *)
  (* exception: Usage_Error in case the filepath root dir doesn't match the input dir name *)
  method complete_fcg_file (dir:Callgraph_t.dir) (filepath:string) (file:Callgraph_t.file) : Callgraph_t.file =

    Printf.printf "fcg.complete_fcg_file:BEGIN: dirname=\"%s\", filepath=\"%s/%s\"\n" dir.name filepath file.name;

    (* let file_rootdir = Common.get_root_dir filepath in *)
    (* if (String.compare file_rootdir dir.name != 0) then *)
    (* ( *)
    (*   Printf.printf "fcg.complete_fcg_file:ERROR: the filepath rootdir \"%s\" doesn't match the input dir name \"%s\"\n" file_rootdir dir.name; *)
    (*   raise Common.Usage_Error *)
    (* ); *)

    Printf.printf "fcg.complete_fcg_file:INFO: Try to add file \"%s\" in dir=\"%s\"...\n" file.name filepath;

    (* Checker whether the input dir does already contain the directory path to the input file *)
    (* Add all required directories otherwise *)
    self#complete_fcg_dir dir filepath;

    let leaf = self#get_leaf dir filepath in

    let file =
      (match leaf with
       | None ->
          (
            Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
            Printf.printf "fcg.complete_fcg_file:ERROR: Not found any leaf in dir \"%s\" through path \"%s\"\n" dir.name filepath;
            Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
            raise Common.Internal_Error
          )
       (* A leaf dir has been found *)
       | Some (lpath, ldir) ->
          (
            (* Check whether the leaf directory is well the files's directory as expected *)
            let (dirpath, dirname) = Batteries.String.rsplit filepath "/" in
            if (String.compare dirname ldir.name == 0) then
              (
                Printf.printf "fcg.complete_fcg_file:INFO: found parent directory \"%s\" of file \"%s\" located in lpath=\"%s\" while dirpath=\"%s\"\n" ldir.name file.name lpath filepath;
                self#add_file ldir file;
                file
              )
            else
              (
                Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
                Printf.printf "fcg.completed_fcg_file:ERROR: Not found directory of file \"%s\" located in \"%s\"...\n" file.name filepath;
                Printf.printf "... but found leaf directory \"%s\" in path \"%s\"\n" ldir.name lpath;
                Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
                raise Common.Internal_Error
              )
          )
      )
    in
    Printf.printf "fcg.complete_fcg_file:END: dirname=\"%s\", filepath=\"%s\"\n" dir.name filepath;
    file

  (* Complete the input dir with the input child dir and all its contained directories *)
  method complete_fcg_dir (dir:Callgraph_t.dir) (childpath:string) : unit =

    Printf.printf "fcg.complete_fcg_dir:BEGIN: dirname=\"%s\", childpath=\"%s\"\n" dir.name childpath;

    let childpath = Common.check_root_dir childpath in

    (* let rootdir = Common.get_root_dir childpath in *)
    (* if (String.compare rootdir dir.name != 0) then *)
    (* ( *)
    (*   Printf.printf "fcg.complete_fcg_dir:ERROR: the childpath rootdir \"%s\" doesn't match the input dir name \"%s\"\n" rootdir dir.name; *)
    (*   raise Common.Usage_Error *)
    (* ); *)

    Printf.printf "complete_fcg_dir: Try to add child \"%s\" in dir=\"%s\"...\n" childpath dir.name;

    let leaf = self#get_leaf dir childpath in

    (match leaf with
    | None ->
      (
        Printf.printf "Not found any leaf in dir \"%s\" through path \"%s\"\n" dir.name childpath
      )
    | Some (lpath, ldir) ->
      (
        Printf.printf "Found leaf \"%s\" at pos \"%s\" in dir \"%s\"\n" ldir.name lpath dir.name;
        Printf.printf "Existing lpath is \"%s\"\n" lpath;

        (* Get the remaining path to be created for adding the new child dir *)
        try
          (
            let (_, rpath) = Batteries.String.split childpath lpath in

            (match rpath with
             | "" ->
                (
                  Printf.printf "The child \"%s\" is already contained in dir \"%s\", so nothing to do here.\n" ldir.name dir.name;
                )
             | _ ->
                (
                  Printf.printf "fcg.complete_fcg_dir:INFO: Path to be completed is \"%s\"\n" rpath;
                  let cdir = self#create_dir_tree rpath in
                  (*fcg#output_dir_tree "extension.fcg.gen.json" dir;*)

                  (* Add the new child tree to the leaf *)
                  (match ldir.children with
                   | None -> (ldir.children <- Some [cdir])
                   | Some children -> (ldir.children <- Some (cdir::children))
                  );

                  Printf.printf "fcg.complete_fcg_dir:END: added child=\"%s\" to leaf=\"%s\"\n" cdir.name ldir.name

                (* Output only the ldir with its new child *)
                (*fcg#output_dir_tree "ldir.gen.json" ldir;*)
                )
            )
          )
        with
          Not_found ->
          (
            Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
            Printf.printf "ERROR Not found pattern \"%s\" in childpath=\"%s\"\n" lpath childpath;
            Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n"
          )
      )
    );

    Printf.printf "fcg.complete_fcg_dir:END: dirname=\"%s\", childpath=\"%s\"\n" dir.name childpath

  method complete_callgraph (filepath:string) (file:Callgraph_t.file option) : unit =

    Printf.printf "fcg.complete_callgraph:BEGIN: filepath=\"%s\"\n" filepath;

    (* Adds the rootdir_prefix = /tmp/callers *)
    let filepath = Common.check_root_dir filepath in
    let file_rootdir = Common.get_root_dir filepath in

    (* Check whether a callgraph root dir does already exists or not *)
    (match json_rootdir with
     | None ->
       (
         Printf.printf "Init rootdir: %s\n" file_rootdir;
         let fcg_dir = self#init_dir file_rootdir in
         (match file with
          | None -> self#complete_fcg_dir fcg_dir filepath
          | Some file -> (let _ = self#complete_fcg_file fcg_dir filepath file in ())
         );
         self#update_fcg_rootdir fcg_dir
       )
     | Some rootdir ->
       (
         (* Check whether root dirs are the same for the file and the fcg *)
         if (String.compare file_rootdir rootdir.name == 0) then
         (
           Printf.printf "Keep the callgraph rootdir %s for file %s\n" rootdir.name filepath;
           (match file with
            | None -> self#complete_fcg_dir rootdir filepath
            | Some file -> (let _ = self#complete_fcg_file rootdir filepath file in ())
           )
           (*self#update_fcg_rootdir fcg_dir*)
         )
         (* Check whether the name of the callgraph rootdir is included in the filepath rootdir *)
         else if (Batteries.String.exists filepath rootdir.name) then
         (
           Printf.printf "Change callgraph rootdir from %s to %s\n" rootdir.name file_rootdir;
           let rdir_sep = Printf.sprintf "/%s" rootdir.name in
           let (rootpath,childpath) = Batteries.String.split filepath rdir_sep in
           Printf.printf "root_path=%s, child_path=%s\n" rootpath childpath;
           let new_rdir : Callgraph_t.dir = self#init_dir file_rootdir in
           (* Add directories from new root dir down to the old root dir *)
           self#complete_fcg_dir new_rdir rootpath;

           (* Attach the old root dir to the new one *)
           (* let (_,pdir) = Batteries.String.rsplit rootpath "/" in *)
           (* Printf.printf "parent_dir=%s\n" pdir; *)
           (** Get a reference to the parent dir **)
           let pdir : (string * Callgraph_t.dir) option = self#get_leaf new_rdir rootpath in
           (match pdir with
            | None ->
               (
                 Printf.printf "ERROR: Not found any leaf in dir \"%s\" through path \"%s\"\n" new_rdir.name filepath;
                 raise Common.Internal_Error
               )
            | Some (lpath, ldir) ->
               (
                 Printf.printf "Found leaf \"%s\" at pos \"%s\" in dir \"%s\"\n" ldir.name lpath new_rdir.name;
                 (* Complete the old root dir with some new child paths when needed *)
                 let old_rdir = self#get_fcg_rootdir in
                 let cpath = Printf.sprintf "/%s%s" rootdir.name childpath in
                 (match file with
                  | None -> self#complete_fcg_dir old_rdir cpath
                  | Some file -> (let _ = self#complete_fcg_file old_rdir cpath file in ())
                 );
                 (* Add the old root dir as a child of the present leaf *)
                 self#add_child_dir ldir old_rdir
               )
           );
           self#update_fcg_rootdir new_rdir
         )
         else
         (
           Printf.printf "fcg.complete_callgraph:UNIMPLEMENTED_CASE: rootdir=\"%s\", filepath=\"%s\"\n" rootdir.name filepath;
           raise Common.Unsupported_Case
         )
       )
    );

    Printf.printf "fcg.complete_callgraph:END: filepath=\"%s\"\n" filepath

  method parse_jsonfile (json_filepath:string) : unit =

    Printf.printf "fcg.parse_jsonfile:INFO: json_filepath=%s\n" json_filepath;
    try
      (
	Printf.printf "Read callgraph's json file \"%s\"...\n" json_filepath;
	(* Read JSON file into an OCaml string *)
	let content = Core.Std.In_channel.read_all json_filepath in
	(* Read the input callgraph's json file *)
	self#update_fcg_rootdir (Callgraph_j.dir_of_string content)
      )
    with
    | Sys_error msg ->
       (
	 Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	 Printf.printf "class function_callgraph::parse_jsonfile:ERROR: Ignore not found file \"%s\"\n" json_filepath;
	 Printf.printf "Sys_error msg: %s\n" msg;
	 Printf.printf "EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE\n";
	 json_rootdir <- None
       )

  method output_fcg (json_filepath:string) : unit =

    match json_rootdir with
    | None ->
      (
        Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n";
        Printf.printf "WARNING: empty callgraph, so nothing to print\n";
        Printf.printf "WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW\n"
      )
    | Some rootdir ->
      (
        self#output_dir_tree json_filepath rootdir
      )

  method output_dir_tree (json_filepath:string) (dir:Callgraph_t.dir) : unit =

    Printf.printf "fcg.output_dir_tree: write json file: %s\n" json_filepath;

    Common.print_callgraph_dir dir json_filepath

end

(*********************************** Unitary Tests **********************************************)

let test_complete_callgraph () =

    (* Add a new file *)
    let new_filename = "another_new_file.json" in
    let new_file : Callgraph_t.file =
      {
        name = new_filename;
        uses = None;
        declared = None;
        defined = None
      }
    in

    let fcg = new function_callgraph in
    fcg#complete_callgraph "/toto/tutu/tata/titi" None;
    fcg#complete_callgraph "/dir_a/dir_b/dir_c/toto/dir_d/dir_e/dir_f" (Some new_file);
    (* fcg#complete_callgraph "/dir_e/dir_r/dir_a/dir_b/dir_c" None; *)
    (* fcg#complete_callgraph "/dir_e/dir_r/dir_a/dir_z/dir_h/dir_z" None; *)
    fcg#output_fcg "complete_callgraph.unittest.gen.json";

    (* test get_file *)
    let rdir = fcg#get_fcg_rootdir in
    let _ = fcg#get_file rdir "/dir_a/dir_b/dir_c/toto/dir_d/dir_e/dir_f/another_new_file.json" in
    let _ = fcg#get_file rdir "/dir_a/dir_b/dir_c/toto/dir_d/toto.c" in
    ()

(* Check edition of a base dir to add a child subdir *)
let test_add_child () =

    let fcg = new function_callgraph in
    let dir = fcg#create_dir_tree "/dir_a/dir_b" in
    let dir_b = fcg#get_dir dir "/dir_a/dir_b" in
    let dir_b =
      (match dir_b with
      | None -> raise Common.Internal_Error
      | Some dir_b -> dir_b
      )
    in
    Printf.printf "dir_b: %s\n" dir_b.name;
    let dir_k = fcg#init_dir "dir_k" in
    dir.children <- Some [ dir_b; dir_k ];
    fcg#output_dir_tree "original.gen.json" dir
    (*fcg#output_fcg "my_callgraph.unittest.gen.json"*)

let test_copy_dir () =

    let fcg = new function_callgraph in
    let dir = fcg#create_dir_tree "/dir_e/dir_r/dir_a/dir_b/dir_c" in
    let copie = fcg#copy_dir dir in
    fcg#output_dir_tree "copie.gen.json" copie
    (*fcg#output_fcg "my_callgraph.unittest.gen.json"*)

let test_update_dir () =

    let fcg = new function_callgraph in
    let dir = fcg#create_dir_tree "/dir_e/dir_r/dir_a/dir_b/dir_c" in
    fcg#update_fcg_rootdir dir;
    fcg#output_fcg "my_callgraph.unittest.gen.json"

(* Check edition of a base dir to add a leaf child subdir and a file in it *)
let test_add_leaf_child () =

    let fcg = new function_callgraph in
    let dir = fcg#create_dir_tree "/dir_a/dir_b/dir_c" in
    (*let cpath = "/dir_a/dir_b/dir_c/dir_d/dir_e/dir_f" in*)
    let cpath = "/other_dir/dir_a/dir_b/dir_c/dir_d/dir_e/dir_f" in

    (*fcg#complete_fcg_dir dir cpath;*)
    fcg#update_fcg_rootdir dir;
    (*let rdir = fcg#get_fcg_rootdir in*)
    (*fcg#complete_fcg_dir rdir cpath;*)

    (* Add a new file *)
    let new_filename = "yet_another_new_file.json" in
    let new_file : Callgraph_t.file =
      {
        name = new_filename;
        uses = None;
        declared = None;
        defined = None
      }
    in
    fcg#complete_fcg_file dir cpath new_file;

    (* Output the complete graph to check whether it has really been completed or not *)
    fcg#output_fcg "my_callgraph.unittest.gen.json"

let test_generate_ref_json () =

    let filename = "test_local_callcycle.c" in
    let file : Callgraph_t.file =
      {
        name = filename;
        uses = None;
        declared = None;
        defined = None
      }
    in

    let fcg = new function_callgraph in

    fcg#add_uses_file file "stdio.h";

    fcg#complete_callgraph "/root_dir/test_local_callcycle" (Some file);

    let rdir = fcg#get_fcg_rootdir in

    let dir = fcg#get_dir  rdir "/root_dir/test_local_callcycle" in

    (match dir with
     | None -> raise Common.Internal_Error
     | Some dir ->
       (
        fcg#add_uses_dir dir "includes";
       )
    );

    let file = fcg#get_file rdir "/root_dir/test_local_callcycle/test_local_callcycle.c" in

    (match file with
     | None -> raise Common.Internal_Error
     | Some file ->
       (
         let fct_main : Callgraph_t.fonction =
      	   {
      	     sign = "int main()";
             virtuality = "no";
      	     locallers = None;
      	     locallees = Some [ "void a()" ];
      	     extcallers = None;
      	     extcallees = None;
      	     virtcallers = None;
      	     virtcallees = None;
      	   }
         in

         let fct_a : Callgraph_t.fonction =
	   {
	     sign = "void a()";
             virtuality = "no";
	     locallers = None;
	     locallees = Some [ "int b()" ];
	     extcallers = None;
	     extcallees = Some [ "int printf()" ];
      	     virtcallers = None;
      	     virtcallees = None;
	   }
         in

         let fct_b : Callgraph_t.fonction =
	   {
	     sign = "int b()";
             virtuality = "no";
	     locallers = Some [ "void a()" ];
	     locallees = Some [ "int c()" ];
	     extcallers = None;
	     extcallees = Some [ "int printf()" ];
      	     virtcallers = None;
      	     virtcallees = None;
	   }
         in

         let fct_c : Callgraph_t.fonction =
	   {
	     sign = "int c()";
             virtuality = "no";
	     locallers = Some [ "int b()" ];
	     locallees = Some [ "void a()" ];
	     extcallers = None;
	     extcallees = Some [ "int printf()" ];
      	     virtcallers = None;
      	     virtcallees = None;
	   }
         in

         fcg#add_fct_defs file [fct_main; fct_a; fct_b; fct_c]
       )
    );

    let fct_printf : Callgraph_t.fonction =
      {
        sign = "int printf()";
        virtuality = "no";
        locallers = Some [ "void a()"; "int b()"; "int c()" ];
        locallees = None;
        extcallers = None;
        extcallees = None;
        virtcallers = None;
        virtcallees = None;
      }
    in

    let file_stdio : Callgraph_t.file =
      {
        name = "stdio.h";
        uses = None;
        declared = Some [fct_printf];
        defined = None
      }
    in

    fcg#complete_callgraph "/root_dir/includes" (Some file_stdio);

    fcg#output_fcg "/try.dir.callgraph.gen.json"

(* let () = test_generate_ref_json() *)

(*
   test_complete_callgraph()
   test_add_child();
   test_copy_dir();
   test_update_dir();
   test_add_leaf_child()
 *)

(* Local Variables: *)
(* mode: tuareg *)
(* compile-command: "ocamlbuild -use-ocamlfind -package atdgen -package core -package batteries -package ocamlgraph -tag thread function_callgraph.native" *)
(* End: *)
