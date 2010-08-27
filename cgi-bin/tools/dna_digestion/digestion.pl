#Program that inputs a DNA sequence and the name of a restriction enzyme
#Shows where the enzyme would cut the DNA
#Written by Emily Hart 7/27/06
#Refactored by Johnathon Schultz 4/08/07

use strict;
use warnings;
use CXGN::Page;
use CXGN::Page::FormattingHelpers;
use CXGN::DB::Connection;
my $dbh=CXGN::DB::Connection->new();
my $page=CXGN::Page->new("Sol Genomics Network","john");
my ($dna_seq, $enz_name, $action)=$page->get_encoded_arguments("dna_seq", "enz_name", "action");

if($action eq "digest"){
    if (!is_valid_dna($dna_seq)){
#	$page-> message_page("Invalid DNA Sequence", "Please make sure that your sequence contains only the letters A, G, T, and C.");
	$page->header("Sol Genomics Network");
	print "<div align='center'>Invalid DNA Sequence<br />Please make sure that your sequence contains only the letter A, G, T, and C.</div>";
	$page->footer();
    }
    elsif(!is_valid_enzyme($enz_name, $dbh)){
#	$page-> message_page("Invalid Enzyme", "Please select an enzyme from the list.");
	$page->header("Sol Genomics Network");
	print "<div align='center'>Invalid Enzyme<br /> Please select an enzyme from the list.</div>";
	$page->footer();
    }
    elsif(!(find_cut_sites(is_valid_dna($dna_seq), $enz_name) || $enz_name eq "All")){
	no_cuts_found($enz_name);
	print "<h1>Error 1</h1>";

#	$page-> message_page("No Cuts Found", "Your sequence is not cut by $enz_name.");
    }
    else{
	my $dna = "";
	if($enz_name eq "All"){
	    my $enzymes = get_all_enzymes($dbh);
	    foreach my $enz(@$enzymes){
		my $result = find_cut_sites(is_valid_dna($dna_seq), $enz);
		if($result){
		    $dna .= "Your sequence was cut by $enz at:<br /> $result";
	        }
#		print "<h1>$enz</h1>";
	    }
	}
	else{
	    $dna = find_cut_sites(is_valid_dna($dna_seq), $enz_name);
	}
	if($dna){
	    $page->header("Sol Genomics Network");
	    print "<div align='center'>Cuts Found!<br /> <tt>$dna</tt></div>";
	    $page->footer();
	}
	else{
	    no_cuts_found($enz_name);
	}
    }
}
else{
    $page->header("Sol Genomics Network","Virtual DNA Digestion");
    display($dbh);
    $page->footer();
}

sub no_cuts_found{
	$page->header("Sol Genomics Network");
	my $message = "<div align='center'>No cuts found.<br /> Your sequence is not cut by ";
	if($enz_name eq "All"){
	    $message .= "any enzymes.</div>";
	}
	else{
	    $message .= "$enz_name.</div>";
	}
	print $message;
	$page->footer();  
}

#shows the main page
sub display{
    my $dbh = shift();
    print "<p>Enter the sequence of DNA that you would like to have virtually digested and select the enzyme that you would like to use.  Please do not enter a DNA sequence containing \"N\"s.</p>";
    print '<p>Enter DNA sequence:</p><form action="#" method="post"><textarea name="dna_seq" rows="10" cols="60" wrap="virtual"></textarea>';
    my $menu = enz_menu($dbh);
    print "<p>Select enzyme: &nbsp; $menu</p>";
    print '<input type="hidden" name="action" value="digest" /><input type="submit" value="Submit" /><input type="reset" value="Reset" /></form>';
}

