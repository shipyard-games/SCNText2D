all: OpenSans-Regular Roboto-Medium

OpenSans-Regular:
	mkdir -p $@
	cd $@ && ${GLFONT} ../Open_Sans/$@.ttf ../Charcodes.csv

Roboto-Medium:
	mkdir -p $@
	cd $@ && ${GLFONT} ../Roboto/$@.ttf ../Charcodes.csv

.PHONY: OpenSans-Regular Roboto-Medium
