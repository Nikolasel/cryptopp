#!/usr/bin/env bash

# cryptest.sh - written and placed in public domain by Jeffrey Walton and Uri Blumenthal.
#               Copyright assigned to Crypto++ project.

# This is a test script that can be used on some Linux/Unix/Apple machines to automate testing
# of the shared object to ensure linking and symbols don't go missing from release to release.

############################################
# Tags to test

OLD_VERSION_TAG=CRYPTOPP_5_6_4
NEW_VERSION_TAG=CRYPTOPP_5_6_5

############################################
# If repo is dirty, then promt first

DIRTY=$(git diff --shortstat 2> /dev/null | tail -n1)
if [[ ! (-z "$DIRTY") ]]; then

	echo "The local repo is dirty. Continuing will reset the repo and lose changes."
	read -p "Type 'Y' to proceed. Proceed? " -n 1 -r
	echo    # (optional) move to a new line
	if [[ !($REPLY =~ ^[Yy]$) ]]; then
		[[ "$0" = "$BASH_SOURCE" ]] && exit 0 || return 0
	fi
else
	echo "The repo is clean. Proceeding..."
fi

############################################
# Setup tools and platforms

GREP=grep
EGREP=egrep
SED=sed
AWK=awk

THIS_SYSTEM=$(uname -s 2>&1)
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c darwin)
IS_LINUX=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c linux)
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c cygwin)
IS_MINGW=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c mingw)
IS_OPENBSD=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c openbsd)
IS_FREEBSD=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c freebsd)
IS_NETBSD=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c netbsd)
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | "$GREP" -i -c sunos)

THIS_MACHINE=$(uname -m 2>&1)
IS_X86=$(echo -n "$THIS_MACHINE" | "$EGREP" -i -c "(i386|i486|i586|i686)")
IS_X64=$(echo -n "$THIS_MACHINE" | "$EGREP" -i -c "(amd64|x86_64)")
IS_PPC=$(echo -n "$THIS_MACHINE" | "$EGREP" -i -c "(Power|PPC)")
IS_ARM32=$(echo -n "$THIS_MACHINE" | "$GREP" -v "64" | "$EGREP" -i -c "(arm|aarch32)")
IS_ARM64=$(echo -n "$THIS_MACHINE" | "$EGREP" -i -c "(arm64|aarch64)")
IS_S390=$(echo -n "$THIS_MACHINE" | "$EGREP" -i -c "s390")
IS_X32=0

# Fixup
if [[ "$IS_SOLARIS" -ne "0" ]]; then
	IS_X64=$(isainfo 2>/dev/null | "$GREP" -i -c "amd64")
	if [[ "$IS_X64" -ne "0" ]]; then
		IS_X86=0
	fi

	# Need something more powerful than the Posix versions
	if [[ (-e "/usr/gnu/bin/grep") ]]; then
		GREP=/usr/gnu/bin/grep;
	fi
	if [[ (-e "/usr/gnu/bin/egrep") ]]; then
		EGREP=/usr/gnu/bin/egrep;
	fi
	if [[ (-e "/usr/gnu/bin/sed") ]]; then
		SED=/usr/gnu/bin/sed;
	fi
	if [[ (-e "/usr/gnu/bin/awk") ]]; then
		AWK=/usr/gnu/bin/awk;
	else
		AWK=nawk;
	fi
fi

if [[ "$IS_DARWIN" -ne "0" ]]; then
	SED_OPTS=(-i '')
else
	SED_OPTS=(-i)
fi

# Fixup
if [[ ("$IS_FREEBSD" -ne "0" || "$IS_OPENBSD" -ne "0" || "$IS_NETBSD" -ne "0") ]]; then
	MAKE=gmake
elif [[ ("$IS_SOLARIS" -ne "0") ]]; then
	MAKE=$(which gmake 2>/dev/null | "$GREP" -v "no gmake" | head -1)
	if [[ (-z "$MAKE") && (-e "/usr/sfw/bin/gmake") ]]; then
		MAKE=/usr/sfw/bin/gmake
	fi
else
	MAKE=make
fi

