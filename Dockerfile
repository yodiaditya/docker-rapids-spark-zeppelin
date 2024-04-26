# Using the latest Zeppelin 0.11.1 and Apache Spark 3.5.1
FROM apache/zeppelin:0.11.1

ENV SPARK_HOME="/opt/zeppelin/spark" 
ENV ZEPPELIN_HOME=/opt/zeppelin
ENV TZ=UTC \
    DEBIAN_FRONTEND=noninteractive

USER root 

RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt \
        	apt-get update && \
	        apt-get install -yqq --no-install-recommends \
            libnss-wrapper gcc git wget vim build-essential libxml2 nvtop rsync tini libarchive13 libnuma-dev

# SPARK 3.5.1 INSTALLATION
COPY ./spark-3.5.1-bin-hadoop3.tgz /tmp/spark-3.5.1-bin-hadoop3.tgz

RUN echo "Download Spark binary" && \
    mkdir -p ${SPARK_HOME} && \
    tar --strip-components=1 -zxvf /tmp/spark-3.5.1-bin-hadoop3.tgz -C ${SPARK_HOME}

COPY ./spark-defaults.conf ${SPARK_HOME}/conf/spark-defaults.conf

# Remove files that caused error in Zeppelin
RUN rm /opt/zeppelin/interpreter/spark/._spark-interpreter-0.11.1.jar && \
    rm /opt/zeppelin/interpreter/spark/scala-2.12/._spark-scala-2.12-0.11.1.jar

################ CUDA INSTALLATION #################
### UNCOMMENT THIS FOR CUDA INSTALLATION
### ENSURE TO COPY THE cuda_11.8.0_520.61.05_linux.run and cudnn INTO `zeppelin/cuda`

## Copy from host `/zeppelin/cuda` to Docker `/opt/zeppelin/cuda
COPY ./cuda ${ZEPPELIN_HOME}/cuda
RUN chmod a+x cuda/cuda_11.8.0_520.61.05_linux.run
RUN cuda/cuda_11.8.0_520.61.05_linux.run --silent --toolkit

# copy CUDNN following files into the cuda toolkit directory.
RUN cp -P cuda/cudnn/include/cudnn.h /usr/local/cuda/include
RUN cp -P cuda/cudnn/lib/libcudnn* /usr/local/cuda/lib64/
RUN chmod a+r /usr/local/cuda-11.8/lib64/libcudnn*
RUN rm -rf cuda

# Ensure cuda is added to the PATH, since ~./bashrc is not loaded
ENV PATH /usr/local/cuda/bin:${PATH}
ENV LD_LIBRARY_PATH /usr/local/cuda/lib:/usr/local/cuda/lib64

# Export the path
RUN echo 'export PATH=/usr/local/cuda/bin:$PATH' >> ${ZEPPELIN_HOME}/.bashrc
RUN echo 'export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH' >> ${ZEPPELIN_HOME}/.bashrc
RUN ldconfig

################# End Install CUDA #################

# MAMBA AND PYTHON PACKAGES INSTALLATION
COPY ./env_python_3_with_R.yml ${ZEPPELIN_HOME}/env_python_3_with_R.yml
COPY ./Mambaforge-24.3.0-0-Linux-x86_64.sh ${ZEPPELIN_HOME}/miniforge.sh
COPY ./condarc /etc/conda/.condarc

# Create cache dir for RAPIDS ML installation 4GB
RUN  mkdir -p ${ZEPPELIN_HOME}/conda-cache

# Copy the conda cache to the docker image
# COPY ./conda-cache ${ZEPPELIN_HOME}/

RUN set -ex && rm -rf /opt/conda && \
    bash  ${ZEPPELIN_HOME}/miniforge.sh -b -p /opt/conda && \
    export PATH=/opt/conda/bin:$PATH && \
    conda update --yes -n base -c defaults conda && \
    conda config --set always_yes yes --set changeps1 no && \
    conda info -a && \
    conda install mamba -c conda-forge

RUN set -ex && \
    export PATH=/opt/conda/bin:$PATH && \
    mamba env update -f env_python_3_with_R.yml --prune && \
    # Cleanup
    rm -v ${ZEPPELIN_HOME}/miniforge.sh && \
    mamba init bash && \
    echo mamba activate python_3_with_R >> ${ZEPPELIN_HOME}/.bashrc && \
    echo mamba activate python_3_with_R >> /root/.bashrc && \
    \
    # Cleanup
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    mamba clean -ay

USER 1000 

ENV PATH="/opt/conda/envs/python_3_with_R/bin:/opt/conda/conda/bin:$PATH"
ENV PATH=/opt/zeppelin/.local/bin:$PATH

# Install rapids
RUN pip install spark_rapids_ml

# # spark UI port 
# EXPOSE 4040

# usage
# docker run -d -it -u $(id -u) -p 8080:8080 -p 4040:4040 --rm -v $PWD/logs:/logs -v $PWD/notebook:/notebook  -e ZEPPELIN_LOG_DIR='/logs' -e ZEPPELIN_NOTEBOOK_DIR='/notebook' --name zeppelin local-zeppelin:latest