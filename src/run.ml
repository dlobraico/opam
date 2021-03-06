(***********************************************************************)
(*                                                                     *)
(*    Copyright 2012 OCamlPro                                          *)
(*    Copyright 2012 INRIA                                             *)
(*                                                                     *)
(*  All rights reserved.  This file is distributed under the terms of  *)
(*  the GNU Public License version 3.0.                                *)
(*                                                                     *)
(*  OPAM is distributed in the hope that it will be useful,            *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of     *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      *)
(*  GNU General Public License for more details.                       *)
(*                                                                     *)
(***********************************************************************)

module Sys2 = struct
  open Unix

  (** behaves as [Sys.is_directory] except for symlinks, which returns always [false]. *)
  let is_directory file = 
    (lstat file).st_kind = S_DIR
end

let log fmt = Globals.log "RUN" fmt

let (/) = Filename.concat

let rec mk_temp_dir () =
  let s =
    Filename.temp_dir_name /
    Printf.sprintf "opam-%d-%d" (Unix.getpid ()) (Random.int 4096) in
  if Sys.file_exists s then
    mk_temp_dir ()
  else
    s

let lock_file () =
  !Globals.root_path / "opam.lock"

let log_file () =
  Random.self_init ();
  let f = "command" ^ string_of_int (Random.int 2048) in
  !Globals.root_path / "log" / f

let safe_mkdir dir =
  if not (Sys.file_exists dir) then begin
    log "mkdir %s" dir;
    Unix.mkdir dir 0o755
  end

let mkdir dir =
  let rec aux dir = 
    if not (Sys.file_exists dir) then begin
      aux (Filename.dirname dir);
      safe_mkdir dir;
    end in
  aux dir
  
let copy src dst =
  if src <> dst then begin
    log "copying %s to %s" src dst;
    let n = 1024 in
    let b = String.create n in
    let read = ref min_int in
    let ic = open_in_bin src in
    let oc =
      if Sys.file_exists dst then
      open_out_bin dst
      else
      let perm = (Unix.stat src).Unix.st_perm in
      mkdir (Filename.dirname dst);
      open_out_gen [Open_wronly; Open_creat; Open_trunc; Open_binary] perm dst
    in
    while !read <>0 do
      read := input ic b 0 n;
      output oc b 0 !read;
    done;
    close_in ic;
    close_out oc;
    let st = Unix.lstat src in
    Unix.utimes dst (st.Unix.st_atime) (st.Unix.st_mtime)
  end

let read file =
  log "read %s" file;
  let ic = open_in_bin file in
  let n = in_channel_length ic in
  let s = String.create n in
  really_input ic s 0 n;
  close_in ic;
  s

let write file contents =
  mkdir (Filename.dirname file);
  log "write %s" file;
  let oc = open_out_bin file in
  output_string oc contents;
  close_out oc

let cwd = Unix.getcwd

let chdir dir =
  if Sys.file_exists dir then
    Unix.chdir dir
  else
    Globals.error_and_exit "%s does not exist!" dir

let in_dir dir fn =
  let reset_cwd =
    try
      let cwd = Unix.getcwd () in
      fun () -> chdir cwd
    with _ ->
      (* can happen when the current directory has been deleted *)
      fun () -> () in
  chdir dir;
  try
    let r = fn () in
    reset_cwd ();
    r
  with e ->
    reset_cwd ();
    raise e
    
let list kind dir =
  if Sys.file_exists dir then
    in_dir dir (fun () ->
      let d = Sys.readdir (Unix.getcwd ()) in
      let d = Array.to_list d in
      let l = List.filter kind d in
      List.sort compare (List.map (Filename.concat dir) l))
  else
    []

let files_with_links =
  list (fun f -> try not (Sys.is_directory f) with _ -> true)

let files_all_not_dir =
  list (fun f -> try not (Sys2.is_directory f) with _ -> true)

let directories_strict =
  list (fun f -> try Sys2.is_directory f with _ -> false)

let directories_with_links =
  list (fun f -> try Sys.is_directory f with _ -> false)

let rec_files dir =
  let rec aux accu dir =
    let d = directories_with_links dir in
    let f = files_with_links dir in
    List.fold_left aux (f @ accu) d in
  aux [] dir

let remove_file file =
  log "remove_file %s" file;
  try Unix.unlink file
  with Unix.Unix_error _ -> ()
    
let rec remove_dir dir = (** WARNING it fails if [dir] is not a [S_DIR] or simlinks to a directory *)
  if Sys.file_exists dir then begin
    List.iter remove_file (files_all_not_dir dir);
    List.iter remove_dir (directories_strict dir);
    log "remove_dir %s" dir;
    Unix.rmdir dir;
  end

