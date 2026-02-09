WK_DIR := $(CURDIR)
CUR_MKF_FILE := $(lastword $(MAKEFILE_LIST))
CUR_MKF_DIR := $(dir $(CUR_MKF_FILE))
$(info cur wk dir  --> $(WK_DIR))
$(info MKF LIST    --> $(MAKEFILE_LIST))
$(info cur mkf dir --> $(CUR_MKF_DIR))

FLAGS = -Wall -Wextra -lm -g
SRCs = $(CUR_MKF_DIR)/rcb_calc_com.c \
	   $(CUR_MKF_DIR)/rcb_calc_vdpu384b.c \
	   $(CUR_MKF_DIR)/main.c
OBJs = $(patsubst %.c, %.o, $(SRCs))
DEPs = $(wildcard *.h)
TARGET = $(CUR_MKF_DIR)/main


.PHONY : all
all : $(TARGET)

$(TARGET) : $(OBJs)
	gcc -o $@ $^ $(FLAGS)

$(OBJs) :
	gcc $(MCRODEF) -c $(subst .o,.c,$@) -o $@ $(FLAGS)

test :
	./$(TARGET)


.PHONY : clean
clean :
	-rm $(OBJs)
	-rm $(TARGET)
