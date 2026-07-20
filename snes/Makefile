ROM := onipong.sfc

all: $(ROM)

$(ROM): src/main.s lorom.cfg tools/fix_checksum.py
	mkdir -p build
	ca65 --cpu 65816 -o build/main.o src/main.s
	ld65 -C lorom.cfg -o $@ build/main.o
	python3 tools/fix_checksum.py $@

clean:
	rm -rf build $(ROM)

.PHONY: all clean
