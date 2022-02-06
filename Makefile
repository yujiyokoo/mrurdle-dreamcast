TARGET=mrubydle.elf

OBJS=src/mrubydle.o src/main.o src/game.o romdisk.o

MRB_SOURCES=src/game.rb src/entry_point.rb

MRB_BYTECODE=src/game.c

KOS_ROMDISK_DIR=romdisk

MRB_ROOT=/opt/mruby

CFLAGS=-I$(MRB_ROOT)/include/ -L$(MRB_ROOT)/build/dreamcast/lib/

all: $(TARGET)

include $(KOS_BASE)/Makefile.rules

$(TARGET): $(OBJS) $(MRB_BYTECODE)
	kos-cc $(CFLAGS) -o $(TARGET) $(OBJS) -lmruby -lm

clean:
	-rm -f $(TARGET) $(OBJS) romdisk.* $(MRB_BYTECODE)

rm-elf:
	-rm -f $(TARGET) romdisk.*

$(MRB_BYTECODE): src/entry_point.rb src/game.rb
	$(MRB_ROOT)/bin/mrbc -g -Bgame -o src/game.c $(MRB_SOURCES)

run: $(TARGET)
	$(KOS_LOADER) $(TARGET)

dist:
	rm -f $(OBJS) romdisk.o romdisk.img
	$(KOS_STRIP) $(TARGET)
