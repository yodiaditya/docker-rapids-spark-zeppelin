# Docker Zeppelin + Spark Simple Standalone Cluster
Repository to create spark/zeppelin development environment. 
Works with NVIDIA GPU attached. 

This will running Spark Master and Node to replicate near production environment.  
You can extend this with Zeppelin, Spark, Flink, DuckDB, Parquet, Tensorflow, PyTorch and many more.  

This already tested with local PC and laptop running on Ubuntu 23.10 and RTX 4090 

## Pre-requisites

Clone this git and download required packages into project folder

```
git clone https://github.com/yodiaditya/docker-zeppelin-spark.git zeppelin-simple
cd zeppelin-simple
wget -c https://github.com/conda-forge/miniforge/releases/download/24.3.0-0/Mambaforge-24.3.0-0-Linux-x86_64.sh
wget -c https://archive.apache.org/dist/spark/spark-3.2.4/spark-3.2.4-bin-hadoop3.2.tgz

```

## Building and Runnning

Now you can start to build and run it:
```
docker compose up --build
```

To access services : <http://localhost:9999>

## Spark and Zeppelin configuration
- Adjusting any Spark memory and settings, can be done by edit `spark-defaults.conf`. 
- While for Zeppelin, you can create `conf` and copy into `/opt/zeppelin/conf` including the files configuration. 
- Python and default packages can be found at `env_python_3_with_R.yml`
- The `Dockerfile` can be customized easily

## Docker Access
Root Login (For apt install and other root permission)
```
docker exec -u 0 -it zeppelin bash
```

While, for `pip installation`, use User Login 
```
docker exec -it zeppelin bash
```

You can login and do `nvtop` to see whether GPU is detected.

## Docker Installation on Ubuntu

Follow this Docker CE installation : <https://docs.docker.com/engine/install/ubuntu/>. 
Don't use `snap` because NVIDIA Toolkit only works with Docker CE

If you received weird NVIDIA errors when running the dockers,
Suggested to uninstall everything and re-install Docker CE. Here are the steps:

```
sudo snap remove --purge docker
sudo apt-get purge docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl restart docker

```
#### Running docker without `root` permission

```
sudo groupadd docker
sudo usermod -aG docker $USER
```

## Docker config for Zeppelin

Docker Configuration <https://zeppelin.apache.org/docs/latest/quickstart/docker.html>

Because DockerInterpreterProcess communicates via docker's tcp interface.
By default, docker provides an interface as a sock file, so you need to modify the configuration file to open the tcp interface remotely.

To listen on both - socket and tcp:

create folder: /etc/systemd/system/docker.socket.d
create file 10-tcp.conf `touch /etc/systemd/system/docker.socket.d` and copy this:

```
[Socket]
ListenStream=0.0.0.0:2375
```

restart everything:

```
sudo systemctl daemon-reload
sudo systemctl stop docker.socket
sudo systemctl stop docker.service
sudo systemctl start docker
```

Plus are: it us user space systemd drop-in, i.e. would not disappear after upgrade of the docker
would allow to use both - socket and tcp connection

#### If there is DNS issue when download 
You can enable another DNS at `/etc/docker/daemon.json` and add your local DNS or Google DNS

```
{ "dns" : [ "114.114.114.114" , "8.8.8.8" ] } 
```

## Docker GPU Installation 
This steps required to enable GPU in the docker
<https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#installing-with-apt>

Or you for Ubuntu 23.10 Docker GPU Nvidia you can follow this: 

```
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
  && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
```

Then configure it

```
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

Run this to test whether its works. 

```
sudo docker run --rm --runtime=nvidia --gpus all ubuntu nvidia-smi
```

This will enabled in `docker-compose.yaml` on zeppelin section:

```
deploy:
  resources:
    reservations:
      devices:
      - driver: nvidia
        device_ids: ['0']
        capabilities: [gpu]
```

You can read details at <https://docs.docker.com/compose/gpu-support/> 

If not, running the docker and go inside it `docker exec -it zeppelin bash` and install NVIDIA driver

```
wget -c https://us.download.nvidia.com/XFree86/Linux-x86_64/550.67/NVIDIA-Linux-x86_64-550.67.run 
```

## CUDA and CUDNN Installation in Docker Zeppelin
I'm using CUDA 11.8 and RTX 3060 / 4090 for this example. We need to download the installation

Start from main project folder
```
cd zeppelin
mkdir cuda && cd cuda
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
```

Next, download CUDNN 8.9.7 and extract it as folder `cudnn`

```
https://developer.download.nvidia.com/compute/redist/cudnn/v8.7.0/local_installers/11.8/cudnn-linux-x86_64-8.7.0.84_cuda11-archive.tar.xz
tar -xvvf cudnn-linux-x86_64-8.7.0.84_cuda11-archive.tar.xz
mv cudnn-linux-x86_64-8.7.0.84_cuda11-archive cudnn
rm -rf cudnn-linux-x86_64-8.7.0.84_cuda11-archive.tar.xz
```

You can see in `zeppelin/Dockerfile` there is operation to copy this into Docker and set installation
