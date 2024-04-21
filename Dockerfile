FROM apache/zeppelin:0.10.1

ENV SPARK_HOME="/opt/zeppelin/spark" 
ENV ZEPPELIN_HOME=/opt/zeppelin
ENV TZ=UTC \
    DEBIAN_FRONTEND=noninteractive

USER root 

RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt \
        	apt-get update && \
	        apt-get install -yqq --no-install-recommends \
            libnss-wrapper gcc git wget vim build-essential libxml2 nvtop rsync tini libarchive13

# SPARK INSTALLATION
COPY ./spark-3.2.4-bin-hadoop3.2.tgz /tmp/spark-3.2.4-bin-hadoop3.2.tgz

RUN echo "Download Spark binary" && \
    mkdir -p ${SPARK_HOME} && \
    tar --strip-components=1 -zxvf /tmp/spark-3.2.4-bin-hadoop3.2.tgz -C ${SPARK_HOME}

COPY ./spark-defaults.conf ${SPARK_HOME}/conf/spark-defaults.conf

# MAMBA AND PYTHON PACKAGES INSTALLATION
COPY ./env_python_3_with_R.yml ${ZEPPELIN_HOME}/env_python_3_with_R.yml
COPY ./Mambaforge-24.3.0-0-Linux-x86_64.sh ${ZEPPELIN_HOME}/miniforge.sh

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

# spark UI port 
EXPOSE 4040

# usage
# docker run -d -it -u $(id -u) -p 8080:8080 -p 4040:4040 --rm -v $PWD/logs:/logs -v $PWD/notebook:/notebook  -e ZEPPELIN_LOG_DIR='/logs' -e ZEPPELIN_NOTEBOOK_DIR='/notebook' --name zeppelin local-zeppelin:latest