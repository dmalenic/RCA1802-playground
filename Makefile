include ./Makefile.mk

all: clean build

build:
	for dir in *; do \
		$(MAKE) -C $$dir build; \
	done

clean:
	$(MAKE) clean_dir
	for dir in *; do \
		$(MAKE) -C $$dir clean_dir; \
	done
