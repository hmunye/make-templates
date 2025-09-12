### Binary name
###
### (=) deferred assignment (value is expanded only when used)
BIN =

### Directory paths containing source files (.c files)
SRCDIRS =

### Directory paths containing header files (.h files)
INCDIRS =

### Directory path for compiled object/dependency files
BUILDDIR =

### Compiler to use. Default is GCC, but can be overridden (e.g., make CC=clang)
###
### (?=) conditional assignment (value is only assigned if not already set)
# CC ?= gcc
CC = gcc

### C standard to use for compilation
CSTD = c11

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
# CFLAGS += $(INCLUDES) $(LDFLAGS)
CFLAGS += $(INCLUDES)

### Iterate over SRCDIRS and use `wildcard` to list all .c files in each directory
CFILES = $(foreach DIR,$(SRCDIRS),$(wildcard $(DIR)/*.c))

### Declare object/dependency file paths to generate in build 
OBJFILES = $(patsubst $(SRCDIRS)/%.c, $(BUILDDIR)/%.o, $(CFILES))
DEPFILES = $(OBJFILES:.o=.d)

### Default target to build
.DEFAULT_GOAL := all

### Declare targets that do not represent actual files
.PHONY: all debug clean help clang-analyze memcheck

all: 
ifeq ($(findstring clang,$(CC)), clang)
	@$(MAKE) --no-print-directory clang-analyze
endif
	@$(MAKE) --no-print-directory $(BIN)

debug: CFLAGS += $(DFLAGS)
debug: all

### $@: expands to the target name (i.e., BIN)
### $^: expands to all prerequisites (i.e., all object files)
$(BIN): CFLAGS += $(DEPFLAGS)
$(BIN): $(OBJFILES)
	$(CC) -o $@ $^

### $(dir $@): extracts the directory part of the target name
### $<: expands to first prerequisite (i.e., the .c file to compile)
$(BUILDDIR)/%.o: $(SRCDIRS)/%.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -o $@ -c $<

### Removes all generated files (object/dependency files, binary, build directory)
clean:
	@rm -rf $(BUILDDIR) $(BIN) main_*

help:
	@echo "Available targets:"
	@echo "  all      - Build binary ($(BIN))"
	@echo "  debug    - Build binary with debugging symbols and _DEBUG macro"
	@echo "  clean    - Remove all generated files and directories"
	@echo "  help     - Show help message"

### --analyze: enable Clang static analyzer (compile-time analysis)
clang-analyze: $(CFILES)
	$(CC) $(CFLAGS) --analyze --analyzer-output text $^ 

memcheck: debug
	@valgrind --leak-check=full --track-origins=yes --show-leak-kinds=all -s ./$(BIN)

### Include dependency files if they exist (for accurate incremental builds)
-include $(DEPFILES)
