(***********************************************************************)
(*                                                                     *)
(*    Copyright 2012 OCamlPro                                          *)
(*    Copyright 2012 INRIA                                             *)
(*                                                                     *)
(*  All rights reserved.  This file is distributed under the terms of  *)
(*  the GNU Public License version 3.0.                                *)
(*                                                                     *)
(*  TypeRex is distributed in the hope that it will be useful,         *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of     *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the      *)
(*  GNU General Public License for more details.                       *)
(*                                                                     *)
(***********************************************************************)

open Types

(** Global state *)
module G : sig

  (** Contains [$opam] *)
  type t

  val create: dirname -> t

  (** Root dir: [$opam/] *)
  val root: t -> dirname

  (** Main configuration file: [$opam/config] *)
  val config: t -> filename

  (** OPAM files: [$opam/opam/$NAME.$VERSION.opam] *)
  val opam: t -> NV.t -> filename

  (** List all the available packages:
      [$opam/opam/$NAME.$VERSION.opam] *)
  val available: t -> NV.Set.t

  (** List all the available packages:
      [$opam/opam/$NAME.$VERSION.opam] *)
  val available_versions: t -> N.t -> V.Set.t

  (** Description file: [$opam/descr/$NAME.$VERSION] *)
  val descr: t -> NV.t -> filename

  (** Archives files: [$opam/archives/$NAME.$VERSION.tar.gz] *)
  val archive: t -> NV.t -> filename

  (** OPAM files folder: [$opam/opam/] *)
  val opam_dir: t -> dirname

  (** Description files folder: [$opam/descr/] *)
  val descr_dir: t -> dirname

  (** Archives files folder: [$opam/archives/] *)
  val archive_dir: t -> dirname

  (** Return the repository index: [$opam/repo/index] *)
  val repo_index: t -> filename

end

(** Compiler-version related state *)
module C : sig

  (** Contains [$opam] and [$OVERSION] *)
  type t
    
  val create: G.t -> OCaml_V.t -> t

  (** Installed libraries for the package:
      [$opam/$OVERSION/lib/NAME] *)
  val lib: t -> N.t -> dirname

  (** Installed binaries: [$opam/$OVERSION/bin] *)
  val bin: t -> dirname

  (** List of installed packages with their version:
      [$opam/$OVERSION/installed] *)
  val installed: t -> filename

  (** Tempory folders used to decompress the corresponding archives:
      [$opam/$OVERSION/build/$NAME-$VERSION] *)
  val build: t -> NV.t -> dirname

  (** Tempory folder: [$opam/$OVERSION/build] *)
  val build_dir: t -> dirname

  (** Installed files for a given package:
      [$opam/$OVERSION/install/$NAME.install] *)
  val install: t -> N.t -> filename

  (** Installed files: [$opam/$OVERSION/install/] *)
  val install_dir: t -> dirname
    
  (** Packages to reinstall on next upgrade:
      [$opam/$OVERSION/reinstall] *)
  val reinstall: t -> filename

  (** Compile and link flags for a given package:
      [$opam/$OVERSION/config/$NAME.config] *)
  val config: t -> N.t -> filename

  (** Configuration folder: [$opam/$OVERSION/config] *)
  val config_dir: t -> dirname

end

module R : sig

  type t

  (** Create a repository path *)
  val create: G.t -> repository -> t

  (** Transform a directory name into a repository path *)
  val of_path: dirname -> t

  (** Return the repository folder: [$opam/repo/$repo] *)
  val root: t -> dirname

  (** Return the repository config: [$opam/repo/$repo/config] *)
  val config: t -> filename

  (** Return the OPAM file for a given package:
      [$opam/repo/$repo/opam/$NAME.$VERSION.opam] *)
  val opam: t -> NV.t -> filename

  (** Return the OPAM folder: [$opam/repo/$repo/opam/] *)
  val opam_dir: t -> dirname

  (** List all the available packages:
      [$opam/repo/$repo/$NAME.$VERSION.opam] *)
  val available: t -> NV.Set.t

  (** List all the available versions for a given package:
      [$opam/repo/$repo/$name.$VERSION.opam] *)
  val available_versions: t -> N.t -> V.Set.t

  (** Return the description file for a given package:
      [$opam/repo/$repo/descr/$NAME.VERSION] *)
  val descr: t -> NV.t -> filename

  (** Return the description folder *)
  val descr_dir: t -> dirname

  (** Return the archive for a giben package:
      [$opam/repo/$repo/archives/$NAME.$VERSION.tar.gz *)
  val archive: t -> NV.t -> filename

  (** Return the archive folder: [$opam/repo/$repo/archives/] *)
  val archive_dir: t -> dirname

  (** Return the list of updated packages:
      [$opam/repo/$repo/updated] *)
  val updated: t -> filename

  (** Return the upload folder for a given version:
      [$opam/repo/$repo/upload/$NAME.$VERSION/] *)
  val upload: t -> NV.t -> dirname

  (** Return the upload folder for OPAM files:
      [$opam/repo/$repo/upload/$NAME.$VERSION/$NAME.$VERSION.opam]*)
  val upload_opam: t -> NV.t -> filename

  (** Return the upload folder for descr files:
      [$opam/repo/$repo/upload/$NAME.$VERSION/$NAME.$VERSION] *)
  val upload_descr: t -> NV.t -> filename

  (** Return the upload folder for archive files:
      [$opam/repo/$repo/upload/$NAME.$VERSION/$NAME.$VERSION.tar.gz] *)
  val upload_archive: t -> NV.t -> filename

  (** Return the upload folder: [$opam/repo/$repo/upload] *)
  val upload_dir: t -> dirname

end