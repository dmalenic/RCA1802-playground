include ./Makefile.mk

all: clean build

build:
	for dir in *; do \
		if [ -d "$$dir" ] ; then \
			if [ -f "$$dir/Makefile" ] ; then \
				$(MAKE) -C $$dir build; \
			fi \
		fi \
	done

clean:
	$(MAKE) clean_dir
	for dir in *; do \
		if [ -d "$$dir" ] ; then \
			if [ -f "$$dir/Makefile" ] ; then \
				$(MAKE) -C $$dir clean_dir; \
			fi \
		fi \
	done
