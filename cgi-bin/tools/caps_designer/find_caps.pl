use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/  page_title_html
                                       blue_section_html  /;
use CXGN::BioTools::CapsDesigner2;
use File::Temp;
use CatalystX::GlobalContext '$c';

my $page = CXGN::Page->new( "CAPS Designer Result", "Chenwei");

my ($format, $cheap_only, $exclude_seq, $cutno, $seq_data) = $page->get_arguments("format", "cheap", "start", "cutno", "seq_data");


#########Check if the input sequence is empty
if ($seq_data eq ''){
  err_page ($page, "Please enter sequence!\n");
}

########Check validity of exclusion number and cut number
if ($exclude_seq < 0){
  err_page ($page, "The number of excluded nucleotides may not be negative!");
}
if ($cutno < 1){
  err_page ($page, "The number of enzyme cut sites allowed must be greater than zero!");
}

##########Write the sequence into a temp file for processing
my $html_root_path = $c->config->{'basepath'};
my $doc_path =  $c->tempfiles_subdir('caps_designer');
my $path = $c->path_to($doc_path);
my ($tmp_fh, $tmp_name);

$tmp_fh = new File::Temp(
			 DIR => $path,
			 UNLINK => 0,
			);
$tmp_name = $tmp_fh->filename;
print $tmp_fh "$seq_data";
close $tmp_fh;




########Read enzyme information.  allENZYME is a file containing all enzyme information and it is located in the same directory as this script.
##allENZYME last updated August 17, 2009 to 09-10 prices
my $support_dir = $c->config->{'support_data_subdir'};
my $enzyme_file = $html_root_path . $support_dir . '/caps_designer/allENZYME';
my ($cost_ref, $cut_ref) = CXGN::BioTools::CapsDesigner2::read_enzyme_file($enzyme_file);




########Check if the input format is correct
my $format_check;
if ($format =~ /fasta/i){
  $format_check = CXGN::BioTools::CapsDesigner2::check_fasta($tmp_name);
} elsif ($format =~ /clustal/i){
  $format_check = CXGN::BioTools::CapsDesigner2::check_clustal($tmp_name);
} else {
  &err_page($page,'Unrecognized format - please enter your input in FASTA or CLUSTAL format.');
}

err_page($page,$format_check) unless $format_check;

########Check if the input has at least two sequences and 12 or fewer sequences
my $seq_num;
if ($format =~ /fasta/i){
    $seq_num = CXGN::BioTools::CapsDesigner2::check_input_number($tmp_name);
    if($seq_num < 2){
	&err_page($page, "Please enter at least two sequences!");
    }elsif($seq_num > 12){
	&err_page($page, "You may only enter up to 12 sequences!");
    } 
}


#########Process input sequence and return aligned sequences
my ($align_clustal,$align_fasta);
eval {
    ($align_clustal,$align_fasta) = CXGN::BioTools::CapsDesigner2::format_input_file($format, $tmp_name);
};

if (!$align_fasta || ($align_fasta eq "")){
  err_page($page, "Clustal alignment failed.  Please check input sequences!");
}
my ($seq_length, $parent_info_ref) = CXGN::BioTools::CapsDesigner2::get_seqs($align_fasta);

&err_page($page, "Please enter sequences containing only DNA nucleotides A, C, G, T or N.") unless CXGN::BioTools::CapsDesigner2::check_seqs($parent_info_ref);

&err_page($page, "The number of excluded nucleotides is too large for the sequences given.") if ($exclude_seq*2 >= $seq_length);



##########Find CAPS
#my ($position1_ref, $position2_ref, $cap_seq1_ref, $cap_seq2_ref) = CXGN::BioTools::CapsDesigner2::find_caps($parent1_id, $parent1_seq, $parent2_id, $parent2_seq, $seq_length, $cut_ref, $exclude_seq, $exclude_seq, $cutno, $cost_ref, $cheap_only);