let with_tmp_dir fn =
  let dir = mk_temp_dir () in
  try
    mkdir dir;
    let e = fn dir in
    remove_dir dir;
    e
  with e ->
    remove_dir dir;
    raise e

let remove file =
  if Sys.file_exists file && Sys2.is_directory file then
    remove_dir file
  else
    remove_file file

let getchdir s =
  let p = Unix.getcwd () in
  let () = chdir s in
  p

let rec root path =
  let d = Filename.dirname path in
  if d = path || d = "" || d = "." then
    path
  else
    root d

(** Expand '..' and '.' *)
let normalize s =
  if Sys.file_exists s then
    getchdir (getchdir s)
  else
    s

let real_path p =
  if Sys.file_exists p && Sys.is_directory p then
    normalize p
  else (
    let dir = normalize (Filename.dirname p) in
    let dir =
      if Filename.is_relative dir then
        Sys.getcwd () / dir
      else
        dir in
    let base = Filename.basename p in
    if base = "." then
      dir
    else
      dir / base
  )

let replace_path bins = 
  let path = ref "<not set>" in
  let env = Unix.environment () in
  for i = 0 to Array.length env - 1 do
    let k,v = match Utils.cut_at env.(i) '=' with
      | Some (k,v) -> k,v
      | None       -> assert false in
    if k = "PATH" then
    let v = Utils.split v ':' in
    let bins = List.filter Sys.file_exists bins in
    let new_path = String.concat ":" (bins @ v) in
    env.(i) <- "PATH=" ^ new_path;
    path := new_path;
  done;
  env, !path

type command = string list

let run_process ?verbose ?(add_to_env=[]) ?(add_to_path=[]) = function
  | []           -> invalid_arg "run_process"
  | cmd :: args ->
      let env, path = replace_path add_to_path in
      let add_to_env = List.map (fun (k,v) -> k^"="^v) add_to_env in
      let env = Array.concat [ env; Array.of_list add_to_env ] in
      let name = log_file () in
      mkdir (Filename.dirname name);
      let str = String.concat " " (cmd :: args) in
      log "cwd=%s path=%s name=%s %s" (Unix.getcwd ()) path name str;
      if None <> try Some (String.index cmd ' ') with Not_found -> None then 
        Globals.warning "Command %S contains 1 space" cmd;
      let verbose = match verbose with
        | None   -> !Globals.debug || !Globals.verbose
        | Some b -> b in
      let r = Process.run ~env ~name ~verbose cmd args in
      if not !Globals.debug then
        Process.clean_files r;
      r

let display_error_message r =
  if Process.is_failure r then (
    let command = r.Process.r_proc.Process.p_name :: r.Process.r_proc.Process.p_args in
    Globals.error "Command %S failed:" (String.concat " " command);
    List.iter (Globals.msg "+ %s\n") r.Process.r_stdout;
    List.iter (Globals.msg "= %s\n") r.Process.r_info;
    List.iter (Globals.msg "- %s\n") r.Process.r_stderr;
  )

let command ?verbose ?(add_to_env=[]) ?(add_to_path=[]) cmd =
  let r = run_process ?verbose ~add_to_env ~add_to_path cmd in
  display_error_message r;
  r.Process.r_code

let fold f =
  List.fold_left (fun err cmd ->
    match err, cmd with
    | _  , [] -> err
    | 0  , _  -> f cmd
    | err, _  -> err
  ) 0

let commands ?verbose ?(add_to_env=[]) ?(add_to_path = []) = 
  fold (command ?verbose ~add_to_env ~add_to_path)

let read_command_output ?(add_to_env=[]) ?(add_to_path=[]) cmd =
  let r = run_process ~add_to_env ~add_to_path cmd in
  if Process.is_failure r then
    None
  else
    Some r.Process.r_stdout

module Tar = struct

  let extensions = 
    [ [ "tar.gz" ; "tgz" ], 'z'
    ; [ "tar.bz2" ; "tbz" ], 'j' ]

  let match_ext file ext = 
    List.exists (Filename.check_suffix file) ext

  let assoc file = 
    snd (List.find (function ext, _ -> match_ext file ext) extensions)

  let is_archive f =
    List.exists
      (fun suff -> Filename.check_suffix f suff)
      (List.concat (List.map fst extensions))

  let extract_function file =
    List.fold_left
      (function
        | Some s -> (fun _ -> Some s)
        | None   -> 
            (fun (ext, c) -> 
              if match_ext file ext then
                Some (fun dir -> command  [ "tar" ; Printf.sprintf "xf%c" c ; file; "-C" ; dir ])
              else
                None))
      None
      extensions