# We need to use the C++ compiler to determine feature availablility. Otherwise
#   mis-detections occur on a number of platforms.
if [[ ((-z "$CXX") || ("$CXX" == "gcc")) ]]; then
	if [[ ("$CXX" == "gcc") ]]; then
		CXX=g++
	elif [[ "$IS_DARWIN" -ne "0" ]]; then
		CXX=c++
	elif [[ "$IS_SOLARIS" -ne "0" ]]; then
		if [[ (-e "/opt/developerstudio12.5/bin/CC") ]]; then
			CXX=/opt/developerstudio12.5/bin/CC
		elif [[ (-e "/opt/solarisstudio12.4/bin/CC") ]]; then
			CXX=/opt/solarisstudio12.4/bin/CC
		elif [[ (-e "/opt/solarisstudio12.3/bin/CC") ]]; then
			CXX=/opt/solarisstudio12.3/bin/CC
		elif [[ (-e "/opt/solstudio12.2/bin/CC") ]]; then
			CXX=/opt/solstudio12.2/bin/CC
		elif [[ (-e "/opt/solstudio12.1/bin/CC") ]]; then
			CXX=/opt/solstudio12.1/bin/CC
		elif [[ (-e "/opt/solstudio12.0/bin/CC") ]]; then
			CXX=/opt/solstudio12.0/bin/CC
		elif [[ (! -z $(which CC 2>/dev/null | "$GREP" -v "no CC" | head -1)) ]]; then
			CXX=$(which CC | head -1)
		elif [[ (! -z $(which g++ 2>/dev/null | "$GREP" -v "no g++" | head -1)) ]]; then
			CXX=$(which g++ | head -1)
		else
			CXX=CC
		fi
	elif [[ ($(which g++ 2>&1 | "$GREP" -v "no g++" | "$GREP" -i -c g++) -ne "0") ]]; then
		CXX=g++
	else
		CXX=c++
	fi
fi

SUN_COMPILER=$("$CXX" -V 2>&1 | "$EGREP" -i -c "CC: (Sun|Studio)")
GCC_COMPILER=$("$CXX" --version 2>&1 | "$GREP" -i -v "clang" | "$EGREP" -i -c "(gcc|g\+\+)")
INTEL_COMPILER=$("$CXX" --version 2>&1 | "$EGREP" -i -c "\(icc\)")
MACPORTS_COMPILER=$("$CXX" --version 2>&1 | "$EGREP" -i -c "MacPorts")
CLANG_COMPILER=$("$CXX" --version 2>&1 | "$EGREP" -i -c "clang")

if [[ ("$SUN_COMPILER" -eq "0") ]]; then
	AMD64=$("$CXX" -dM -E - </dev/null 2>/dev/null | "$EGREP" -c "(__x64_64__|__amd64__)")
	ILP32=$("$CXX" -dM -E - </dev/null 2>/dev/null | "$EGREP" -c "(__ILP32__|__ILP32)")
	if [[ ("$AMD64" -ne "0") && ("$ILP32" -ne "0") ]]; then
		IS_X32=1
	fi
fi

############################################

# CPU is logical count, memory is in MiB. Low resource boards have
#   fewer than 4 cores and 1GB or less memory. We use this to
#   determine if we can build in parallel without an OOM kill.
CPU_COUNT=1
MEM_SIZE=512

if [[ (-e "/proc/cpuinfo") && (-e "/proc/meminfo") ]]; then
	CPU_COUNT=$(cat /proc/cpuinfo | "$GREP" -c '^processor')
	MEM_SIZE=$(cat /proc/meminfo | "$GREP" "MemTotal" | "$AWK" '{print $2}')
	MEM_SIZE=$(($MEM_SIZE/1024))
elif [[ "$IS_DARWIN" -ne "0" ]]; then
	CPU_COUNT=$(sysctl -a 2>&1 | "$GREP" 'hw.availcpu' | "$AWK" '{print $3; exit}')
	MEM_SIZE=$(sysctl -a 2>&1 | "$GREP" 'hw.memsize' | "$AWK" '{print $3; exit;}')
	MEM_SIZE=$(($MEM_SIZE/1024/1024))
elif [[ "$IS_SOLARIS" -ne "0" ]]; then
	CPU_COUNT=$(psrinfo 2>/dev/null | wc -l | "$AWK" '{print $1}')
	MEM_SIZE=$(prtconf 2>/dev/null | "$GREP" Memory | "$AWK" '{print $3}')
fi

# Some ARM devboards cannot use 'make -j N', even with multiple cores and RAM
#  An 8-core Cubietruck Plus with 2GB RAM experiences OOM kills with '-j 2'.
HAVE_SWAP=1
if [[ "$IS_LINUX" -ne "0" ]]; then
	if [[ (-e "/proc/meminfo") ]]; then
		SWAP_SIZE=$(cat /proc/meminfo | "$GREP" "SwapTotal" | "$AWK" '{print $2}')
		if [[ "$SWAP_SIZE" -eq "0" ]]; then
			HAVE_SWAP=0
		fi
	else
		HAVE_SWAP=0
	fi
