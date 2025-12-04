# Configuração do Ambiente e Instalação

Este documento descreve os passos necessários para configurar o ambiente, instalar dependências e verificar a instalação.

## 1. Pré-requisitos do Sistema

Instale as extensões CMake e o Sox via gerenciador de pacotes:

```bash
sudo apt-get install cmake sox
```

## 2. Obter o Código Fonte

Clone o repositório oficial do ESPnet:

```bash
git clone https://github.com/espnet/espnet
```

## 3. Configuração do Ambiente

Configure as variáveis de ambiente e o caminho do Python.

```bash
# Ativar o ambiente Python
. <espnet-root>/tools/activate_python.sh

# Configurar PYTHONPATH
MAIN_ROOT=$PWD/../../..
export PYTHONPATH="${MAIN_ROOT}:${PYTHONPATH}"
```

Para verificar se o módulo `espnet2` foi encontrado corretamente:

```bash
python3 -c "import espnet2; print('espnet2 found at', espnet2.__file__)"
```

## 4. Instalação Principal

Compile e instale as ferramentas necessárias no diretório `tools`:

```bash
cd <espnet-root>/tools
make
```

## 5. Instalação do Transducer (Opcional)

Para instalar o suporte ao Warp Transducer com CUDA:

```bash
cd <espnet-root>/tools
cuda_root=<cuda-root>  # Exemplo: /usr/local/cuda
bash -c ". activate_python.sh; . ./setup_cuda_env.sh $cuda_root; ./installers/install_warp-transducer.sh"
```

## 6. Verificação da Instalação

Execute o script de verificação para garantir que todas as dependências estão configuradas corretamente:

```bash
cd <espnet-root>/tools
bash -c ". ./activate_python.sh; . ./extra_path.sh; python3 check_install.py"
```
