# getting anaconda3 loaded
FROM continuumio/anaconda3:latest

MAINTAINER Matteo Ungaro <matteo.ungaro@unife.it>

WORKDIR /app
RUN apt-get update && apt-get -y install \
    cmake \
    bcftools \
    tabix \
    pigz

# create CONDA environment
RUN conda create -n myenv
RUN echo "source activate myenv" > ~/.bashrc
ENV PATH /opt/conda/envs/myenv/bin:$PATH

# install PanGenIe
RUN git clone https://github.com/eblerjana/pangenie.git
WORKDIR pangenie
RUN conda env create -f environment.yml
SHELL ["conda", "run", "-n", "pangenie", "/bin/bash", "-c"]
RUN mkdir build; cd build; cmake .. ; make

# install dependencies to run PanGenIe and activate snakemake
SHELL ["conda", "run", "-n", "myenv", "/bin/bash", "-c"]
#RUN conda install -c bioconda bcftools
# RUN conda install -c conda-forge pigz
# RUN conda install -c bioconda tabix
RUN pip install pyfaidx

#RUN echo "source activate snakemake" > ~/.bashrc
#ENV PATH /opt/conda/envs/snakemake/bin:$PATH
WORKDIR build/src
# ideas on how to deactivate the Conda (snakemake)
