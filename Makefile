HLSDK = cssdk
METAMOD = metamod
M_INCLUDE = include

NAME = csdm_amxx

COMPILER = /opt/intel/bin/icpc

OBJECTS = src/amxxmodule.cpp src/csdm_amxx.cpp src/csdm_config.cpp \
	src/csdm_mm.cpp src/csdm_natives.cpp src/csdm_player.cpp src/csdm_spawning.cpp \
	src/csdm_tasks.cpp src/csdm_timer.cpp src/csdm_util.cpp \
        src/gamedll_api.cpp src/h_export.cpp src/dllapi.cpp src/engine_api.cpp src/meta_api.cpp src/precompiled.cpp cssdk/public/interface.cpp

LINK = -lm -ldl -static-intel -static-libgcc -no-intel-extensions

OPT_FLAGS = -O3 -msse3 -ipo -no-prec-div -fp-model fast=2 -funroll-loops -fomit-frame-pointer -fno-stack-protector

INCLUDE = -I. -I$(M_INCLUDE)/ -I$(HLSDK)/common -I$(HLSDK)/dlls -I$(HLSDK)/engine -I$(HLSDK)/game_shared -I$(HLSDK)/pm_shared -I$(HLSDK)/public -I$(METAMOD)

BIN_DIR = Release
CFLAGS = $(OPT_FLAGS)

CFLAGS += -g -DNDEBUG -Dlinux -D__linux__ -std=c++0x -shared -wd147,274 -fasm-blocks \
 -Dstrcmpi=strcasecmp -DPAWN_CELL_SIZE=32 -DJIT -DASM32 -DHAVE_STDINT_H -m32 -Wall -Werror

OBJ_LINUX := $(OBJECTS:%.c=$(BIN_DIR)/%.o)

$(BIN_DIR)/%.o: %.c
	$(COMPILER) $(INCLUDE) $(CFLAGS) -o $@ -c $<

all:
	mkdir -p $(BIN_DIR)
	mkdir -p $(BIN_DIR)/sdk

	$(MAKE) $(NAME) && strip -x $(BIN_DIR)/$(NAME)_i386.so

$(NAME): $(OBJ_LINUX)
	$(COMPILER) $(INCLUDE) $(CFLAGS) $(OBJ_LINUX) $(LINK) -o$(BIN_DIR)/$(NAME)_i386.so

check:
	cppcheck $(INCLUDE) --quiet --max-configs=100 -D__linux__ -DNDEBUG -DHAVE_STDINT_H .

debug:	
	$(MAKE) all DEBUG=false

default: all

clean:
	rm -rf Release/*.o
	rm -rf Release/$(NAME)_i386.so
	rm -rf Debug/*.o
	rm -rf Debug/$(NAME)_i386.so
