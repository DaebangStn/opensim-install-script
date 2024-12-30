#!/bin/bash

# Exit when an error happens instead of continue.
set -e

# Default values for flags.
DEBUG_TYPE="Release"
NUM_JOBS=32
MOCO="on"
CORE_BRANCH="main"
GUI_BRANCH="main"
GENERATOR="Ninja"

Help() {
    echo
    echo "This script builds and installs the last available version of OpenSim-Gui in your computer."
    echo "Usage: ./scriptName [OPTION]..."
    echo "Example: ./opensim-gui-build.sh -j 4 -d \"Release\""
    echo "    -d         Debug Type. Available Options:"
    echo "                   Release (Default): No debugger symbols. Optimized."
    echo "                   Debug: Debugger symbols. No optimizations (>10x slower). Library names ending with _d."
    echo "                   RelWithDefInfo: Debugger symbols. Optimized. Bigger than Release, but not slower."
    echo "                   MinSizeRel: No debugger symbols. Minimum size. Optimized."
    echo "    -j         Number of jobs to use when building libraries (>=1)."
    echo "    -s         Simple build without moco (Tropter and Casadi disabled)."
    echo "    -c         Branch for opensim-core repository."
    echo "    -g         Branch for opensim-gui repository."
    echo "    -n         Use the Ninja generator to build opensim-core. If not set, Unix Makefiles is used."
    echo
    exit
}

# Show values of flags:
echo
echo "Build script parameters:"
echo "DEBUG_TYPE="$DEBUG_TYPE
echo "NUM_JOBS="$NUM_JOBS
echo "MOCO="$MOCO
echo "CORE_BRANCH="$CORE_BRANCH
echo "GUI_BRANCH="$GUI_BRANCH
echo "GENERATOR="$GENERATOR
echo ""

# Create workspace folder.
mkdir ~/opensim-workspace || true

# Check netbeans12.3 and swig is installed
[ -d ~/swig ] && echo "Directory ~/swig exists." || echo "Directory ~/swig does not exist."
[ -d ~/netbeans-12.3 ] && echo "Directory ~/netbeans-12.3 exists." || echo "Directory ~/netbeans-12.3 does not exist."

# Get opensim-core.
echo "LOG: CLONING OPENSIM-CORE..."
git -C ~/opensim-workspace/opensim-core-source pull || git clone https://github.com/opensim-org/opensim-core.git ~/opensim-workspace/opensim-core-source
cd ~/opensim-workspace/opensim-core-source
git checkout $CORE_BRANCH
echo

# Build opensim-core dependencies.
echo "LOG: BUILDING OPENSIM-CORE DEPENDENCIES..."
mkdir -p ~/opensim-workspace/opensim-core-dependencies-build || true
cd ~/opensim-workspace/opensim-core-dependencies-build
cmake ~/opensim-workspace/opensim-core-source/dependencies -DCMAKE_INSTALL_PREFIX=~/opensim-workspace/opensim-core-dependencies-install/ -DSUPERBUILD_ezc3d=on -DOPENSIM_WITH_CASADI=$MOCO -DOPENSIM_WITH_TROPTER=$MOCO
cmake . -LAH
cmake --build . --config $DEBUG_TYPE -j$NUM_JOBS
echo

# Build opensim-core.
echo "LOG: BUILDING OPENSIM-CORE..."
mkdir -p ~/opensim-workspace/opensim-core-build || true
cd ~/opensim-workspace/opensim-core-build
cmake ~/opensim-workspace/opensim-core-source -G"$GENERATOR" -DOPENSIM_DEPENDENCIES_DIR=~/opensim-workspace/opensim-core-dependencies-install/ -DBUILD_JAVA_WRAPPING=on -DBUILD_PYTHON_WRAPPING=on -DOPENSIM_C3D_PARSER=ezc3d -DBUILD_TESTING=off -DCMAKE_INSTALL_PREFIX=~/opensim-core -DOPENSIM_INSTALL_UNIX_FHS=off -DSWIG_DIR=~/swig/share/swig -DSWIG_EXECUTABLE=~/swig/bin/swig
cmake . -LAH
cmake --build . --config $DEBUG_TYPE -j$NUM_JOBS
cmake --install .
echo

# Get opensim-gui.
echo "LOG: CLONING OPENSIM-GUI..."
git -C ~/opensim-workspace/opensim-gui-source pull || git clone https://github.com/opensim-org/opensim-gui.git ~/opensim-workspace/opensim-gui-source
cd ~/opensim-workspace/opensim-gui-source
git checkout $GUI_BRANCH
git submodule update --init --recursive -- opensim-models opensim-visualizer Gui/opensim/threejs
echo

# Build opensim-gui.
echo "LOG: BUILDING OPENSIM-GUI..."
mkdir -p ~/opensim-workspace/opensim-gui-build || true
cd ~/opensim-workspace/opensim-gui-build
cmake ~/opensim-workspace/opensim-gui-source -DCMAKE_PREFIX_PATH=~/opensim-core -DAnt_EXECUTABLE=~/netbeans-12.3/netbeans/extide/ant/bin/ant -DANT_ARGS="-Dnbplatform.default.netbeans.dest.dir=$HOME/netbeans-12.3/netbeans;-Dnbplatform.default.harness.dir=$HOME/netbeans-12.3/netbeans/harness"
make CopyOpenSimCore -j$NUM_JOBS
make PrepareInstaller -j$NUM_JOBS
echo

# Install opensim-gui.
echo "LOG: INSTALLING OPENSIM-GUI..."
cd ~/opensim-workspace/opensim-gui-source/Gui/opensim/dist/installer/opensim
bash INSTALL
echo
