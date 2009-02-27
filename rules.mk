
VPATH = $(srcdir)

CPPFLAGS += -I$(top_srcdir) -I$(top_srcdir)/lib -I$(builddir)

# we need paths to be overridable at build-time
DEFS += '-DPREFIX="$(prefix)"' '-DPKG_SHARE_DIR="$(pkgdatadir)"' \
	'-DLOCAL_STATE_DIR="$(localstatedir)"'

# programs
pb_discover = discover/pb-discover
pb_cui = ui/ncurses/pb-cui
pb_test = ui/test/pb-test
pb_twin = ui/twin/pb-twin
parser_test = test/parser-test

# install targets and components
daemons = $(pb_discover)
#parsers = kboot native yaboot (todo)
parsers = kboot
uis = $(pb_test)
tests = $(parser_test)

ifeq ($(PBTWIN),y)
	uis += $(pb_twin)
endif

# other to install
artwork = background.jpg cdrom.png hdd.png usbpen.png tux.png cursor.gz
rules = utils/99-petitboot.rules

# client/daemon lib objs
list_objs = lib/list/list.o
log_objs = lib/log/log.o
protocol_objs = lib/pb-protocol/pb-protocol.o
talloc_objs = lib/talloc/talloc.o
waiter_objs = lib/waiter/waiter.o

# daemon objs
parser_objs = discover/parser.o discover/parser-utils.o \
	$(foreach p, $(parsers), discover/$(p)-parser.o)
discover_objs = discover/udev.o discover/discover-server.o \
	discover/device-handler.o discover/paths.o

# client objs
ui_common_objs = ui/common/discover-client.o
ncurses_objs =
twin_objs = ui/twin/pb-twin.o

# object collections
lib_objs = $(list_objs) $(log_objs) $(protocol_objs) $(talloc_objs) \
	$(waiter_objs)

daemon_objs = $(lib_objs) $(parser_objs) $(discover_objs)

client_objs = $(lib_objs) $(ui_common_objs)

all: $(uis) $(daemons)

# ncurses cui
pb_cui_objs = $(client_objs) $(ncurses_objs) ui/ncurses/ps3-cui.o

$(pb_cui): LDFLAGS += -lncurses

$(pb_cui): $(pb_cui_objs)
	$(LINK.o) -o $@ $^

# test ui
pb_test_objs = $(client_objs) ui/test/pb-test.o

$(pb_test): $(pb_test_objs)
	$(LINK.o) -o $@ $^

# twin gui
pb_twin_objs = $(client_objs) $(twin_objs) ui/twin/ps3-twin.o

$(pb_twin): LDFLAGS+=$(twin_LDFLAGS) $(LIBTWIN)
$(pb_twin): CFLAGS+=$(twin_CFLAGS)

$(pb_twin): $(pb_twin_objs)
	$(LINK.o) -o $@ $^

# discovery daemon
pb_discover_objs = $(daemon_objs) discover/pb-discover.o

$(pb_discover): $(pb_discover_objs)
	$(LINK.o) -o $@ $^

# parser-test
parser_test_objs = $(parser_objs) test/parser-test.o

$(parser_test): $(parser_test_objs)
	$(LINK.o) -o $@ $^

parser-test: $(parser_test)

install: all $(rules)
	$(INSTALL) -d $(DESTDIR)$(sbindir)/
	$(INSTALL) $(daemons) $(uis) $(DESTDIR)$(sbindir)/
	$(INSTALL) -d $(DESTDIR)$(pkgdatadir)/artwork/
	$(INSTALL) $(addprefix $(top_srcdir)/ui/twin/artwork/,$(artwork)) \
		$(DESTDIR)$(pkgdatadir)/artwork/
	$(INSTALL) -d $(DESTDIR)$(pkgdatadir)/utils
	$(INSTALL) $(top_srcdir)/$(rules) $(DESTDIR)$(pkgdatadir)/utils

dist: $(PACKAGE)-$(VERSION).tar.gz

check: parser-test
	$(SHELL) test/parser-test.sh

distcheck: dist
	tar -xvf $(PACKAGE)-$(VERSION).tar.gz
	cd $(PACKAGE)-$(VERSION) && make check

$(PACKAGE)-$(VERSION).tar.gz: $(PACKAGE)-$(VERSION)
	tar czvf $@ $^

$(PACKAGE)-$(VERSION): clean
	for f in $$(git-ls-files); do \
		d=$@/$$(dirname $$f); \
		mkdir -p $$d; \
		cp -a $$f $$d; \
	done

clean:
	rm -rf $(PACKAGE)-$(VERSION)
	rm -f $(uis)
	rm -f $(pb_cui_objs)
	rm -f $(pb_test_objs)
	rm -f $(pb_twin_objs)
	rm -f $(daemons)
	rm -f $(pb_discover_objs)
	rm -f $(tests)
	rm -f $(parser_test_objs)

maintainer-clean: clean
	-rm -f $(top_srcdir)/aclocal.m4
	-rm -rf $(top_srcdir)/autom4te.cache
	-rm -f $(top_srcdir)/config.h.in
	-rm -f $(top_srcdir)/configure
	-rm -f config.h
	-rm -f config.log
	-rm -f config.status
	-rm -f Makefile
	-rm -f $(PACKAGE)-$(VERSION).tar.gz
