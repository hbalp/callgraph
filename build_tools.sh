#!/bin/bash

atdgen -t callers.atd && atdgen -j callers.atd
atdgen -t callgraph.atd && atdgen -j callgraph.atd

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread callers_to_json.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread callgraph_to_json.native

#ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread function_callgraph.native
ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread callgraph_to_dot.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread parse_json_dir.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread parse_json_symbols.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread list_json_files_in_dirs.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread list_all_symbols.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread list_defined_symbols.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread read_defined_symbols.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_declarations.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_definitions.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_extcallees.native
ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread add_extcallers.native
ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread extract_fcg.native

ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_inherited.native
ocamlbuild -use-ocamlfind -package atdgen -package core -tag thread add_virtual_function_calls.native
ocamlbuild -use-ocamlfind -package atdgen -package core -package ocamlgraph -tag thread classes_depgraph.native
