.POSIX:

.SUFFIXES: .cc .c .m .o .S

MAJOR_VERSION = 4
MINOR_VERSION = 6
SUBMINOR_VERSION = 0
VERSION ?= $(MAJOR_VERSION).$(MINOR_VERSION).$(SUBMINOR_VERSION)

LIBOBJCLIBNAME=objc
LIBOBJC=libobjc
LIBOBJCXX=libobjcxx

INSTALL ?= install
SILENT ?= @

CFLAGS += -std=gnu99 -fPIC -fexceptions
#CFLAGS += -Wno-deprecated-objc-isa-usage
CXXFLAGS += -fPIC -fexceptions
CPPFLAGS += -DTYPE_DEPENDENT_DISPATCH -DGNUSTEP
CPPFLAGS += -D__OBJC_RUNTIME_INTERNAL__=1 -D_XOPEN_SOURCE=500 -D__BSD_VISIBLE=1 -D_BSD_SOURCE=1

# Suppress warnings about incorrect selectors
CPPFLAGS += -DNO_SELECTOR_MISMATCH_WARNINGS

# Some helpful flags for debugging.
ifeq ($(debug), yes)
  CPPFLAGS += -g -O0 -fno-inline
  OBJCFLAGS += -fno-inline
  CPPFLAGS += -DGC_DEBUG
else
  CPP_FLAGS += -O3
endif

# Hack to support -03 and get the __sync_* GCC builtins work
# -O3 requires -march=i586 on Linux x86-32, otherwise Clang compiles 
# programs that segfaults if -fobjc-nonfragile-abi is used.
ifneq ($(findstring gcc, $(CC)),) 
  # TODO: Detect target CPU even if GNUstep.sh is not sourced
  ifeq ($(GNUSTEP_TARGET_CPU), ix86)
    CFLAGS += -march=i586
  endif
endif

# Hack to get mingw to provide declaration for strdup (since it is non-standard)
# TODO: Detect mingw32 target even if GNUstep.sh is not sourced
ifeq ($(GNUSTEP_TARGET_OS), mingw32)
  ${LIBOBJC}_CPPFLAGS += -U__STRICT_ANSI__
endif

ifeq ($(findstring openbsd, `$CC -dumpmachine`), openbsd)
  LDFLAGS += -pthread 
else
  LDFLAGS += -lpthread 
endif

ASMFLAGS += `if $(CC) -v 2>&1| grep -q 'clang' ; then echo -no-integrated-as ; fi`

THE_LD=`if [ "$(LD)" = "" ]; then echo "ld"; else echo "$(LD)"; fi` 

STRIP=`if [ "$(strip)" = "yes" ] ; then echo -s ; fi`


PREFIX?= /usr/local
LIB_DIR= ${PREFIX}/lib
HEADER_DIR= ${PREFIX}/include

OBJCXX_OBJECTS = \
	objcxx_eh.o

OBJECTS = \
	NSBlocks.o\
	Protocol2.o\
	abi_version.o\
	alias_table.o\
	arc.o\
	associate.o\
	blocks_runtime.o\
	block_to_imp.o\
	block_trampolines.o\
	objc_msgSend.o\
	caps.o\
	category_loader.o\
	class_table.o\
	dtable.o\
	eh_personality.o\
	encoding2.o\
	gc_none.o\
	hash_table.o\
	hooks.o\
	ivar.o\
	legacy_malloc.o\
	loader.o\
	mutation.o\
	properties.o\
	protocol.o\
	runtime.o\
	sarray2.o\
	selector_table.o\
	sendmsg2.o\
	statics_loader.o\
	toydispatch.o

all: $(LIBOBJC).a $(LIBOBJCXX).so.$(VERSION)

$(LIBOBJCXX).so.$(VERSION): $(LIBOBJC).so.$(VERSION) $(OBJCXX_OBJECTS)
	$(SILENT)echo Linking shared Objective-C++ runtime library...
	$(SILENT)$(CXX) -shared \
            -Wl,-soname=$(LIBOBJCXX).so.$(MAJOR_VERSION) $(LDFLAGS) \
            -o $@ $(OBJCXX_OBJECTS) $(LDFLAGS)

$(LIBOBJC).so.$(VERSION): $(OBJECTS)
	$(SILENT)echo Linking shared Objective-C runtime library...
	$(SILENT)$(CC) -shared -rdynamic \
            -Wl,-soname=$(LIBOBJC).so.$(MAJOR_VERSION) $(LDFLAGS) \
            -o $@ $(OBJECTS) $(LDFLAGS)

$(LIBOBJC).a: $(OBJECTS)
	$(SILENT)echo Linking static Objective-C runtime library...
	$(SILENT)$(THE_LD) -r -s -o $@ $(OBJECTS)

.cc.o: Makefile
	$(SILENT)echo Compiling `basename $<`...
	$(SILENT)$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

.c.o: Makefile
	$(SILENT)echo Compiling `basename $<`...
	$(SILENT)$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

.m.o: Makefile
	$(SILENT)echo Compiling `basename $<`...
	$(SILENT)$(CC) $(CPPFLAGS) $(CFLAGS) -fobjc-exceptions -c $< -o $@

.S.o: Makefile
	$(SILENT)echo Assembling `basename $<`...
	$(SILENT)$(CC) $(CPPFLAGS) $(ASMFLAGS) -c $< -o $@

$(INSTALL): all
	$(SILENT)echo Installing libraries...
	$(SILENT)install -d $(LIB_DIR)
	$(SILENT)install -m 444 $(STRIP) $(LIBOBJC).so.$(VERSION) $(LIB_DIR)
	$(SILENT)install -m 444 $(STRIP) $(LIBOBJCXX).so.$(VERSION) $(LIB_DIR)
	$(SILENT)install -m 444 $(STRIP) $(LIBOBJC).a $(LIB_DIR)
	$(SILENT)echo Creating symbolic links...
	$(SILENT)ln -sf $(LIBOBJC).so.$(VERSION) $(LIB_DIR)/$(LIBOBJC).so
	$(SILENT)ln -sf $(LIBOBJC).so.$(VERSION) $(LIB_DIR)/$(LIBOBJC).so.$(MAJOR_VERSION)
	$(SILENT)ln -sf $(LIBOBJC).so.$(VERSION) $(LIB_DIR)/$(LIBOBJC).so.$(MAJOR_VERSION).$(MINOR_VERSION)
	$(SILENT)ln -sf $(LIBOBJCXX).so.$(VERSION) $(LIB_DIR)/$(LIBOBJCXX).so
	$(SILENT)ln -sf $(LIBOBJCXX).so.$(VERSION) $(LIB_DIR)/$(LIBOBJCXX).so.$(MAJOR_VERSION)
	$(SILENT)ln -sf $(LIBOBJCXX).so.$(VERSION) $(LIB_DIR)/$(LIBOBJCXX).so.$(MAJOR_VERSION).$(MINOR_VERSION)
	$(SILENT)echo Installing headers...
	$(SILENT)install -d $(HEADER_DIR)/objc
	$(SILENT)install -m 444 objc/*.h $(HEADER_DIR)/objc

clean:
	$(SILENT)echo Cleaning...
	$(SILENT)rm -f $(OBJECTS)
	$(SILENT)rm -f $(OBJCXX_OBJECTS)
	$(SILENT)rm -f $(LIBOBJC).so.$(VERSION)
	$(SILENT)rm -f $(LIBOBJCXX).so.$(VERSION)
	$(SILENT)rm -f $(LIBOBJC).a
