# pangenie_wdl
WDL wrapper for running the PanGenie tool. Read more at [PanGenie](https://github.com/eblerjana/pangenie) for tool usage and general information, and at [Docker Hub](https://hub.docker.com/repository/docker/overcraft90/eblerjana_pangenie) for running the tool using docker.

## Main parameters

- *FORWARD_FASTQ*: compressed R1 FASTQ file
- *REVERSE_FASTQ*: compressed R2 FASTQ file
- *SAMPLE_NAME*: the sample name
- *PANGENOME_VCF*: the input vcf with variants to be genotyped
- *REF_GENOME*: a FASTA file of the reference genome for variant calling
- *SORT_INDEX_OUTPUT_VCF*: Should the output VCF be sorted, bgzipped and indexed? Default is true. If false, the output VCF is just gzipped.

## Testing locally

For example with cromwell or miniwdl, and using the small test dataset in the [`test` folder](test):

```
miniwdl run --as-me --copy-input-files PanGenie.wdl -i inputs.json
## or 
java -jar $CROMWELL_JAR run PanGenie.wdl -i inputs.json
```