my ($substrings_ref, $cutsites_ref, $uniques_ref) = CXGN::BioTools::CapsDesigner2::find_caps($parent_info_ref, $seq_length, $cut_ref, $exclude_seq, $cutno, $cost_ref, $cheap_only);


############Predict the size of bands
my ($size_ref) = CXGN::BioTools::CapsDesigner2::predict_fragments($cutsites_ref, $seq_length);



##########Prepare HTML printout content

my ($help_content, $sum_content, $caps_content, $plain_content);
$help_content = "<tr><th>1.</th><td>Polymorphism caused by an ambiguous nucleotide 'N' is not considered.</td></tr>";
$help_content .= "<tr><th>2.</th><td>Please check the provided local alignment around the predicted CAPs site in order to make sure it is not caused by alignment gaps.</td></tr>";
$help_content .= "<tr><th>3.</th><td>Analysis is based on sequenced parts of the PCR products.  Additional cutting sites and digested fragments may exist.</td></tr>";
$help_content .= "<tr><th>4.</th><td>Enzymes separated by a slash are isoschizimers.</td></tr>";
$help_content .= "<tr><th>5.</th><td>Enzyme price is based on NEB catalogue <a href = 'http://www.neb.com/nebecomm/price_list.pdf'>(http://www.neb.com/nebecomm/price_list.pdf)</a>.</td></tr>";

my $temp_str = join ", ", sort keys %$parent_info_ref;

$sum_content = "<tr><th>Aligned Sequences</th><td>$temp_str</td></tr>";
my $search_start = $exclude_seq + 1;
my $search_end = $seq_length - $exclude_seq;
$sum_content .= "<tr><th>Alignment Length(w/ gaps)</th><td>$seq_length bp</td><th>Search Range</th><td>bp $search_start - $search_end</td></tr>";
$sum_content .= "<tr><th>Cutting Sites Limit</th><td>$cutno</td></tr>";
$sum_content .= "<tr><th>Enzyme Selection</th><td>";
if ($cheap_only == 1){
  $sum_content .= "less than \$65/1000u";
}
else {
  $sum_content .= "All";
} 
$sum_content .= "</td></tr>";

# my %position1 = %$position1_ref;
# my %position2 = %$position2_ref;
# my %cap_seq1 = %$cap_seq1_ref;
# my %cap_seq2 = %$cap_seq2_ref;
 my %cut_site = %$cut_ref;
 my %cost = %$cost_ref;
# my %size1 = %$size1_ref;
# my %size2 = %$size2_ref;

my %position = %$cutsites_ref;
my %cap_seq = %$substrings_ref;
my %size = %$size_ref;
my %uniques = %$uniques_ref;
my %parent_info = %$parent_info_ref;


for my $current_enzyme(sort keys %cap_seq) {
    if(!defined $cost{$current_enzyme}) {$cost{$current_enzyme} = 'over $65/1000u';}
    $caps_content .= '<table width="100%" cellpadding="5" cellspacing="0" border="6"><tr><th>Enzyme</th><td>' . $current_enzyme . '</td><th>Price</th><td>' . $cost{$current_enzyme} . '</td></tr>';

    $caps_content .= '<tr><th>Recognition Sequence</th><td colspan="3">' . $cut_site{$current_enzyme} . '</td></tr>';

    for my $id (sort keys %parent_info) {
	$caps_content .='<tr><th>' . $id  . ' Current Site(s) </th><td>';
	if(@{$position{$current_enzyme}{$id}} == 0) {
	    $caps_content .= 'None.';
	}else{
	    for (sort {$a<=>$b}  @{$position{$current_enzyme}{$id}}){
		$caps_content .= $_ . '  ';
	    }
	}
	$caps_content .= '<th>' . $id . ' Fragments(s),bp </th><td>';
	for (@{$size{$current_enzyme}{$id}}){
	    $caps_content .= $_ . '  ';
	}
	$caps_content .= '</td></tr>';
    }

    for (sort {$a<=>$b} keys %{$cap_seq{$current_enzyme}}){
	$caps_content .= '<tr><th>CAPS Site</th><td>'. $_ . '</td><td colspan=2>';
	$caps_content .= '<table cellspacing="2" style="font-family:Lucida Console"><tr><th>';
	for my $id (sort keys %parent_info) {
	    if($id eq $uniques{$current_enzyme}{$_}) {
		$caps_content .= $id . '</th><td><tt>' . $cap_seq{$current_enzyme}{$_}{$id} . '</tt></td></tr><tr><th>';
	    }else{
		$caps_content .= $id . '</th><td><span style="color:gray"><tt>' . $cap_seq{$current_enzyme}{$_}{$id} . '</tt></span></td></tr><tr><th>';
	    }
	}
	$caps_content .= '</table>';
    }
    $caps_content .= '</td></tr>';
    $caps_content .= '</table><br /><br />';
}
$caps_content .= 'Black font denotes sequence with unique cut site(s). <br />' if $caps_content;

