
all: server spritz

clean:
	rm *.o server

spritz: spritz.s util.o
	gcc -c spritz.s
	ld -o spritz spritz.o util.o

server: server.s util.o
	gcc -c server.s
	ld -o server server.o util.o

util.o: util.s
	gcc -c util.s
