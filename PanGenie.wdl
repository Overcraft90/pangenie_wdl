version 1.0

########### PanGeie WDL workflow to run on TERRA ###########
# Author: Matteo Ungaro and Jean Monlong                   #
# Description: pipelien to genotype samples using PanGenie #
# Reference: https://github.com/eblerjana/pangenie         #
############################################################

workflow pangenie {
    input {
        String PANGENIE_CONTAINER = "overcraft90/eblerjana_pangenie:2.1.6"
        
        File FORWARD_FASTQ # compressed R1
        File REVERSE_FASTQ # compressed R2
        String SAMPLE_NAME

        File PANGENOME_VCF # input vcf with variants to be genotyped
        File REF_GENOME # reference for variant calling

        Boolean SORT_INDEX_OUTPUT_VCF = true # should the output VCF be sorted, bgzipped and indexed? Default is true. If false, VCF is just gzipped.
        Int CORES = 24 # number of cores to allocate for PanGenie execution
        Int DISK # storage memory for output files
        Int MEM = 250 # RAM memory allocated
    }

    call reads_extraction_and_merging {
        input:
        in_forward_fastq=FORWARD_FASTQ,
        in_reverse_fastq=REVERSE_FASTQ,
        in_label=SAMPLE_NAME,
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
        in_label=SAMPLE_NAME,
        in_cores=CORES,
        in_disk=DISK,
        in_mem=MEM
    }

    if (SORT_INDEX_OUTPUT_VCF){
        call sortIndexVCF {
            input: in_vcf_file=genome_inference.vcf_file
        }
    }

    File output_vcf = select_first([sortIndexVCF.vcf_file, genome_inference.vcf_file])
    
    output {
        File genotype = output_vcf
        File? index = sortIndexVCF.index_file
    }
}

task reads_extraction_and_merging {
    input {
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
        docker: "quay.io/biocontainers/pigz:2.3.4"
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
    /app/pangenie/build/src/PanGenie -i ~{in_fastq_file} -r ~{in_reference_genome} -s ~{in_label} -v ~{in_pangenome_vcf} -e ~{jellyfish_hash_size} -t ~{in_cores} -j ~{in_cores}
    
    ## quick gzip compression
    pigz -cp ~{in_cores} result_genotyping.vcf > ~{in_label}_genotyping.vcf.gz
    >>>
    output {
        File vcf_file = "~{in_label}_genotyping.vcf.gz"
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

task sortIndexVCF {
    input {
        File in_vcf_file
        Int disk_size = 30 * round(size(in_vcf_file, "G")) + 50
        Int mem_gb = 8
    }

    ## file basename with .gz or .vcf extensions stripped
    String out_prefix = sub(sub(basename(in_vcf_file), ".gz", ""), ".vcf", "")
    command <<<
    ## bcftools doesn't like when the contigs are not defined in the header, so let's sort it manually

    ## extract the header
    bcftools view -h ~{in_vcf_file} > ~{out_prefix}.sorted.vcf
    ## sort the non-header lines
    bcftools view -H ~{in_vcf_file} | sort -k1,1d -k2,2n >> ~{out_prefix}.sorted.vcf
    ## bgzip
    bgzip ~{out_prefix}.sorted.vcf
    ## index
    tabix -f -p vcf ~{out_prefix}.sorted.vcf.gz
    >>>
    output {
        File vcf_file = "~{out_prefix}.sorted.vcf.gz"
        File index_file = "~{out_prefix}.sorted.vcf.gz.tbi"
    }
    runtime {
        docker: "quay.io/biocontainers/bcftools:1.16--hfe4b78e_1"
        memory: mem_gb + " GB"
        cpu: 1
        disks: "local-disk " + disk_size + " SSD"
        preemptible: 1 # can be useful for tools which execute sequential steps in a pipeline generating intermediate outputs
    }
}

