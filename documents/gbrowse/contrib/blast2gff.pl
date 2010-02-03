#!/usr/local/bin/perl -w

=head1 NAME

blast2gff.pl - Convert a BLAST result file into a GFF file

=head1 SYNOPSIS

  % blast2gff.pl --blast_result_file [blast result file] 
      --reference_sequence_file  [file with reference sequences (optional)] 
      --gff_output_file [gff file name (optional)]

=head1 DESCRIPTION

This script takes a blast result file and a set of reference sequences and 
generates a GFF file from it, with the following form:                                                                                      

 GroupUn.1786  tblastn drosophila_HSP 880 1035  .  +  . Drosophila_Match P91685                             

It also adds entries for reference sequences, if the --reference_sequence_file 
flag is used:                                      

 Group1.2  sequence  sequence  1  265115  .  + .  Sequence Group1.2                           

If the --make_dumpable flag is used, it adds information to the 9th column
("Class name") to make the alignments dumpable, e.g. Target EST:actg5.3  5 300
the query start and end sites

=head2 NOTES

This code should be considered beta. Be especially skeptical of the 
--make_dumpable feature, as it is it untested. Please report all bugs to
the gmod-gbrowse mailing list.

=head1 COMMAND-LINE OPTIONS

    --blast_result_file <blast result file>                      

(Mandatory) File with BLAST output        

    --reference_sequence_file <file with reference sequences>    

(Optional) FASTA formatted file with reference ("database") sequences that BLAST was 
run against. If specified, GFF entries for the reference sequences are created.

    --gff_output_file <gff file name>                            

(Optional) Name for GFF output file. If not supplied, we will write to STDOUT.

    --make_dumpable                                              

(Optional) Add information to the 9th column to make the alignments dumpable, 
e.g. Target EST:actg5.3  5 300 (where 5 and 300 are the query start and end sites)

=head1 SEE ALSO

Bioperl also provides BLAST to GFF capability with its 
scripts//utilities/search2gff.PLS script.

=head1 AUTHOR

Justin Reese

jtr4v at nospam alumni.zerospam.virginia.edu

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

use strict;
use Getopt::Long;
use Bio::SeqIO;
use Bio::SearchIO;

my $usage = "$0 [--make_dumpable] --blast_result_file [blast result file] --reference_sequence_file [file with reference sequences (optional)] --gff_output_file [gff file name (optional)]";

###########################
# user configurable options
###########################

##### Default values for reference sequence
# We'll always use Bio::Seq object's primary id attribute for Column 1
my $default_reference_sequence_col2_feature_source = "sequence"; # string, not a key name
my $default_reference_sequence_col3_feature_type = "sequence"; # string, not a key name
my $default_reference_sequence_col4_feature_start = "1"; # string, not a key name
# We'll always use Bio::Seq object's length attribute for Column 5
my $default_reference_sequence_col6_feature_score = "."; # string, not a key name
my $default_reference_sequence_col7_feature_strand = "+"; # string, not a key name
my $default_reference_sequence_col8_feature_phase = "."; # string, not a key name
# We'll always use "Sequence".(Bio::Seq object's primary id attribute) for Column 9

##### Default values for match features
my $default_KEY_NAME_match_col1_feature_name = 'name'; # KEY
my $default_KEY_NAME_match_col2_feature_source = 'algorithm'; # KEY
my $default_match_col3_feature_type = 'match'; # LITERAL STRING, NOT A KEY

##### Default values for HSP features
my $default_KEY_NAME_hsp_col1_feature_name = 'name'; # KEY
my $default_KEY_NAME_hsp_col2_feature_source = 'algorithm'; # KEY
my $default_hsp_col3_feature_type = 'hsp'; # LITERAL STRING, NOT A KEY

#######################
####### Parse options
#######################
my $blast_result_file;
my $reference_sequence_file;
my $gff_output_file;
my $GFF_OUTPUT_FILE_HANDLE;
my %Options;

GetOptions(\%Options,
	   "blast_result_file=s",
	   "reference_sequence_file=s",
	   "gff_output_file=s",
	   "force",
	   "make_dumpable",
	   );

if( exists($Options{blast_result_file}) ){
    $blast_result_file = $Options{blast_result_file};
}
else {
    die $usage."\n";
}

if( exists($Options{reference_sequence_file}) ){
    $reference_sequence_file = $Options{reference_sequence_file};
    if (! -r $reference_sequence_file ){
	die "Can't seem to read reference sequence file \'$reference_sequence_file\'\n";
    }
 }

if ( exists($Options{gff_output_file}) ){
    $gff_output_file = $Options{gff_output_file};
    if (! open $GFF_OUTPUT_FILE_HANDLE, ">$gff_output_file" ){
	die "Can't open gff output file \'$gff_output_file\' for writing: $!\n";
    }
}
else {
    $GFF_OUTPUT_FILE_HANDLE = *STDOUT; # if user doesn't specify outfile, write to standard out
}

