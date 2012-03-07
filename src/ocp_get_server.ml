open Sys
open Unix
open File
open Server

let usage =
  Printf.sprintf "%s -p <port> [--debug]" Sys.argv.(0)

let nice_exit () =
  Printf.eprintf "%s\n%!" usage;
  exit 2

let version () =
  Printf.printf "\
%s version %s

Copyright (C) 2012 OCamlPro - INRIA

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.\n"
    Sys.argv.(0) Globals.version

let port  = ref Globals.default_port
let set_port p = port := p

let args = Arg.align [
  "-p"       , Arg.Int set_port     , " Set up the listening port (default is 9999)";
  "--debug"  , Arg.Set Globals.debug, " Print more debug messages";
  "--version", Arg.Unit version     , " Display version information";
]

let _ = Arg.parse args (fun s -> Printf.eprintf "%s: Unknown\n" s) usage

let server fn =
  let host = (gethostbyname(gethostname ())).h_addr_list.(0) in 
  let addr = ADDR_INET (host, !port) in
  let state = Server.init () in
  if !Globals.debug then
    Printf.printf "Listening on port %d (%s) ...\n%!"
      !port (string_of_inet_addr host);

  establish_server (fn state) addr

let request = ref 0

let log fmt =
  Globals.log (Printf.sprintf "REQUEST-%d" !request) fmt

let protect f =
  try f ()
  with e -> Oerror (Printexc.to_string e)

let fn t stdin stdout =
  incr request;
  log "Processing an incoming request";

  let output = match (input_value stdin : input_api) with
  | IgetList                    ->
      log "getList";
      protect (fun () -> OgetList (Server.getList t))
  | IgetOpam name_version       ->
      log "getOpam";
      protect (fun () -> OgetOpam (Server.getOpam t name_version))
  | IgetArchive opam            ->
      log "getArchive";
      protect (fun () -> OgetArchive (Server.getArchive t opam))
  | InewArchive (opam, archive) ->
      (* XXX: need to protect the server state mutation as it can be updated concurrently *)
      log "newArchive";
      protect (fun () -> Server.newArchive t opam archive; OnewArchive) in 

  output_value stdout output;
  flush stdout

let _ =
  handle_unix_error server fn