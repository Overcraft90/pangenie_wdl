version 1.0

########### PanGeie WDL workflow to run on TERRA ###########
# Author: Matteo Ungaro and Jean Monlong                   #
# Description: pipelien to genotype samples using PanGenie #
# Reference: https://github.com/eblerjana/pangenie         #
############################################################

workflow pangenie {
    input {
        String PANGENIE_CONTAINER = "overcraft90/eblerjana_pangenie:2.1.2"
        
        File FORWARD_FASTQ # compressed R1
        File REVERSE_FASTQ # compressed R2
        String NAME = "sample" # grub names' prefix!?

        File PANGENOME_VCF # input vcf with variants to be genotyped
        File REF_GENOME # reference for variant calling
        String EXE_PATH = "/app/pangenie/build/src/PanGenie" # path to PanGenie executable in Docker

        Int CORES = 24 # number of cores to allocate for PanGenie execution
        Int DISK = 300 # storage memory for output files
        Int MEM = 100 # RAM memory allocated
    }

    call reads_extraction_and_merging {
        input:
        in_container_pangenie=PANGENIE_CONTAINER,
        in_forward_fastq=FORWARD_FASTQ,
        in_reverse_fastq=REVERSE_FASTQ,
        in_label=NAME,
        in_cores=CORES,
        in_disk=DISK,
        in_mem=MEM
    }

    call genome_inference {
        input:
        in_container_pangenie=PANGENIE_CONTAINER,
        in_pangenome_vcf=PANGENOME_VCF,
        in_reference_genome=REF_GENOME,
        in_executable=EXE_PATH,
        in_fastq_file=reads_extraction_and_merging.fastq_file,
        prefix_vcf=VCF_PREFIX,
        in_cores=CORES,
        in_disk=DISK,
        in_mem=MEM
    }

    output {
        File sample = reads_extraction_and_merging.fastq_file
        File genotype = genome_inference.vcf_file
    }
}

task reads_extraction_and_merging {
    input {
        String in_container_pangenie
        File in_forward_fastq
        File in_reverse_fastq
        String in_label
        Int in_cores
        Int in_disk
        Int in_mem
    }
    command <<<
        cat ~{in_forward_fastq} ~{in_reverse_fastq} | pigz -dcp ~{in_cores} > ~{in_label}.fastq
    >>>
    output {
        File fastq_file = "~{in_label}.fastq"
    }
    runtime {
        docker: in_container_pangenie
        memory: in_mem + " GB"
        cpu: in_cores
        disks: "local-disk " + in_disk + " SSD"
    }
}

task genome_inference {
    input {
        String jellyfish_hash_size = "3000000000"
        String in_container_pangenie
        File in_reference_genome
        File in_pangenome_vcf
        String in_executable
        File in_fastq_file
        String prefix_vcf
        Int in_cores
        Int in_disk
        Int in_mem
    }
    command <<<
        ## save the working directory because that's were the final output file should be located
        WD=`pwd`

        ## write a config file for the snakemake run
        echo "vcf: ~{in_pangenome_vcf}" > /app/pangenie/pipelines/run-from-callset/config.yaml
        echo "reference: ~{in_reference_genome}" >> /app/pangenie/pipelines/run-from-callset/config.yaml
        echo $'reads:\n sample: ~{in_fastq_file}' >> /app/pangenie/pipelines/run-from-callset/config.yaml
        echo "pangenie: ~{in_executable}" >> /app/pangenie/pipelines/run-from-callset/config.yaml
        echo "outdir: /app/pangenie" >> /app/pangenie/pipelines/run-from-callset/config.yaml
        
        cd /app/pangenie/pipelines/run-from-callset

        ## tweak snakefile to use the '-e' argument of pangenie.
        ## Useful to decrease jellyfish hash size and run on lower memory machines
        sed "s/{pangenie} -i/{pangenie} -e ~{jellyfish_hash_size} -i/" Snakefile > Snakefile_tweaked

        ## run snakemake on the tweaked Snakefile
        snakemake --cores ~{in_cores} --snakefile Snakefile_tweaked

        ## copy the output of the workflow to the working directory
        cp /app/pangenie/genotypes/sample-genotypes.vcf $WD/sample-genotypes.vcf
    >>>
    output {
        File vcf_file = "sample-genotypes.vcf"
    }
    runtime {
        docker: in_container_pangenie
        memory: in_mem + " GB"
        cpu: in_cores
        disks: "local-disk " + in_disk + " SSD"
        preemptible: 1 # can be useful for tools which execute sequential steps in a pipeline generating intermediate outputs
    }
    meta{
        author: "Matteo Ungaro & Jean Monlong"
        email: "mungaro@ucsc.edu"
        description: "WDL wrapper of a Docker container for the `PanGenie` tool. More info at [Docker Hub](https://hub.docker.com/repository/docker/overcraft90/eblerjana_pangenie) and at [PanGenie](https://github.com/eblerjana/pangenie) for docker versions and the tool itself, respectively."
}
