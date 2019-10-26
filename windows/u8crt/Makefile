all: libu8crt.a

CC= gcc -std=c99
CFLAGS= -O2 -Wall -Wextra

libu8crt.a: u8conv.o u8crt.o u8winapi.o u8main.o
	ar rcu $@ u8conv.o u8crt.o u8winapi.o u8main.o

clean:
	-rm *.o
	-rm libu8crt.a

.PHONY: all

u8conv.o: u8conv.c u8conv.h
u8crt.o: u8crt.c u8crt.h u8conv.h
u8main.o: u8main.c u8conv.h
u8winapi.o: u8winapi.c u8winapi.h u8conv.h
