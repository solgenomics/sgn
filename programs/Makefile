PROGS= draw_contigalign

CC=gcc
CPP=g++
CFLAGS=-O2 -fomit-frame-pointer -Wall

all: $(PROGS)

draw_contigalign: source/draw_contigalign.c
	$(CC) $(CFLAGS) -odraw_contigalign $< -lgd

clean:
	rm -f $(PROGS) *.o
