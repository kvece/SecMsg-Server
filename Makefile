
all: server

clean:
	rm *.o server


server: server.s
	gcc -c server.s
	ld -o server server.o
