version 1.0

########### PanGeie WDL workflow to run on TERRA ###########
# Author: Matteo Ungaro and Jean Monlong                   #
# Description: pipelien to genotype samples using PanGenie #
# Reference: https://github.com/eblerjana/pangenie         #
############################################################

workflow pangenie {
    input {
        String PANGENIE_CONTAINER = "overcraft90/eblerjana_pangenie:2.1.7"
        
        File FORWARD_FASTQ # compressed R1
        File REVERSE_FASTQ # compressed R2
        String NAME

        File PANGENOME_VCF # input vcf with variants to be genotyped
        File REF_GENOME # reference for variant calling

        Int CORES = 24 # number of cores to allocate for PanGenie execution
        Int DISK # storage memory for output files
        Int MEM = 250 # RAM memory allocated
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
        in_fastq_file=reads_extraction_and_merging.fastq_file,
        in_label=NAME,
        in_cores=CORES,
        in_disk=DISK,
        in_mem=MEM
    }

    output {
        File sample = reads_extraction_and_merging.fastq_file
        File genotype = genome_inference.vcf_file
        File index = genome_inference.index_file
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
        File in_fastq_file
        String in_label
        Int in_cores
        Int in_disk
        Int in_mem
    }
    command <<<
    ## run PanGenie
    /app/pangenie/build/src/PanGenie -i ~{in_fastq_file} -r ~{in_reference_genome} -v ~{in_pangenome_vcf} -e ~{jellyfish_hash_size} -t ~{in_cores} -j ~{in_cores}
    
    ## compress, index and sort VCF file
    bgzip -l 9 -@ ~{in_cores} result_genotyping.vcf
    mv result_genotyping.vcf.gz ~{in_label}_genotyping.vcf.gz
    tabix -p vcf ~{in_label}_genotyping.vcf.gz | bcftools sort -o ~{in_label}_genotyping.vcf.gz -Oz9 ~{in_label}_genotyping.vcf.gz
        
    #pigz -9cp ~{in_cores} result_genotyping.vcf > ~{in_label}_genotyping.vcf.gz
    >>>
    output {
        File vcf_file = "~{in_label}_genotyping.vcf.gz"
        File index_file = "~{in_label}_genotyping.vcf.gz.tbi"
    }
    runtime {
        docker: in_container_pangenie
        memory: in_mem + " GB"
        cpu: in_cores
        disks: "local-disk " + in_disk + " SSD"
        preemptible: 1 # can be useful for tools which execute sequential steps in a pipeline generating intermediate outputs
    }
    meta {
        author: "Matteo Ungaro & Jean Monlong"
        email: "mungaro@ucsc.edu"
        description: "WDL wrapper of a Docker container for the PanGenie tool. More info at [Docker Hub](https://hub.docker.com/repository/docker/overcraft90/eblerjana_pangenie) and at [PanGenie](https://github.com/eblerjana/pangenie) for docker versions and the tool itself, respectively."
    }
}