#gets the names of the enzymes form the database and puts them into a drop down list
sub enz_menu{
    my $dbh = shift();
    $dbh -> do("set search_path=sgn");
    my $enzyme_ids = $dbh ->selectcol_arrayref("SELECT DISTINCT enzyme_id FROM enzyme_restriction_sites WHERE restriction_site IS NOT NULL");
    my $formatted_enz_ids = join ", ", @$enzyme_ids;
    my $enzyme_names = $dbh -> selectcol_arrayref("SELECT enzyme_name FROM enzymes WHERE enzyme_id IN($formatted_enz_ids) ORDER BY enzyme_name");
    my $menu_string = '<select name="enz_name">';
    $menu_string .= "<option value='All' default='True'>All Enzymes</option>";
    foreach my $e(@$enzyme_names){
	$menu_string .= "<option value = \"$e\">$e</option>";
    }
    $menu_string .= "</select>";
    return $menu_string;
}
#if the DNA sequence contains only A,G,T,C, returns the sequence
#otherwise returns false
sub is_valid_dna{
    my ($dna) = @_;
    $dna = uc $dna;
    $dna =~ s/\s//g;
    if($dna =~ m/^[ACGT]+$/){
	return $dna;
    }
    else{
	return "";
    }
}

#returns true if the enzyme is valid, false otherwise
sub is_valid_enzyme{
    my ($enz, $dbh) = @_;
    $dbh -> do("set search_path=sgn");
    my $ids = $dbh ->selectcol_arrayref("SELECT DISTINCT enzyme_id FROM enzyme_restriction_sites WHERE restriction_site IS NOT NULL");
    my $formatted_enz_ids = join ", ", @$ids;
    my $enzyme_names = $dbh -> selectcol_arrayref("SELECT enzyme_name FROM enzymes WHERE enzyme_id IN($formatted_enz_ids) ORDER BY enzyme_name");
    my $is_valid = 0;
    foreach my $e(@$enzyme_names){
	if($e eq $enz){
	    $is_valid = 1;
	}
    }
    return $is_valid || $enz_name eq "All";
    #Return the truth of this statement: The enzyme "is valid" or is equal to "All"
}

#returns an array of all possible sequences for the given enzyme
sub get_enz_seq_arr{
    my ($enz_name) = @_;
    $dbh -> do("set search_path=sgn");
    my $ids_ref = $dbh -> selectcol_arrayref("SELECT enzyme_id FROM enzymes WHERE enzyme_name = '$enz_name'");
    my $enz_id = $ids_ref->[0];
    my $seqs_ref = $dbh -> selectcol_arrayref("SELECT restriction_site FROM enzyme_restriction_sites WHERE enzyme_id = ?", undef, $enz_id);
    foreach my $seq(@$seqs_ref){
	$seq =~ s/\s//g;
    }
    return $seqs_ref;
}

#finds where the enzyme matches the dna sequence and returns an array of the indexes where they first match
sub find_matches{
    my ($dna_seq, $enz_name) = @_;
    my $seqs_ref = get_enz_seq_arr($enz_name);
    my @matches = ();
    for(my $i=0; $i<length($dna_seq); $i++){
	foreach my $enz_seq(@$seqs_ref){
	    $enz_seq =~ s/\^//g;
	    $enz_seq =~ s/(.*)\(\d*\/\d*\)/$1/;
	    my $enz_length = length($enz_seq);
	    my $sub_seq = substr($dna_seq, $i, $enz_length);
	    if($enz_seq eq $sub_seq){
		push @matches, $i;
	    }
	}
    }
    return \@matches;
}

#returns the reverse compliment of the given DNA sequence
sub reverse_compliment{
    my ($dna_seq) = @_;
    my %base_pair = ("A" => "T",
		      "T" => "A",
		      "G" => "C",
		      "C" => "G");
    my $compliment = "";
    my @seq = split "", $dna_seq;
    foreach my $s(@seq){
	$compliment.=$base_pair{$s};
    }
    my $rev_comp = reverse($compliment);
    return $rev_comp;    
}

