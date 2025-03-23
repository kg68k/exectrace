# Makefile for exectrace

ifeq ($(notdir $(CURDIR)),src)
$(error do not execute make in src directory)
endif

SRCDIR_MK = ../srcdir.mk
SRC_DIR = ../src
-include $(SRCDIR_MK)

U8TOSJ = u8tosj
AS = has060
ASFLAGS = -w2 -c3 -i./include
LD ?= hlkx
LDFLAGS =
CV = cv

ifeq ($(findstring hlkx,$(LD)),hlkx)
USE_HLKX = true
endif

OBJS = exectrace.o keepchk.o
DOCS = README.txt CHANGELOG.txt

TARGET = exectrace.r
DIST_ZIP = exetr.zip


.PHONY: all clean archive

all: $(TARGET)
archive: $(DIST_ZIP)

$(TARGET:.r=.x): $(OBJS)
	$(LD) $(LDFLAGS) -o $@ $^

ifdef USE_HLKX
$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) -r -o $@ $^
else
$(TARGET): $(TARGET:.r=.x)
	$(CV) $< $@
endif

exectrace.o: exectrace.s startup.s
	$(AS) $(ASFLAGS) -o $@ $<

keepchk.o: keepchk.s
	$(AS) $(ASFLAGS) -o $@ $<


$(DIST_ZIP): $(DOCS) $(TARGET)
	rm -f $@
	zip -9 $@ $^

%.txt: $(SRC_DIR)/../%.md
	rm -f $@
	$(U8TOSJ) < $^ > $@


clean:
	rm -f $(DIST_ZIP) $(DOCS) $(TARGET) $(TARGET:.r=.x) $(OBJS)


# EOF
