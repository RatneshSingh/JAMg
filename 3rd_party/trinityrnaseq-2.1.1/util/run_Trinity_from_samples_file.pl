#!/usr/bin/env perl

use strict;
use warnings;
use Getopt::Long qw(:config no_ignore_case bundling);
use FindBin;
use Cwd;

######################################################
## Set to base directory of the Trinity installation:
my $BASEDIR = "$FindBin::Bin/../";
######################################################

my $usage = <<__EOUSAGE__;


##########################################################################################################
#
#  Required:
#
#  --samples_file <string>         tab-delimited text file indicating biological replicate relationships.
#                                   ex.
#                                        cond_A    cond_A_rep1    A_rep1_left.fq    A_rep1_right.fq
#                                        cond_A    cond_A_rep2    A_rep2_left.fq    A_rep2_right.fq
#                                        cond_B    cond_B_rep1    B_rep1_left.fq    B_rep1_right.fq
#                                        cond_B    cond_B_rep2    B_rep2_left.fq    B_rep2_right.fq
#
#                                   # note, Trinity-specific parameter settings should be included in the samples_file like so:
#                                   # (only --max_memory is absolutely required, since defaults exist for the other settings)
#                                   --CPU=6
#                                   --max_memory=10G
#                                   --seqType=fq
#                                   --SS_lib_type=RF
#
#
#
#
#  Optional:
#
#  -I                              Interactive mode, waits between commands.
#
###########################################################################################################

__EOUSAGE__

    ;


my $help_flag;
my $read_samples_descr_file;
my $PAUSE_EACH_STEP = 0;
my $GENES_TOO = 0;

&GetOptions ( 'h' => \$help_flag,
              'samples_file=s' => \$read_samples_descr_file,
              'I' => \$PAUSE_EACH_STEP,
              'genes_too' => \$GENES_TOO,

);

if ($help_flag || ! $read_samples_descr_file) {
    die $usage;
}

{
    ## Check for required software
    my @needed_tools = qw (R bowtie bowtie-build); # Trinity.pl, RSEM, and samtools are set by relative paths.
    my $missing_flag = 0;
    foreach my $prog (@needed_tools) {
        my $path = `which $prog`;
        unless ($path =~ /\w/) {
            print STDERR "\n** ERROR, cannot find path to required software: $prog **\n";
            $missing_flag = 1;
        }
    }
    if ($missing_flag) {
        die "\nError, at least one required software tool could not be found. Please install tools and/or adjust your PATH settings before retrying.\n";
    }
}


my $workdir = cwd();

my %PARAMS; 
my %conditions_to_read_info = &parse_sample_descriptions($read_samples_descr_file, \%PARAMS);

my @conditions = sort keys %conditions_to_read_info;

## first, gunzip the inputs as needed.

my $reads_ALL_left_fq = "reads.ALL.left.fq";
my $reads_ALL_right_fq = "reads.ALL.right.fq";

my $REGENERATE_ALL_FQ = 1;
if (-s $reads_ALL_left_fq && -s $reads_ALL_right_fq) {
    $REGENERATE_ALL_FQ = 0;
}


## concatenate all entries before running Trinity


foreach my $condition (@conditions) {
    
    my $replicates_href = $conditions_to_read_info{$condition};
    
    my @replicates = keys %$replicates_href;
    foreach my $replicate (@replicates) {
        my ($left_fq_file, $right_fq_file) = @{$replicates_href->{$replicate}};
         
    
        if (-s "$left_fq_file.gz" && ! -s $left_fq_file) {
            &process_cmd("gunzip -c $left_fq_file.gz > $left_fq_file",
                         "Uncompressing $left_fq_file.gz"
                         );
        }
        
        if ($right_fq_file && -s "$right_fq_file.gz" && ! -s $right_fq_file) {
            &process_cmd("gunzip -c $right_fq_file.gz > $right_fq_file",
                         "Uncompressiong $right_fq_file.gz");
        }
        
        if ($REGENERATE_ALL_FQ) {
            
            &process_cmd("cat $left_fq_file >> $reads_ALL_left_fq",
                         "Concatenating left.fq files");
            
            &process_cmd("cat $right_fq_file >> $reads_ALL_right_fq",
                         "Concatenating right.fq files"
                         ) if $right_fq_file;  ## only left if 'single'
            
        }
        
    }    
    
}

unless (-s "trinity_out_dir/Trinity.fasta") {
    
    my $cmd;

    if (-s $reads_ALL_right_fq) {
        ## got pairs
    
        ## Run Trinity:
        $cmd = "$BASEDIR/Trinity --left $reads_ALL_left_fq --right $reads_ALL_right_fq ";
        
    }
    else {
        # run left as single
        $cmd = "$BASEDIR/Trinity --single $reads_ALL_left_fq ";
        
    }
    
    my @trinity_params = qw ( 
--seqType 
--max_memory 
--CPU 
--SS_lib_type 
--monitoring 
--trimmomatic 
--normalize_reads 
--jaccard_clip
--full_cleanup
--quality_trimming_params
--grid_conf

 );
    
    my %trin_params = map { + $_ => 1 } @trinity_params;

    foreach my $param (keys %PARAMS) {
        if ($trin_params{$param}) {
            my $val = $PARAMS{$param};
            if (defined $val) {
                $cmd .= " $param $val ";
            }
            else {
                $cmd .= " $param ";
            }
        }
    }
    
    &process_cmd($cmd, "Running Trinity de novo transcriptome assembly");
    
}



exit(0);



####
sub process_cmd {
    my ($cmd, $msg) = @_;


    if ($msg) {
        print "\n\n";
        print "#################################################################\n";
        print "$msg\n";
        print "#################################################################\n";
    }
    
    print "CMD: $cmd\n";
    if ($PAUSE_EACH_STEP) {
        print STDERR "\n\n-WAITING, PRESS RETURN TO CONTINUE ...";
        my $wait = <STDIN>;
        print STDERR "executing cmd.\n\n";
        
    }
    

    my $time_start = time();
    
    my $ret = system($cmd);
    my $time_end = time();

    if ($ret) {
        die "Error, CMD: $cmd died with ret $ret";
    }

    my $number_minutes = sprintf("%.1f", ($time_end - $time_start) / 60);
    
    print "TIME: $number_minutes min. for $cmd\n";
    

    return;
}


####
sub parse_sample_descriptions {
    my ($read_samples_descr_file, $PARAMS_href) = @_;

    my %samples_descr;
    
    
    open (my $fh, $read_samples_descr_file) or die $!;
    while (<$fh>) {
        if (/^\#/) { next; }
        unless (/\w/) { next; }
        s/^\s+|\s+$//g;
        chomp;
        my @x = split(/\t/);
        if (/=/ && scalar(@x) == 1) {
            my ($key, $val) = split(/=/, $x[0]);
            $PARAMS_href->{$key} = $val;
        }
        else {
        
            
            my ($condition, $replicate, $reads_left, $reads_right) = @x;
            
            ## remove gzip extension, will convert to gunzipped version later 
            $reads_left =~ s/\.gz$//;
            $reads_right =~ s/\.gz$// if $reads_right;
        
            $samples_descr{$condition}->{$replicate} = [$reads_left, $reads_right];
        }
    }
    
    close $fh;
    
    return(%samples_descr);
    
    
}
