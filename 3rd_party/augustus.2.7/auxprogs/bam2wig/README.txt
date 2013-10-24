Installation instructions:

1. Go to Makefile and modify the value of SAMTOOLS variable
2. Type Make from command prompt


Examples:
A file test.bam has ben included. You can try bam2wig by trying out
the following examples,

a) ./bam2wig test.bam 
b) ./bam2wig -t "my_specified_track" -r chr3L test.s.bam 

Example (b) can only be done if an index file for test.s.bam exists. 
Do "samtools index test.s.bam" and a file "test.s.bam.bai" will be generated.

Tonatiuh Pena
17-June-2012
