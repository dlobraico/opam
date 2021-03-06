include Makefile.config

LOCAL_OCPBUILD=./ocp-build/ocp-build
OCPBUILD ?= $(LOCAL_OCPBUILD)
SRC_EXT=src_ext
TARGETS = opam opam-mk-repo opam-repo-convert-0.3

.PHONY: all

all: $(LOCAL_OCPBUILD) META
	$(MAKE) clone
	$(MAKE) compile

scan: $(LOCAL_OCPBUILD)
	$(OCPBUILD) -scan
sanitize: $(LOCAL_OCPBUILD)
	$(OCPBUILD) -sanitize
byte: $(LOCAL_OCPBUILD)
	$(OCPBUILD) -byte
opt: $(LOCAL_OCPBUILD)
	$(OCPBUILD) -asm

$(LOCAL_OCPBUILD): ocp-build/ocp-build.boot ocp-build/win32_c.c
	$(MAKE) -C ocp-build

compile: $(LOCAL_OCPBUILD)
	$(OCPBUILD) -init -scan -sanitize $(TARGET)

clone:
	$(MAKE) -C $(SRC_EXT)

clean:
	rm -rf _obuild
	rm -rf src/*.annot bat/*.annot
	rm -f opam
	rm -f ocp-build.*
	$(MAKE) -C $(SRC_EXT) clean
	$(MAKE) -C ocp-build clean

distclean: clean
	rm -f *.tar.gz *.tar.bz2
	rm -rf _obuild _build
	$(MAKE) -C $(SRC_EXT) distclean

.PHONY: tests

tests:
	$(MAKE) -C tests all

tests-rsync:
	$(MAKE) -C tests rsync

tests-git:
	$(MAKE) -C tests git

%-install:
	cp _obuild/$*/$*.asm $(prefix)/bin/$*

META: META.in
	sed 's/@VERSION@/$(version)/g' < $< > $@

.PHONY: install
install:
	mkdir -p $(prefix)/bin
	$(MAKE) $(TARGETS:%=%-install)
	mkdir -p $(mandir)/man1 && cp doc/man/* $(mandir)/man1

uninstall:
	rm -f $(prefix)/bin/opam*
	rm -f $(mandir)/man1/opam*

doc: compile
	mkdir -p doc/html/
	ocamldoc \
	  -I _obuild/opam-lib -I _obuild/cudf -I _obuild/dose \
	  -I _obuild/bat -I _obuild/unix -I _obuild/extlib \
	  -I _obuild/arg -I _obuild/graph \
	  src/*.mli -html -d doc/html/
	$(MAKE) -C doc/man-src

trailing:
	find src -name "*.ml*" -exec \
	  sed -i xxx -e :a -e "/^\n*$$/{$$d;N;ba" -e '}' {} \;
	find src -name "*xxx" -exec rm {} \;

archive:
	echo $(ARCHIVES)
	$(MAKE) distclean
	$(MAKE) clone
	tar cz $(wildcard src_ext/*.tar.gz) > opam-extfiles.1.tar.gz

configure: configure.ac m4/*.m4
	aclocal -I m4
	autoconf