# get and write out reference sequences
if( exists($Options{reference_sequence_file}) ){
    my %reference_seq_objects;
    my $stream_in = Bio::SeqIO->new(
				    '-file' => $reference_sequence_file,
				    '-format' => 'fasta',
				    );

    while (my $new_seq_obj = $stream_in->next_seq){
	my $primary_id;
	unless ($primary_id = $new_seq_obj->primary_id){
	    die "Can't find primary id for sequence object: ". $new_seq_obj->id." while parsing reference sequences";
	}
	$reference_seq_objects{$new_seq_obj->primary_id} = $new_seq_obj;

	my $sequence = $new_seq_obj->seq;
	if (length($sequence) < 1){
	    die "Sequence for ".$new_seq_obj->seq;
	}

 	print $GFF_OUTPUT_FILE_HANDLE 
 	    $new_seq_obj->primary_id."\t".
 	    $default_reference_sequence_col2_feature_source."\t".
 	    $default_reference_sequence_col3_feature_type."\t".
 	    $default_reference_sequence_col4_feature_start."\t".
 	    $new_seq_obj->length."\t".
 	    $default_reference_sequence_col6_feature_score."\t".
 	    $default_reference_sequence_col7_feature_strand."\t".
 	    $default_reference_sequence_col8_feature_phase."\t".
 	    "Sequence ".$new_seq_obj->primary_id."\n",

	}

}

my $blast_result_stream = new Bio::SearchIO(
					'-format' => 'blast', 
					'-file'   => $blast_result_file,
					);

while( my $result = $blast_result_stream->next_result ) {
    my $prot=$result->query_name;

    while( my $hit = $result->next_hit ) {

	##############
	# get 'match' data and write out 'match' line
	my $match_col1_name = replace_undef($hit->$default_KEY_NAME_match_col1_feature_name);
	my $match_col2_source = replace_undef($hit->$default_KEY_NAME_match_col2_feature_source);
	my $match_col3_type = replace_undef($default_match_col3_feature_type);

	my @starts_for_hit_and_query = $hit->start;
	my $match_col4_start = replace_undef($starts_for_hit_and_query[1]);
	my @ends_for_hit_and_query = $hit->end;
	my $match_col5_end = replace_undef($ends_for_hit_and_query[1]);

	my $match_col6_score = replace_undef($hit->expect);
	my $match_col7_strand;
	my @strand_for_hit_and_query = $hit->strand;
	my $match_strand = $strand_for_hit_and_query[1];
	if ( $match_strand == 1 ){
	    $match_col7_strand = "+";
	}
	elsif ( $match_strand == -1 ){
	    $match_col7_strand = "-";
	}
	else {
	    $match_col7_strand = "NA";
	}
	my $match_col8_phase = "."; # phase is not relevant for match line

	my $match_col9_class_name;
	if( exists($Options{make_dumpable}) ){ # need to put in query start/stop info to make dumpable
            # Target EST:agt830.3 504 1

	    $match_col9_class_name = "Target ".
		$match_col2_source.":".
		replace_undef($result->query_name)." ".
		replace_undef($starts_for_hit_and_query[0])." ".
		replace_undef($ends_for_hit_and_query[0]);
	}
	else {
	    $match_col9_class_name = upper_case_first_letter(replace_undef($default_match_col3_feature_type))." ".
		replace_undef($result->query_name);
	}

        # write out match line
 	print $GFF_OUTPUT_FILE_HANDLE 
	    $match_col1_name."\t".
	    $match_col2_source."\t".
	    $match_col3_type."\t".
	    $match_col4_start."\t".
	    $match_col5_end."\t".
	    $match_col6_score."\t".
	    $match_col7_strand."\t".
	    $match_col8_phase."\t".
	    $match_col9_class_name."\n";

	while( my $hsp = $hit->next_hsp ) {

	    # get 'hsp' data and write out 'hsp' line	    
	    my $hsp_col1_name = replace_undef($hit->$default_KEY_NAME_hsp_col1_feature_name);
	    my $hsp_col2_source = replace_undef($hit->$default_KEY_NAME_hsp_col2_feature_source);
	    my $hsp_col3_type = replace_undef($default_hsp_col3_feature_type);
	    my $hsp_col4_start = replace_undef($hsp->hit->start);
	    my $hsp_col5_end = replace_undef($hsp->hit->end);
	    my $hsp_col6_score = replace_undef($hsp->expect);
	    my $hsp_col7_strand;
	    my $hsp_strand = $hsp->hit->strand;
	    if ( $hsp_strand == 1 ){
		$hsp_col7_strand = "+";
	    }
	    elsif ( $hsp_strand == -1 ){
		$hsp_col7_strand = "-";
	    }
	    else {
		$hsp_col7_strand = "NA";
	    }
	    my $hsp_col8_phase = replace_undef($hsp->hit->frame);
	       
	    my $hsp_col9_class_name;
	    if( exists($Options{make_dumpable}) ){ # need to put in query start/stop info to make dumpable
		# Target EST:agt830.3 504 1
		$hsp_col9_class_name = "Target ".
		    $match_col2_source.":".
		    replace_undef($result->query_name)." ".
		    replace_undef($hsp->query->start)." ".
		    replace_undef($hsp->query->end);
	    }
	    else {
		$hsp_col9_class_name = upper_case_first_letter(replace_undef($default_hsp_col3_feature_type))." ".
		    replace_undef($result->query_name);
	    }

	    # write out HSP lines
	    print $GFF_OUTPUT_FILE_HANDLE 
		$hsp_col1_name."\t".
		$hsp_col2_source."\t".
		$hsp_col3_type."\t".
		$hsp_col4_start."\t".
		$hsp_col5_end."\t".
		$hsp_col6_score."\t".
		$hsp_col7_strand."\t".
		$hsp_col8_phase."\t".
		$hsp_col9_class_name."\n";

	    undef;

	}

    }

}

sub replace_undef {
    my $value = shift;
    if (! defined ($value) ) {
	$value = "NA";
    }
    return $value;
}

sub upper_case_first_letter {
    my $value = shift;
    my $first_letter;
    if ( $value =~ s/^(.)// ){
	$first_letter = $1;
    }
    $value = uc($first_letter).$value;
    return $value;
}
