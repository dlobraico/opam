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

(** The OPAM types and then main function which operates on them. *)

(** {2 Abstract types} *)

(** Collection of abstract values *)
module type SET = sig

  include Set.S

  (** auto-map *)
  val map: (elt -> elt) -> t -> t

  (** Return one element. Fail if the set is not a singleton. *)
  val choose_one : t -> elt

  (** Make a set from a list *)
  val of_list: elt list -> t

  (** Pretty-print a set *)
  val to_string: t -> string

  (** Find an element in the list *)
  val find: (elt -> bool) -> t -> elt

end               

(** Dictionaries of abstract values *)
module type MAP = sig
  
  include Map.S

  (** Pretty-printing *)
  val to_string: ('a -> string) -> 'a t  -> string

  (** Split with [bindings] and return the [snd] component. *)
  val values: 'a t -> 'a list

  (** Same as [merge] but only keys that appear in both maps
      are given in the merging function *)
  (** WARNING : Besides [key], the function could receive 
      some [v1] and some [v2] such that [v1 = v2] holds. *)
  val merge_max: (key -> 'a -> 'a -> 'a option) -> 'a t -> 'a t -> 'a t

  (** Convert an assoc list to a map *)
  val of_list: (key * 'a) list -> 'a t

end

(** All abstract types should implement this signature *)
module type ABSTRACT = sig

  (** ABSTRACT type *)
  type t

  (** Create an abstract value from a string *)
  val of_string: string -> t

  (** Convert an abstract value to a string *)
  val to_string: t -> string

  module Set: SET with type elt = t
  module Map: MAP with type key = t
end

(** Extended sets and maps *)
module type OrderedType = sig
  include Set.OrderedType
  val to_string: t -> string
end
module Set: sig
  module Make (S: OrderedType): SET with type elt = S.t
end
module Map: sig
  module Make (S: OrderedType): MAP with type key = S.t
end

(** {2 Filenames} *)

(** Basenames *)
module Basename: ABSTRACT

(** Shortcut to basename type *)
type basename = Basename.t

(** Absolute directory names *)
module Dirname: sig

  include ABSTRACT

  (** Return the current working directory *)
  val cwd: unit -> t

  (** Remove a directory *)
  val rmdir: t -> unit

  (** Create a directory *)
  val mkdir: t -> unit

  (** List the directory *)
  val list: t -> t list

  (** Evaluate a function in a given directory *)
  val in_dir: t -> (unit -> 'a) -> 'a

  (** Execute a list of commands in a given directory *)
  val exec: t
    -> ?add_to_env:(string * string) list
    -> ?add_to_path:t list -> string list list -> int

  (** Change the current directory *)
  val chdir: t -> unit

  (** Move a directory *)
  val move: t -> t -> unit

  (** Copy a directory *)
  val copy: t -> t -> unit

  (** Does the directory exists ? *)
  val exists: t -> bool

  (** Return the parent directory *)
  val dirname: t -> t

  (** Return the deeper directory name *)
  val basename: t -> basename

  (** Creation from a raw string (as {i http://<path>}) *)
  val raw: string -> t

  (** Remove a prefix from a directory *)
  val remove_prefix: prefix:t -> t -> string

  (** Does the directory starts with a given prefix *)
  val starts_with: prefix:t -> t -> bool

  (** Execute a function in a temp directory *)
  val with_tmp_dir: (t -> 'a) -> 'a

end

(** Shortcut to directory type *)
type dirname = Dirname.t

(** Concatenate a directory and a string *)
val (/): dirname -> string -> dirname

(** Raw file contents *)
module Raw: ABSTRACT

(** Shortcut to raw file content type *)
type raw = Raw.t

(** Stdlib [Filename] module *)
module Stdlib_filename: sig
  val check_suffix: string -> string -> bool
  val concat: string -> string -> string
  val basename: string -> string
end

(** non-directory filenames *)
module Filename: sig

  include ABSTRACT

  (** Create a filename from a dirname and a basename *)
  val create: dirname -> basename -> t

  (** Create a file from a basename and the current working directory
      as dirname *)
  val of_basename: basename -> t

  (** Creation from a raw string (as {i http://<path>}) *)
  val raw: string -> t

  (** Return the directory name *)
  val dirname: t -> dirname

  (** Return the base name *)
  val basename: t -> basename

  (** Retrieves the contents from the hard disk. *)
  val read: t -> Raw.t

  (** Removes everything in [filename] if existed. *)
  val remove: t -> unit

  (** Removes everything in [filename] if existed, then write [contents] instead. *)
  val write: t -> Raw.t -> unit

  (** see [Sys.file_exists] *)
  val exists: t -> bool

  (** Check whether a file has a given suffix *)
  val check_suffix: t -> string -> bool

  (** Add a file extension *)
  val add_extension: t -> string -> t

  (** Remove the file extension *)
  val chop_extension: t -> t

  (** List all the filenames (ie. which are not directories) in a directory *)
  val list: dirname -> t list

  (** List all the filenames, recursively *)
  val rec_list: dirname -> t list

  (** Apply a function on the contents of a file *)
  val with_raw: (Raw.t -> 'a) -> t -> 'a

  (** Copy a file in a directory *)
  val copy_in: t -> dirname -> unit

  (** Move a file *)
  val move: t -> t -> unit

  (** Symlink a file in a directory *)
  val link_in: t -> dirname -> unit

  (** Copy a file *)
  val copy: t -> t -> unit

  (** Symlink a file. If symlink is not possible on the system, use copy instead. *)
  val link: t -> t -> unit

  (** Extract an archive in a given directory (it rewrites the root to
      match [dirname] dir if needed) *)
  val extract: t -> dirname -> unit

  (** Extract an archive in a given directory (which should already exists) *)
  val extract_in: t -> dirname -> unit

  (** Check wether a filename starts by a given dirname *)
  val starts_with: dirname -> t -> bool

  (** Remove a prefix from a file name *)
  val remove_prefix: prefix:dirname -> t -> string

  (** download a remote file in a given directory. Return the location
      of the downloaded file if the download is successful.  *)
  val download: t -> dirname -> t option

  (** iterate downloads until one is sucessful *)
  val download_iter: t list -> dirname -> t option

  (** Apply a patch to a directory *)
  val patch: t -> dirname -> bool

  (** Compute the MD5 digest of a file *)
  val digest: t -> string

  (** Create an empty file *)
  val touch: t -> unit

  (** Change file permissions *)
  val chmod: t -> int -> unit

end

(** Shortcut to file names *)
type filename = Filename.t

(** Generalized file type *)
type file =
  | D of dirname
  | F of filename


(** Download result *)
type 'a download =
  | Up_to_date of 'a
  | Not_available
  | Result of 'a

(** Concatenate a directory and a string to create a filename *)
val (//): dirname -> string -> filename

(** {2 Package name and versions} *)

(** Versions *)
module V: ABSTRACT

(** Shortcut to V.t *)
type version = V.t

(** Names *)
module N: ABSTRACT

(** Shortcut to N.t *)
type name = N.t

(** Package (name x version) pairs *)
module NV: sig
  include ABSTRACT

  (** Return the package name *)
  val name: t -> name

  (** Return the version name *)
  val version: t -> version

  (** Create a new pair (name x version) *)
  val create: name -> version -> t

  (** Create a new pair from a filename. This function extracts {i
      $name} and {i $version} from {i /path/to/$name.$version.XXX}
      with various heuristics.*)
  val of_filename: filename -> t option

  (** Create a new pair from a directory name. This function extracts {i
      $name} and {i $version} from {i /path/to/$name.$version/} *)
  val of_dirname: dirname -> t option

  (** Create a new pair from a debian package *)
  val of_dpkg: Debian.Packages.package -> t

  (** Create a new pair from a cudf package *)
  val of_cudf: Debian.Debcudf.tables -> Cudf.package -> t

  (** Convert a set of pairs to a map [name -> versions] *)
  val to_map: Set.t -> V.Set.t N.Map.t

end


(** Shortcut to NV.t *)
type nv = NV.t


type relop = [`Eq|`Geq|`Gt|`Leq|`Lt]

(** OCaml version *)
module OCaml_V: sig
  include ABSTRACT

  (** Return the version of the compiler currently installed *)
  val current: unit -> t option

  (** Compare OCaml versions *)
  val compare: t -> relop -> t -> bool
end

(** OPAM version *)
module OPAM_V: ABSTRACT

(** {2 Repositories} *)

(** OPAM repositories *)
module Repository: sig

  include ABSTRACT

  (** Create a repository *)
  val create: name:string -> kind:string -> address:string -> t

  (** Default repository *)
  val default: t
  
  (** Get the repository name *)
  val name: t -> string
  
  (** Get the repository kind *)
  val kind: t -> string

  (** Get the repository address *)
  val address: t -> dirname

  (** Return a copy of repo with a different kind *)
  val with_kind: t -> string -> t

end

(** Shortcut to repository type *)
type repository = Repository.t

(** {2 Variable names} *)

(** Variable names are used in .config files *)
module Variable: sig
  include ABSTRACT

  (** the variable [enable] *)
  val enable: t

  (** the variable [installed] *)
  val installed: t
end

(** Shortcut to variable type *)
type variable = Variable.t

(** Section names *)
module Section: sig 

  include ABSTRACT

  (** Graph of fully-qualified sections *)
  module G : Graph.Sig.I with type V.t = t

  (** Iteration in topological order *)
  val graph_iter : (G.V.t -> unit) -> G.t -> unit
end

(** Shortcut to section names *)
type section = Section.t

(** Fully qualified sections *)
module Full_section: sig

  include ABSTRACT

  (** Create a fully qualified section *)
  val create: name -> section -> t

  (** All the sections in a package *)
  val all: name ->  t

  (** Return the package name in which the section is *)
  val package: t -> name

  (** Return the optional section name: [None] means all available
      sections. *)
  val section: t -> section option

end

type full_section = Full_section.t

(** Fully qualified variables *)
module Full_variable: sig

  include ABSTRACT
  
  (** Create a variable local for a given library/syntax extension *)
  val create_local: name -> section -> variable -> t

  (** Create a global variable for a package *)
  val create_global: name -> variable -> t

  (** Return the package the variable is defined in *)
  val package: t -> name

  (** Return the section (library or syntax extension) the package is
      defined in *)
  val section: t -> section option

  (** Return the variable name *)
  val variable: t -> variable

end

(** Shortcut to fully qualified variables *)
type full_variable = Full_variable.t

(** Content of user-defined variables *)
type variable_contents =
  | B of bool
  | S of string

(** Convert the content of a variable to a string *)
val string_of_variable_contents: variable_contents -> string

(** Content of [pp] variables *)
type ppflag =
  | Camlp4 of string list
  | Cmd of string list

(** {2 Command line arguments} *)

(** Upload arguments *)
type upload = {
  opam   : filename;
  descr  : filename;
  archive: filename;
}

(** Pretty-print *)
val string_of_upload: upload -> string

(** Remote arguments *)
type remote =
  | List
  | Add of repository
  | Rm of string

(** Pretty-print or remote args *)
val string_of_remote: remote -> string

(** Pinned packages options *)
type pin_option =
  | Version of version
  | Path of dirname
  | Unpin

(** Pinned packages *)
type pin = {
  pin_package: name;
  pin_arg: pin_option;
}

(** Pretty-printing of pinned packages *)
val string_of_pin: pin -> string

(** Read pin options args *)
val pin_option_of_string: string -> pin_option

val string_of_pin_option: pin_option -> string

(** Configuration requests *)
type config_option = {
  is_rec : bool;
  is_byte: bool;
  is_link: bool;
  options: full_section list;
}

type config =
  | Env
  | List_vars
  | Variable of full_variable
  | Includes of bool * (name list)
  | Compil   of config_option
  | Subst    of basename list

(** Pretty-print *)
val string_of_config: config -> string

(** Compiler aliases *)
module Alias: ABSTRACT

type atom_formula = Debian.Format822.vpkg
type and_formula = atom_formula list

(** Pretty-print *)
val string_of_atom_formula : atom_formula -> string

type cnf_formula = Debian.Format822.vpkgformula
type ocaml_constraint = relop * OCaml_V.t

module Remote_file: sig
  include ABSTRACT

  (** Get remote filename *)
  val base: t -> basename
  
  (** MD5 digest or the remote file *)
  val md5: t -> string

  (** File permission *)
  val perm: t -> int option

  (** Constructor*)
  val create: basename -> string -> int -> t
end
