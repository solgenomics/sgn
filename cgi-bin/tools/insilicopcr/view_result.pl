#!/usr/bin/perl -w


=head1 NAME

view_result.pl - 

=head1 DESCRIPTION
Recieves the blast report from pcr_blast_result.pl in the tabular format (m8). will parse
the blast report to find a forward and a reverse result that is on the same place and with 
mismatches less than what the user provided. Will present the results in a fasta format. 
And will draw a gel image of the product bands. 

=head1 AUTHOR

Waleed Haso wh292@cornell.edu 


=cut
use strict;
use warnings;
use English;
use File::Basename;
use File::Temp qw/tempfile/;
use File::Basename;
use File::Spec;
use CXGN::Page;
use CXGN::BlastDB;
use CXGN::Apache::Error;
use Bio::Seq;
use Bio::Graphics::Gel;
use CXGN::Page::FormattingHelpers qw/info_section_html page_title_html columnar_table_html html_break_string/;
use CatalystX::GlobalContext '$c';

##############################################################################################################################
our $page = CXGN::Page->new( "PCR Search Report", "Waleed");
our %params;
our $tempfiles_subdir_rel = File::Spec->catdir($c->config->{'tempfiles_subdir'},'blast'); #path relative to website root dir
our $tempfiles_subdir_abs = File::Spec->catdir($c->config->{'basepath'},$tempfiles_subdir_rel); #absolute path
##############################################################################################################################


my @arglist = qw/report_file outformat seq_count productLength database allowedMismatches flength rlength/;
@params{@arglist} = $page->get_encoded_arguments(@arglist);
$params{report_file} =~ s/\///g; #remove any slashes.  that should stop any nefarious path monkeying
 

# get the name of the database w/o the directory names (not sure if this works for all datasets...)
if ($params{database}=~/\/(\w+?)$/) { 
    $params{database} = $1; 
}

#my ($bdb) = CXGN::BlastDB->search_ilike(title=> "%$params{database}%");
my ($bdb) = CXGN::BlastDB->from_id($params{database});

die "No such database" if (!$bdb);

##############################################################################################################################

my $raw_report_file       = File::Spec->catfile($tempfiles_subdir_abs,$params{report_file});
my $raw_report_url        = File::Spec->catfile($tempfiles_subdir_rel,$params{report_file});


##############################################################################################################################

$page->header();

print page_title_html('PCR Results');


print <<EOH;
<div align="center" style="margin-bottom: 1em">
  Note: Please <b>do not bookmark</b> this page. BLAST results are
  automatically deleted periodically.  To save these results, use your
  browser's <b>save</b> feature.
</div>
EOH

##############################################################################################################################
#Parsing the blast m8 result file


#Report parsing method was taken from /util/blast_result_handle.pl by Aure 

my (%query_id, %subject_id, %identity, %align_length, %mismatches, %gap_openings, %q_start, %q_end, %s_start, %s_end, 
      %e_value, %hit_score, %orientation);

my (@fprimer_ids ,@rprimer_ids);

  
open(my $res_fh, "<$raw_report_file") or die "$! opening $raw_report_file for reading";
  
my $line=0;

  while (<$res_fh>) {
      $line++;
      
      my @data=split(/\t/, $_);
      
      #separating forward primers from reverse primers using 2 arrays
      push (@fprimer_ids , $line) if ($data[0] eq 'FORWARD-PRIMER');
      push (@rprimer_ids , $line) if ($data[0] eq 'REVERSE-PRIMER');

      $query_id{$line}=$data[0];
      $subject_id{$line}=$data[1];
      $identity{$line}=$data[2];
      $align_length{$line}=$data[3];
      $mismatches{$line}=$data[4];
      $gap_openings{$line}=$data[5];
      $q_start{$line}=$data[6];
      $q_end{$line}=$data[7];
      $s_start{$line}=$data[8];
      $s_end{$line}=$data[9];
      $e_value{$line}=$data[10];
      $hit_score{$line}=$data[11];

      #finding the orientation of the strand "+" is  5'->3' and "-" 3'->5'
      $orientation{$line}= ($s_end{$line}-$s_start{$line} > 0)? '+' : '-';
  }
 
close $res_fh;


#NOTE: remeber that since the reverse primer is in the the reverse orientation 
#      $s_start contains the end coordinate, while $s_end contais the start 


###########################   PCR Method  ################################## 
#                                                                          #
# 3' ----------------------------------------- 5'  this is the '-' strand  #
#    |||||||||||||||||||||||||||||||||||||||||                             #
# 5' ----------------------------------------- 3'  this is the '+' strand  #
#                                                                          #
# After heating and adding the primers :                                   #
#                                                                          #
# 3' ----------------------------------------- 5'  this is the '-' strand  #
#       |||||                                                              #
#    5' ----- 3' Forward Primer --->                                       #
#                                                                          #
#              <--- Reverse Prime  3'-------5'                             #
#                                    |||||||                               # 
# 5' ----------------------------------------- 3'  this is the '+' strand  #
#                                                                          #
#                                                                          #
# So, To perform an In Silico PCR we are working with only one strand      #
# The + strand. The forward primer will be located at the begining and     #
# it is not a reverse complement. The reverse primer will be located down  #
# stream of the forward primer and it is a reverse complement of the       #
# subject strand.                                                          #
############################################################################




#cycling through the hits to see if 2 hits match the same subject seq
#and validating the orientation of the strand. 