end

let is_tar_archive = Tar.is_archive

let extract file dst =
  log "extract %s %s" file dst;
(*   let files = read_command_output [ "tar" ; "tf" ; file ] in
     log "%s contains %d files: %s" file (List.length files) (String.concat ", " files); *)
  with_tmp_dir (fun tmp_dir ->
    match Tar.extract_function file with
    | None   -> Globals.error_and_exit "%s is not a valid archive" file
    | Some f -> 
        let err = f tmp_dir in
        if err <> 0 then
          Globals.error_and_exit "Error while extracting %s" file;
        if Sys.file_exists dst then
          Globals.error_and_exit "Cannot overwrite %s" dst;
        match directories_strict tmp_dir with
        | [x] ->
            mkdir (Filename.dirname dst);
            let err = command [ "mv"; x; dst] in
            if err <> 0 then Globals.error_and_exit "Cannot mv %s to %s" x dst
        | _   -> Globals.error_and_exit "The archive contains mutliple root directories"
  )

let extract_in file dst =
  log "extract_in %s %s" file dst;
  if not (Sys.file_exists dst) then
    Globals.error_and_exit "%s does not exist" file;
  match Tar.extract_function file with
  | None   -> Globals.error_and_exit "%s is not a valid archive" file
  | Some f ->
      let err = f dst in
      if err <> 0 then
        Globals.error_and_exit "Error while extracting %s" file

let link src dst =
  log "linking %s to %s" src dst;
  mkdir (Filename.dirname dst);
  if Sys.file_exists dst then
    remove_file dst;
  Unix.link src dst

let flock () =
  let l = ref 0 in
  let file = lock_file () in
  let id = string_of_int (Unix.getpid ()) in
  let max_l = 5 in
  let rec loop () =
    if Sys.file_exists file && !l < max_l then begin
      let ic = open_in file in
      let pid = input_line ic in
      close_in ic;
      Globals.msg
        "An other process (%s) has already locked %S. Retrying in 1s (%d/%d)\n"
        pid file !l max_l;
      Unix.sleep 1;
      incr l;
      loop ()
    end else if Sys.file_exists file then begin
      Globals.msg "Too many attempts. Cancelling ...\n";
      exit 1
    end else begin
      let oc = open_out file in
      output_string oc id;
      flush oc;
      close_out oc;
      Globals.log id "locking %s" file;
    end in
  loop ()
    
let funlock () =
  let id = string_of_int (Unix.getpid ()) in
  let file = lock_file () in
  if Sys.file_exists file then begin
    let ic = open_in file in
    let s = input_line ic in
    close_in ic;
    if s = id then begin
      Globals.log id "unlocking %s" file;
      Unix.unlink file;
    end else
      Globals.error_and_exit "cannot unlock %s (%s)" file s
  end else
    Globals.error_and_exit "Cannot find %s" file

let with_flock f =
  try
    flock ();
    f ();
    funlock ();
  with e ->
    funlock ();
    raise e

let ocaml_version () =
  match read_command_output [ "ocamlc" ; "-version" ] with
  | None   -> None
  | Some s -> Some (Utils.string_strip (List.hd s))

let ocamlc_where () =
  match read_command_output [ "ocamlc"; "-where" ] with
  | None   -> None
  | Some s -> Some (Utils.string_strip (List.hd s))

let download_command =
  let err_curl = command ~verbose:false ["which"; "curl"] in
  if err_curl = 0 then
    (fun src -> [ "curl"; "--insecure" ; "-OL"; src ])
  else
    let err_wget = command ~verbose:false ["which"; "wget"] in
    if err_wget = 0 then
      (fun src -> [ "wget"; "--no-check-certificate" ; src ])
    else
      Globals.error_and_exit "Cannot find curl nor wget"

let download ~filename:src ~dirname:dst =
  let cmd = download_command src in
  let dst_file = dst / Filename.basename src in
  log "download %s in %s (%b)" src dst_file (src = dst_file);
  let e =
    if dst_file = src then
      0
    else if Sys.file_exists src then
      commands [
        [ "rm"; "-f"; dst_file ];
        [ "cp"; src; dst ]
      ]
    else
      in_dir dst (fun () -> command cmd) in
  if e = 0 then
    Some dst_file
  else
    None

let patch p =
  let err = command ["patch"; "-p0"; "-i"; p] in
  err = 0