###############Prepare plain text result links
# my $out = CXGN::BioTools::CapsDesigner2::print_text($cost_ref,$cut_ref,$seq_length,$position1_ref, $position2_ref, $cap_seq1_ref, $cap_seq2_ref, $parent1_id, $parent2_id, $cheap_only, $size1_ref, $size2_ref, $cutno, $exclude_seq, $path);
 my $out = CXGN::BioTools::CapsDesigner2::print_text($cost_ref, $cut_ref, $seq_length, $cutsites_ref, $substrings_ref, $parent_info_ref, $cheap_only, $size_ref, $uniques_ref, $cutno, $exclude_seq, $path);

 $out =~ s/$html_root_path//;
 $align_fasta =~ s/$html_root_path//;
 $align_clustal =~ s/$html_root_path//;
 $plain_content .= "<tr><td><a target='blank' href = $out> View/download plain text result file</a></td></tr>";
 $plain_content .= "<tr><td><a target='blank' href = $align_clustal> View/download alignment in clustal format</a></td></tr>";
 $plain_content .= "<tr><td><a target='blank' href = $align_fasta> View/dowload alignment in fasta format</a></td></tr>";

 $page->header();
 print page_title_html("CAPS Designer Result");
 print blue_section_html('For experienced users','<table width="100%" cellpadding="5" cellspacing="0" border="0">' . $plain_content . '</table>');

#######The user can go back to the caps_input page and keep all the input.  Some browsers don't do that.
print "<form methed=\"post\" action=\"caps_input.pl\" name=\"capsinput\">";
print "<input type=\"hidden\" name=\"format\" value=\"$format\">";
print "<input type=\"hidden\" name=\"cheap\" value=\"$cheap_only\">";
print "<input type=\"hidden\" name=\"start\" value=\"$exclude_seq\">";
print "<input type=\"hidden\" name=\"cutno\" value=\"$cutno\">";
print "<input type=\"hidden\" name=\"seq_data\" value=\"$seq_data\">";
#print "<input type=\"hidden\" name=\"seq_select\" value=\"$seq_select\">";
print "<input type=\"submit\" value=\"Back to input\">";
print "</form>";
print "<br />";

print blue_section_html('Notes','<table width="100%" cellpadding="5" cellspacing="0" border="0">' . $help_content . '</table>');
print blue_section_html('Query Summary','<table width="100%" cellpadding="5" cellspacing="0" border="0">' . $sum_content . '</table>');
if ($caps_content) {
    print blue_section_html('CAPS Candidates',$caps_content);
}else{
    print blue_section_html('CAPS Candidates',"None.");
}
$page -> footer();

sub err_page {
  my $err_page = shift;
  my $err_message = shift;

  $c->throw( public_message => $err_message, notify => 0, is_client_error => 1 );
}
