
=head1 NAME

show_ssr.pl - find SSR sequences

=head1 DESCRIPTION

Generates an simple table with SSR sequences from data submitted through the input page (index.pl in this directory). It is a web script that supports the following cgi parameters:

=over 5

=item seq_data

seq_data is the actual data uploaded; it should be in FASTA format.

=item upload

upload is an optional file upload containing a FASTA formatted sequence as input

=item ssr_min

denotes the minimum length needed to be found.

=item ssr_max

denotes the maximum length needed to be found.

=item ssr_repeat

denotes the minimum number of times a substring must be repeated to be found.

=item type

=over 5

=item 'html' for HTML output

=item 'tab' for tab delimited output

=back 5

=back

=head1 AUTHOR(S)

Search code by Chenwei Lin (cl295@cornell.edu) with edits by Robert Albright (rfa5). Documentation and HTML interface by Robert Albright (rfa5@cornell.edu).

=cut

use strict;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use Bio::SeqIO;

our $page = CXGN::Page->new("SSR Search Results", "rfa5");

my $r = Apache2::RequestUtil->request;
$r->content_type("text/html");
if ($r->method() ne "POST") {
  post_only($page);
  exit;
}


my ($output_type, $unit_low, $unit_high, $repeat_time, $seq_data) = $page->get_arguments("type", "ssr_min", "ssr_max", "ssr_repeat", "seq_data");

# Check for input errors
my $upload = $page->get_upload("upload");
my $upload_fh;

# print STDERR "Uploading file $args{upload_file}...\n";
if (defined $upload) { 
    $upload_fh = $upload->fh();
    
    while (<$upload_fh>) { 
	$seq_data .=$_;
    }    
}

if ($seq_data eq "") {
    user_error($page, "No sequence was entered!");
}


# Perform SSR search
my %out = search($unit_low, $unit_high, $repeat_time, $seq_data);

if ($output_type eq "tab") {
    print " ";
    print $out{tab};
} elsif ($output_type eq "html") {
    $page->header();
    print page_title_html("SSR Search Results");
    print blue_section_html("$out{num} SSRs Found",'<table width="100%" cellpadding="5" cellspacing="0" border="0" summary=""><tr><td>' . $out{html} . '</td></tr></table>');
    $page -> footer();    
} else {
    user_error($page, "Unrecognized output type!");
}

sub search {
    (@_ == 4) or die "Please supply minimum unit length, maximum unit length, minimum repeat time, input sequence (in blast format), true if output should be HTML, false if tab delimited.";

    my ($unit_low, $unit_high, $repeat_time, $inseq) = @_;
    $repeat_time = $repeat_time - 1;
    my %seq = ();

    # open input string as a file
    open IN, "+<", \$inseq or die "Couldn't open input file \n";
    my $seqio = Bio::SeqIO->new( -format=>"fasta",
				 -fh => \*IN,
				 );

    #Search and write result to output file
    my $result_table = '<table width="100%"><tr><th>Sequence</th><th>Motif</th><th>Repeat</th><th>Start</th><th>Length</th></tr>'."\n";
    my $result_tab   = "Sequence\tMotif\tRepeat\tStart\tLength\n";
    
    open OUT_TAB, "+>>", \$result_tab or die "Couldn't open output file\n";
    open OUT_TABLE, "+>>", \$result_table or die "Couldn't open output file\n";
    
    my $numResults=0;
    while (my $seqobj = $seqio->next_seq()) {
	my $id = $seqobj->display_id(); #substr ($_, 1);
	my $length = $seqobj->length(); # length $seq{$_};
	my $seq = $seqobj->seq();

#	print OUT_TABLE '<tr><td colspan="5">'.$seq.'</td></tr>';
 
	#seach for patterns repeats
	while ($seq =~ /([ATGC]{$unit_low,$unit_high}?)(\1{$repeat_time,})/g){    
	    my $actual_repeat_time = (length $&)/(length $1);
	    my $start = (length $`) + 1;
	    my $match = $1;
	    my $fullmatch =$&;

	    #screen out single nucleotide repeat  
	    if (!($match =~ /^A+$|^T+$|^G+$|^C+$/)) {
		#for patterns longer than 2 necleotides, print out all the hits
		if (length $match >=3){
		    print OUT_TAB "$id\t$1\t$actual_repeat_time\t$start\t$length\n";
		    print OUT_TABLE "<tr><td>$id</td><td>$1</td><td>$actual_repeat_time</td><td>$start</td><td>$length</td></tr>\n";
		    $numResults++;
		}
		#If the repeat time specified in command line is less than 4, for patterns of 2 nucleotides, print out matches of at least 4 repeats. 
		elsif ($actual_repeat_time >3){
		    print OUT_TAB "$id\t$1\t$actual_repeat_time\t$start\t$length\n";
		    print OUT_TABLE "<tr><td>$id</td><td>$1</td><td>$actual_repeat_time</td><td>$start</td><td>$length</td></tr>\n";
		    $numResults++;
		}
	    }
	}
    }
    print OUT_TABLE "</table>\n";
    close OUT_TABLE;
    close OUT_TAB;
    
    my %result = ();
    $result{html} = $result_table;
    $result{tab} = $result_tab;
    $result{num} = $numResults;
    return %result;
}

sub post_only {
  my ($page) = @_;

  $page->header();

  print <<EOF;

  <h4>SGN SSR Interface Error</h4>

  <p>SSR subsystem can only accept HTTP POST requests</p>

EOF

  $page->footer();
}

sub user_error {
  my ($page, $reason) = @_;

  $page->header();

  print <<EOF;

  <h4>SGN SSR Interface Error</h4>

  <p>$reason</p>
EOF

  $page->footer();
  exit(0);
}
