#!/bin/bash
# *****************************************************************
#
# Licensed Materials - Property of IBM
#
# (C) Copyright IBM Corp. 2020. All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
# *****************************************************************
set -ex
BAZEL_RC_DIR=$1

# Here "/usr/include" is added so that cublas headers can be located on baremetal.
CUDA_TOOLKIT_PATH=$CUDA_HOME,$PREFIX,"/usr/include"

# Determine architecture for specific settings
ARCH=`uname -p`

## CUDA OPTION 1: CUDA CAPABILITY LEVEL
## More information on Capability Levels found at: 
##  https://developer.nvidia.com/cuda-gpus
##
## Note 1: CUBINs are compatible within the same major architecture, 
## which means we only need to ship PTX to JIT for future architectures.
##
## Note 2: This has changed for TF 2.3. We can now designate which 
## architectures to include PTX code for:
##     - compute_<cuda_arch> : include PTX
##     - sm_<cuda_arch> : do not include PTX
##
##

CUDA_VERSION="${cudatoolkit%.*}"

CUDA_OPTION_1=''
if [[ "${ARCH}" == 'x86_64' ]]; then
    CUDA_OPTION_1='sm_37,sm_52,sm_60,sm_61,sm_70,compute_75'
fi
if [[ "${ARCH}" == 'ppc64le' ]]; then
    ## M40 and P4 never fully qualified on ppc64le
    CUDA_OPTION_1='sm_37,sm_60,sm_70,compute_75'
fi

if [[ $CUDA_VERSION == '11' ]]; then
    CUDA_OPTION_1+='compute_80'
fi


cat > $BAZEL_RC_DIR/nvidia_components_configure.bazelrc << EOF
build --config=cuda
build --copt=-fPIC
build:tensorrt --action_env TF_NEED_TENSORRT=1
build --config=tensorrt
build --action_env TF_NEED_CUDA=1
build --action_env TF_NEED_TENSORRT=1
build --action_env TF_CUDA_VERSION=$CUDA_VERSION"
build --action_env TF_CUDNN_VERSION="${cudnn:0:1}" #First digit only
build --action_env TF_TENSORRT_VERSION="${tensorrt:0:1}"
build --action_env TF_NCCL_VERSION="${nccl:0:1}"
build --action_env TF_CUDA_PATHS="$CUDA_TOOLKIT_PATH"
build --action_env CUDA_TOOLKIT_PATH="$CUDA_TOOLKIT_PATH"
build --action_env TF_CUDA_COMPUTE_CAPABILITIES="${CUDA_OPTION_1}"
build --action_env GCC_HOST_COMPILER_PATH="${CC}"
EOF

cat > $BAZEL_RC_DIR/tensorflow-serving.bazelrc << EOF
import %workspace%/tensorflow_serving/nvidia_components_configure.bazelrc
EOF

