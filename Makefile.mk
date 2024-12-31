clean_dir:
	rm -f *.hex *.lst *.p

%.p : %.asm
	asl -cpu 1802 -L $<

%.hex : %.p
	p2hex $< $@