#The primer on the parent's + strand should be as the following:
#The forward primers should always be + orientaion
#The reverse primers should always be - orientation

#The primer on the parent's - strand should be as the following:
#The forward primers should always be - orientaion
#The reverse primers should always be + orientation


#Also, validating that the forward primer is located upstream of the reverse


##NOTE: $s_end of the reverse primer contains the start of the primer
##      $s_start of reverse contains the end of the primer 
##      this is b/c of the '-' orientation of the reverse complement


#Finding Results
my @pcr_results; #is an array of array references [forward Primer # , reverse primer #, + or - for parent orientation] 

foreach my $forward (@fprimer_ids){
  
    foreach my $reverse (@rprimer_ids){
	
		if (     $subject_id{$forward} eq $subject_id{$reverse}    #both on the same subject seq
            and  $s_start{$reverse}- $s_start{$forward}<= $params{productLength} #product Length is within user's choice
            and  $mismatches {$forward} <= $params{allowedMismatches}  #Allowed mismatches by user
            and  $mismatches {$reverse} <= $params {allowedMismatches}
            and  $align_length{$forward} == $params {flength}  #primers match exact length
            and  $align_length {$reverse} == $params {rlength}
		   )
		{
            
            #if the product is in the + starnd of parent seq add a + sign in the array
            
            if ( $orientation{$forward} eq '+'     #forward is on the + strand
            and  $orientation{$reverse} eq '-'     #reverse is on the - strand b/c its a complement
            and  $s_end{$forward} < $s_end{$reverse}  #end of forward located upstream of beginning of reverse 
            ){
            	push (@pcr_results , [$forward,$reverse, '+']) ;
             }
            	
            #if the product is in the - strand of the parent seq add a - sign in the array	
            elsif ( $orientation{$forward} eq '-'     #forward is on the - strand (complemet here)
               and  $orientation{$reverse} eq '+'     #reverse is on the + strand 
               and  $s_end{$forward} > $s_end{$reverse}  #end of forward located upstream of beginning of reverse 
              )
               {
                  push (@pcr_results , [$forward,$reverse, '-']);
               }	
         }
    }#end of the 4each loop

}
##############################################################################################################################


my $find_seq;
my $find_subseq;
my $find_id;
my $report_download_link = qq|[ <a href="$raw_report_url">BLAST OUTPUT</a> ]|;


my @product_sizes; #for the gel




print info_section_html( title => 'PCR Report',
          subtitle => $report_download_link,
          contents => "\n");



if (scalar(@pcr_results) ==  0 ){
    print <<EOF;
    <div style="border: 1px solid gray; padding: 1em 2em 1em 2em">
	<P> No PCR Product Found </P>
    </div><BR>

EOF
}
 
else{

    foreach my $result (@pcr_results){
	
	#finding parent sequence
	$find_seq =$bdb->get_sequence( $subject_id{$result->[0]});
	#finding the pcr result sequence
	$find_subseq = $find_seq->subseq($s_start{$result->[0]},$s_start{$result->[1]}) if $result->[2] eq '+';
	$find_subseq = $find_seq->subseq($s_start{$result->[1]},$s_start{$result->[0]}) if $result->[2] eq '-';
	
	######################################################################################
	
	#generating sequence object for the result to be able to find its molecular weight
	my $seq_obj = Bio::Seq->new(-seq       => $find_subseq ,
                                -alphabet  => 'dna' 
                                );


	my $seq_size = $seq_obj->length;
   	push (@product_sizes , $seq_size);
    
    #finding the ID of the sequence and adding + sign if it is on the plus strand and - if its on minus strand and some coordinates
	$find_id = $find_seq->id();
	$find_id .= $result->[2] eq '+' ? ' strand = plus, ' : ' strand = minus, ';
	$find_id .= " start = $s_start{$result->[0]}, end = $s_start{$result->[1]}, size = $seq_size bp";
	 
	#######################################################################################

	#reverse complementing $find_subseq if the orientation is '-'
	$find_subseq = $seq_obj->revcom->seq if $result->[2] eq '-'; 
	
	$find_subseq = html_break_string($find_subseq , 90);
	

	print <<EOF;
	
	<div style="border: 1px solid gray; padding: 1em 2em 1em 2em">    	
	    <span class="sequence">&gt; $find_id<BR> $find_subseq</span>
	    <BR>
	  
	    
	</div><BR>
EOF

    }

##############################################################################################################################
#Generating a gel of the results 

    my $gel = Bio::Graphics::Gel->new('pcr' => \@product_sizes,             	
            	      -lane_length => 200,
            	      -bandcolor => [0xff,0xc6,0x00]);
    
    my $gel_img = $gel->img->png;
    

    #saving the gel img in a temp file 
    my $gel_img_tempdir = $c->path_to( $c->tempfiles_subdir('temp_images') );
    
    my ($fh ,$temp_file) = tempfile( DIR => $gel_img_tempdir, TEMPLATE=>"gel_XXXXXX", SUFFIX => ".png");
    print $fh $gel_img;

    my $base_temp = basename ($temp_file);

    #generating the url
    my $img_url = File::Spec->catdir( $c->config->{'tempfiles_subdir'},
            	      "temp_images", $base_temp
            	    );


print info_section_html( title => 'Agarose Gel ',
             contents => <<EOF);


<img border="1" style="margin-right: 1em" src="$img_url" />   
EOF
} 
$page->footer();


###############################

