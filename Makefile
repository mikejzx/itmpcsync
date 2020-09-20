# Compiler flags, etc.
CC = g++
CFLAGS = -std=c++17 -Wall -I./src -DPLATFORM_UNIX -D_GNU_SOURCE
LDFLAGS =

# Utils
RM = rm
MKDIR = mkdir

# Project stuff.
PROJECT = itxmlconvert

# Source files, objs, and dependencies:
SRCS = $(shell find src -name '*.cpp' | grep -P '.*\.*cpp$$')
DIRS = $(shell find src -type d | sed 's/src/./g')
OBJS = $(patsubst src/%.cpp,bin/intermed/%.o,$(SRCS))
DEPS = $(patsubst src/%.cpp,bin/intermed/%.d,$(SRCS))

# Mark these as phonies.
.PHONY: all clean run

all: ./bin/$(PROJECT)

run: all
	@./bin/$(PROJECT) res/example_real.xml

# Clean target.
clean:
	$(RM) -rf ./bin
	$(MKDIR) -p ./bin/intermed/plistcpp

# Main binary target.
./bin/$(PROJECT): $(OBJS)
	$(CC) $^ -o $@ $(CFLAGS) $(LDFLAGS)

-include $(DEPS)

# Object file target
bin/intermed/%.o: src/%.cpp Makefile
	$(CC) -MMD -MP -c $< -o $@ $(CFLAGS) $(LDFLAGS)
