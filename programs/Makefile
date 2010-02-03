PROGS= draw_contigalign	fast_mapping

CC=gcc
CPP=g++
CFLAGS=-O2 -fomit-frame-pointer -Wall

all: $(PROGS)

draw_contigalign: source/draw_contigalign.c
	$(CC) $(CFLAGS) -odraw_contigalign $< -lgd


fast_mapping: source/fast_mapping.cpp
	$(CPP) $(CFLAGS) -c $<
	$(CPP) fast_mapping.o -o fast_mapping

clean:
	rm -f $(PROGS) *.o
