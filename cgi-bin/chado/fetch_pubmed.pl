
use strict;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / info_section_html page_title_html html_optional_show/;
use CXGN::Chado::Publication;

use CXGN::Login;
use CXGN::People;
use CXGN::Contact;
use CXGN::Tools::Pubmed;
use CXGN::Tools::Text qw / sanitize_string /;
use CXGN::DB::Connection;

use base qw / CXGN::DB::ModifiableI /;

my $page=CXGN::Page->new("Fetch PubMed","Naama");
my $dbh = CXGN::DB::Connection->new();

my $logged_in_person_id=CXGN::Login->new($dbh)->verify_session();
my $logged_in_user=CXGN::People::Person->new($dbh, $logged_in_person_id);
my $logged_in_person_id=$logged_in_user->get_sp_person_id();
my $logged_in_username=$logged_in_user->get_first_name()." ".$logged_in_user->get_last_name();
my $logged_in_user_type=$logged_in_user->get_user_type();

#only curators can access this page
if($logged_in_user_type eq 'curator') {
    $page->header();
    my %args=$page->get_all_encoded_arguments();
    my $ids = $args{"pubmed_ids"};
    my $curator_id= $args{curator_id};
    my $action = $args{action};
   
    my @fail=();
    if($ids) {
	my @pubmeds = split (/\r\n/, $ids);
	if(@fail) {
            my $fail_str="";
            foreach(@fail) {    $fail_str .= "<li>$_</li>\n"; }
	    print <<END_HTML;
            
            <table width=80% align=center>
            <tr><td>
            <p>Could not feth pubmed ids  for the following reasons</p>
            <ul>
            $fail_str
            </ul>
            <p>Please use your browser\'s back button to try again.</p>
            </td></tr>
            <tr><td><br /></td></tr>
            </table>
END_HTML
        }
        else {
	    print qq | <br/><b> Fetched the following  publications from PubMed</b> | ;
	    my $pubmed_string;
	    my $count=0;
	    foreach my $pubmed (@pubmeds) { 
		my $pub = CXGN::Chado::Publication->new($dbh);
		$pub->set_accession($pubmed);
		CXGN::Tools::Pubmed->new($pub); #call eutils and populates the publication object with all necessary fields
		if ($pub->get_title()) {
		    $count++;
		    my $pub_ref=$pub->print_pub_ref();
		    $pubmed_string .= $pubmed . "|";
		    print <<END_HTML;
		    <table width=80% align=center>
			<tr><td><p><b>$count.</b> $pub_ref (PMID:$pubmed)</p></td></tr>
			<tr><td><br /></td></tr>
			</table>
END_HTML
		}
	    }
	    print <<END_HTML;
	    <form method="post" action="">
		<input type="submit" name="action" value="Confirm store">
		<input type = "hidden" name="curator_id" value=$curator_id>
		<input type = "hidden" name="publications" value=$pubmed_string>
		</form><br>
		<a href="javascript:history.back(1)">Go back without storing the publications</a> 
END_HTML

	}
	
    }elsif ($action eq 'Confirm store') {

	my $ids = $args{publications};
	my $curator_id = $args{curator_id} ;
	
	my @pubmeds  = split (/\|/, $ids);
	my $count=0;
	print qq | <br/><b> stored the following  publications from PubMed</b><br /> | ;
	print qq| (assigned to curator $curator_id) | ; 
	#chop $ids;
	foreach my $pubmed (@pubmeds) { 
		#$pubmed =~ s/ +//g; 
		my $pub = CXGN::Chado::Publication->new($dbh);
		$count++;
		$pub->set_accession($pubmed);
		$pub->add_dbxref("PMID:$pubmed");
		CXGN::Tools::Pubmed->new($pub); #call eutils and populates the publication object with all necessary fields
		my $pub_ref=$pub->print_pub_ref();
		my $e_id = $pub->get_eid;
		if ($e_id) {
		    $pub->add_dbxref("DOI:$e_id");
		}
		$pub->store();

		unless ($pub->is_curated() ) {
		    $pub->set_sp_person_id($logged_in_person_id);
		    $pub->set_curator_id($curator_id); #
		    $pub->set_status('pending');
		    $pub->store_pub_curator();
		    $pub->d("Assigned publication $pubmed to curator $curator_id");
		}
		print <<END_HTML;
		<table width=80% align=center>
		    <tr><td><p><b>$count.</b> $pub_ref (PMID:$pubmed)</p></td></tr>
		    <tr><td><br /></td></tr>
		    </table>
END_HTML
	    }
	print qq | <a href="/chado/fetch_pubmed.pl">Go back to fetch  publications page </a ><br />|; 
	print qq| <a href= "/search/pub_search.pl?w9b3_status=pending">See publications pending curation</a><br />|;
    } else {
	my @curators= CXGN::People::Person::get_curators($dbh);
	my %names = map {$_ => CXGN::People::Person->new($dbh, $_)->get_first_name() }  @curators;
	my $curator_options=qq|<option value="">--Assign publications to curator--</option>|;
	for my $curator_id (keys %names) {
	    my $curator= $names{$curator_id};
	    $curator_options .=qq|<option value="$curator_id">$curator</option>|;
	}
		
	print <<END_HTML;
	<br/>
        <form method="post" action="fetch_pubmed.pl">
        <table cellpadding="2" cellspacing="2">
        <th colspan="2">Curators may use this form to bulk fetch publications from PubMed.<br />&nbsp;</th>
	<tr><td><textarea id="" cols="20" rows="10" name="pubmed_ids" value ="Insert a list of  PubMed IDs"></textarea></td>
	<td>
	<select id="curator_id" name="curator_id"> $curator_options </select>
	</td></tr>
        <tr><td><input type="submit" name="fetch_pubmeds" value="Store"><input type="reset" value="Reset form" /></td></tr>
        </table>
        <br />
    
END_HTML
    
    }
    $page->footer();
}
else { $page->client_redirect('/user/login'); }



sub confirm_store {

    my $self=shift;
    $self->print_confirm_form();   
}


sub print_confirm_form {
    my $self=shift;
    my %args= $self->get_args();
   
    my $query= sanitize_string($args{query});    
    
}
    

