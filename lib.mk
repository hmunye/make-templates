### Library name (with "lib" prefix, without file extension)
###
### (=) deferred assignment (value is expanded only when used)
LIBNAME =

### Directory paths containing source files (.c files)
SRCDIRS = 

### Directory paths containing header files (.h files)
INCDIRS = 

### Directory path for compiled object/dependency files
BUILDDIR =

### Compiler to use. Default is GCC, but can be overridden (e.g., make CC=clang)
###
### (?=) conditional assignment (value is only assigned if not already set)
CC ?= gcc

### C standard to use for compilation
CSTD = c99

### Compiler flags
###
### -fanalyzer: enable GCC static analyzer (compile-time analysis)
###
### `findstring` used to allow specifying different GCC versions (e.g., make CC=gcc-14)
###
### (:=) immediate assignment (value is immediately expanded and assigned)
ifeq ($(findstring gcc,$(CC)), gcc)
	CFLAGS := -Wall -Wextra -Werror -Wconversion -std=$(CSTD) -Wpedantic -fanalyzer
else
	CFLAGS := -Wall -Wextra -Werror -Wconversion -std=$(CSTD) -Wpedantic
endif

### Iterate over INCDIRS and generate include flags
INCLUDES = $(foreach DIR,$(INCDIRS),-I$(DIR))

### Flags for tracking header dependencies to ensure only changed files are recompiled
###
### -MP: add phony targets for missing headers
### -MD: generate .d files for each .c file
DEPFLAGS = -MP -MD

### Debug flags
DFLAGS = -D_DEBUG -g2

### Linker flags
LDFLAGS =

### (+=) append value(s) to a variable
CFLAGS += $(INCLUDES)

STATIC_LIB = $(LIBNAME).a
SHARED_LIB = $(LIBNAME).so

### Iterate over SRCDIRS and use `wildcard` to list all .c files in each directory
CFILES = $(foreach DIR,$(SRCDIRS),$(wildcard $(DIR)/*.c))

### Declare separate directories for shared and static builds
SHAREDDIR = $(BUILDDIR)/shared
STATICDIR = $(BUILDDIR)/static

### Declare object/dependency file paths to generate in build 
SHAREDOBJFILES = $(patsubst $(SRCDIRS)/%.c, $(SHAREDDIR)/%.o, $(CFILES))
SHAREDDEPFILES = $(SHAREDOBJFILES:.o=.d)
STATICOBJFILES = $(patsubst $(SRCDIRS)/%.c, $(STATICDIR)/%.o, $(CFILES))
STATICDEPFILES = $(STATICOBJFILES:.o=.d)

### Default target to build
.DEFAULT_GOAL := all

### Declare targets that do not represent actual files
.PHONY: all static shared debug clean help clang-analyze

all: static shared

static: 
ifeq ($(findstring clang,$(CC)), clang)
	@$(MAKE) --no-print-directory clang-analyze
endif
	@$(MAKE) --no-print-directory $(STATIC_LIB)

shared:
ifeq ($(findstring clang,$(CC)), clang)
	@$(MAKE) --no-print-directory clang-analyze
endif
	@$(MAKE) --no-print-directory $(SHARED_LIB)

debug: CFLAGS += $(DFLAGS)
debug: all

### $@: expands to the target name (i.e., STATIC_LIB)
### $^: expands to all prerequisites (i.e., all static object files)
###
### `ar` is an archiver tool used to create static libraries
$(STATIC_LIB): CFLAGS += $(DEPFLAGS)
$(STATIC_LIB): $(STATICOBJFILES)
	ar rcs $@ $^

### $@: expands to the target name (i.e., SHARED_LIB)
### $^: expands to all prerequisites (i.e., all shared object files)
###
### -shared: directs the compiler to generate a shared library for dynamic linking
$(SHARED_LIB): CFLAGS += $(DEPFLAGS)
$(SHARED_LIB): $(SHAREDOBJFILES)
	$(CC) -shared -o $@ $^ $(LDFLAGS)

### $(dir $@): extracts the directory part of the target name
### $<: expands to first prerequisite (i.e., the .c file to compile)
###
### -flto: enable Link Time Optimization (LTO)
$(STATICDIR)/%.o: $(SRCDIRS)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -flto -o $@ -c $<

### $(dir $@): extracts the directory part of the target name
### $<: expands to first prerequisite (i.e., the .c file to compile)
###
### -fPIC (Position Independent Code): allows the code to be loaded at any memory address
$(SHAREDDIR)/%.o: $(SRCDIRS)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -flto -fPIC -o $@ -c $<

### Removes all generated files (object/dependency files, libraries, build directory)
clean:
	@rm -rf $(BUILDDIR) $(STATIC_LIB) $(SHARED_LIB) main_*

help:
	@echo "Available targets:"
	@echo "  all      - Build both static and shared libraries ($(STATIC_LIB), $(SHARED_LIB))"
	@echo "  static   - Build only the static library ($(STATIC_LIB))"
	@echo "  shared   - Build only the shared library ($(SHARED_LIB))"
	@echo "  debug    - Build both libraries with debugging symbols and _DEBUG macro"
	@echo "  clean    - Remove all generated files and directories"
	@echo "  help     - Show help message"

### --analyze: enable Clang static analyzer (compile-time analysis)
clang-analyze: $(CFILES)
	$(CC) $(CFLAGS) --analyze --analyzer-output text $^ 

### Link with the static library; object code is copied directly into final binary
###
### `-flto` flag should be used both during compilation and linking
### 
### $(CC) -o <bin> <source(s)> $(CFLAGS) -flto $(STATIC_LIB) $(LDFLAGS)

### Link with the shared library; only symbol references are included, library code is loaded at runtime
### 
### `-flto` flag should be used both during compilation and linking
###
###	$(CC) -o <bin> <source(s)> $(CFLAGS) -flto -L. -l<lib> $(LDFLAGS)

### LD_LIBRARY_PATH is used to locate shared library at runtime (current directory)
###
### LD_LIBRARY_PATH=. ./<shared-bin>

### Include dependency files if they exist (for accurate incremental builds)
-include $(SHAREDDEPFILES) $(STATICDEPFILES)