fi

if [[ ("$CPU_COUNT" -ge "2" && "$MEM_SIZE" -ge "1280" && "$HAVE_SWAP" -ne "0") ]]; then
	if [[ ("$WANT_NICE" -eq "1") ]]; then
		CPU_COUNT=$(echo -n "$CPU_COUNT 2" | "$AWK" '{print int($1/$2)}')
	fi
	MAKEARGS=(-j "$CPU_COUNT")
	echo "Using $MAKE -j $CPU_COUNT"
fi

###############################################################################
###############################################################################

"$MAKE" distclean &>/dev/null

rm -f GNUmakefile-symbols

git checkout master -f &>/dev/null
cp GNUmakefile GNUmakefile-symbols

git checkout "$OLD_VERSION_TAG" -f &>/dev/null

if [[ "$IS_DARWIN" -ne "0" ]]; then
	"$SED" "$SED_OPTS" -e 's|libcryptopp.a $(TESTOBJS)|libcryptopp.dylib $(TESTOBJS)|g' GNUmakefile-symbols
	"$SED" "$SED_OPTS" -e 's|$(TESTOBJS) ./libcryptopp.a |$(TESTOBJS) ./libcryptopp.dylib |g' GNUmakefile-symbols
else
	"$SED" "$SED_OPTS" -e 's|libcryptopp.a $(TESTOBJS)|libcryptopp.so $(TESTOBJS)|g' GNUmakefile-symbols
	"$SED" "$SED_OPTS" -e 's|$(TESTOBJS) ./libcryptopp.a |$(TESTOBJS) ./libcryptopp.so |g' GNUmakefile-symbols
fi

git diff --exit-code

echo "****************************************************************"
echo "Building library for $OLD_VERSION_TAG"
echo "****************************************************************"

"$MAKE" "${MAKEARGS[@]}" -f GNUmakefile-symbols dynamic

echo "****************************************************************"
echo "Building cryptest.exe for $OLD_VERSION_TAG"
echo "****************************************************************"

"$MAKE" "${MAKEARGS[@]}" -f GNUmakefile-symbols cryptest.exe

if [[ -f "cryptest.exe" ]]; then

	echo "****************************************************************"
	echo "Running $OLD_VERSION_TAG cryptest.exe using $OLD_VERSION_TAG library"
	echo "****************************************************************"

	if [[ "$IS_DARWIN" -ne "0" ]]; then
		DYLD_LIBRARY_PATH="$PWD:$DYLD_LIBRARY_PATH" "$PWD/cryptest.exe" v 2>&1 | c++filt
		DYLD_LIBRARY_PATH="$PWD:$DYLD_LIBRARY_PATH" "$PWD/cryptest.exe" tv all 2>&1 | c++filt
	else
		LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" "$PWD/cryptest.exe" v 2>&1 | c++filt
		LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" "$PWD/cryptest.exe" tv all 2>&1 | c++filt
	fi
else
	echo "Failed to make cryptest.exe"
fi

echo "****************************************************************"
echo "Removing dynamic library for $OLD_VERSION_TAG"
echo "****************************************************************"

rm -f *.o *.so *.dylib

git checkout "$NEW_VERSION_TAG" -f &>/dev/null

echo "****************************************************************"
echo "Building dynamic library for $NEW_VERSION_TAG"
echo "****************************************************************"

"$MAKE" "${MAKEARGS[@]}" -f GNUmakefile-symbols dynamic

if [[ -f "cryptest.exe" ]]; then

	echo "****************************************************************"
	echo "Running $OLD_VERSION_TAG cryptest.exe using $NEW_VERSION_TAG library"
	echo "****************************************************************"

	if [[ "$IS_DARWIN" -ne "0" ]]; then
		DYLD_LIBRARY_PATH="$PWD:$DYLD_LIBRARY_PATH" "$PWD/cryptest.exe" v 2>&1 | c++filt
		DYLD_LIBRARY_PATH="$PWD:$DYLD_LIBRARY_PATH" "$PWD/cryptest.exe" tv all 2>&1 | c++filt
	else
		LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" "$PWD/cryptest.exe" v 2>&1 | c++filt
		LD_LIBRARY_PATH="$PWD:$LD_LIBRARY_PATH" "$PWD/cryptest.exe" tv all 2>&1 | c++filt
	fi
else
	echo "Failed to make cryptest.exe"
fi

git checkout master -f &>/dev/null

[[ "$0" = "$BASH_SOURCE" ]] && exit 0 || return 0]