#returns finished, formatted DNA
sub find_cut_sites{
    my($top_seq, $enz_name) = @_;
    my $rev_bottom_seq = reverse_compliment($top_seq);
    my $enzyme_seq_ref = get_enz_seq_arr($enz_name);
    my $enzyme_seq = $enzyme_seq_ref->[0];
    my $length_before_cut = this_length_before_cut($enzyme_seq);
    my $top_seq_cuts = find_matches($top_seq, $enz_name);
    foreach my $c(@$top_seq_cuts){
	my $cut = $c+$length_before_cut;
	$top_seq = insert_cut($top_seq, $cut);
	if (other_length_before_cut($enzyme_seq)){
	    my $bottom_seq = reverse($rev_bottom_seq);
	    $bottom_seq = insert_cut($bottom_seq, other_length_before_cut($enzyme_seq));
	    $rev_bottom_seq = reverse($bottom_seq);
	}	
    }
    my $rev_bottom_seq_cuts = find_matches($rev_bottom_seq, $enz_name);
    foreach my $c(@$rev_bottom_seq_cuts){
	my $cut = $c+$length_before_cut;
	$rev_bottom_seq = insert_cut($rev_bottom_seq, $cut);
	if (other_length_before_cut($enzyme_seq)){
	    my $rev_top_seq = insert_cut(reverse($top_seq), other_length_before_cut($enzyme_seq));
	    $top_seq = reverse($rev_top_seq);
	}
    }
    my $bottom_seq = reverse($rev_bottom_seq);
    if(has_cut_sites($top_seq) || has_cut_sites($bottom_seq)){
	if(length($top_seq) < 100 && length($bottom_seq) < 100){
	    return "$top_seq<br />$bottom_seq<br />";
	}
	else{
	    return wrap_text($top_seq, $bottom_seq);
	}
    }
    return "";
}

#returns true if a DNA sequence contains a ^
sub has_cut_sites{
    my($dna_seq) = @_;
    my @dna = split "", $dna_seq;
    my $has_cut_sites = 0;
    foreach my $d(@dna){
	if($d eq "^"){
	    $has_cut_sites = 1;
	}
    }
    return $has_cut_sites;
}

#returns how far after the match the strand will be cut
sub this_length_before_cut{
    my ($enzyme_seq) = @_;
    $enzyme_seq =~ s/\s//g;
    my $length_before_cut = "";
    if($enzyme_seq =~ m/^(.*)\^.*$/){
	$length_before_cut = length($1);
    }  
    elsif($enzyme_seq =~ m/(.*)\((\d*)\/\d*\)/){
	$length_before_cut = length($1) + $2;
    }
    return $length_before_cut;
}

#for enzymes which cut the strand and its compliment, returns how far after the match the other strand will be cut
sub other_length_before_cut{ 
    my ($enzyme_seq) = @_;
    my $length_before_cut = "";
    if($enzyme_seq =~ m/(.*)\(\d*\/(\d*)\)/){
	$length_before_cut = length($1) + $2;
    }
    return $length_before_cut;
}

#insert a cut before the index given, ignoring ^s
sub insert_cut{
    my ($dna_seq, $index) = @_;
    my $length = length($dna_seq);
    if($index > length($dna_seq)){
	return $dna_seq;
    }
    my @dna = split "", $dna_seq;
    my $letters_count = -1;
    my $char_count = -1;
    foreach my $d(@dna){
	$char_count++;
	if ($d =~ m/[ATGC]/){
	    $letters_count++;
	}
	if ($letters_count == $index){
	    last;
	}  
    }
    if($letters_count == $index-1){
	return $dna_seq."^";
    }
    elsif($letters_count < $index-1){
	return $dna_seq;
    }
    else{
	$dna_seq =~ s/^(.{$char_count})(.*)$/$1^$2/;
	return $dna_seq;
    }
}

#Returns the names of all the enzymes in the database.
sub get_all_enzymes{
    my ($dbh) = @_;
    $dbh->do("set search_path=sgn");
    my $enzymes = $dbh->selectcol_arrayref("SELECT DISTINCT enzyme_name from enzymes");
    return $enzymes;
}

#Wraps the dna text around the screen instead of letting it run off into the abyss.
#I know this is like the worst possible way to write this code but, its the only way I can think of for doing it
#Since I don't understand a lot of the perl "subtleties"
sub wrap_text{
    my ($top, $bottom) = @_;
    print CXGN::Page::FormattingHelpers->html_break_string($top,100,":");
    my $delimitedtop = CXGN::Page::FormattingHelpers->html_break_string($top,100,":");
    my $delimitedbottom = CXGN::Page::FormattingHelpers->html_break_string($bottom,100,":");
    my @toplines = split(/:/,$delimitedtop);
    my @bottomlines = split(/:/,$delimitedbottom);
    my $result = "";
    for(my $i = 0; $i < length(@toplines) && $i < length(@bottomlines); $i++){
	$result .= "$toplines[$i]<br />$bottomlines[$i]<br /><br />";
    }
    return $result;
}
