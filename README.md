# Environment Setup and Installation

## 1. System Prerequisites

Install CMake extensions and Sox via package manager:

```bash
sudo apt-get install cmake sox
```

## 2. Get Source Code

Clone the official ESPnet repository:

```bash
git clone https://github.com/espnet/espnet
```

## 3. Environment Setup

Configure environment variables and Python path.

```bash
# Activate Python environment
. <espnet-root>/tools/activate_python.sh

# Set PYTHONPATH
MAIN_ROOT=$PWD/../../..
export PYTHONPATH="${MAIN_ROOT}:${PYTHONPATH}"
```

To verify if the `espnet2` module is found correctly:

```bash
python3 -c "import espnet2; print('espnet2 found at', espnet2.__file__)"
```

## 4. Main Installation

Compile and install the necessary tools in the `tools` directory:

```bash
cd <espnet-root>/tools
make
```

## 5. Transducer Installation (Optional)

To install Warp Transducer support with CUDA:

```bash
cd <espnet-root>/tools
cuda_root=<cuda-root>  # Example: /usr/local/cuda
bash -c ". activate_python.sh; . ./setup_cuda_env.sh $cuda_root; ./installers/install_warp-transducer.sh"
```

## 6. Check Installation

Run the verification script to ensure all dependencies are configured correctly:

```bash
cd <espnet-root>/tools
bash -c ". ./activate_python.sh; . ./extra_path.sh; python3 check_install.py"
```
