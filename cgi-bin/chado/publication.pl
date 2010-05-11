
my $publication_detail_page=CXGN::Chado::PublicationDetailPage->new();

package CXGN::Chado::PublicationDetailPage;

use base qw/CXGN::Page::Form::SimpleFormPage/;

use strict;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw/info_section_html
                                     page_title_html
                                     columnar_table_html
                                     info_table_html
                                     html_optional_show
                                     tooltipped_text
                                   /;
use CXGN::People::Person;
use CXGN::Chado::Publication;
use CXGN::Chado::Pubauthor;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Locus::LocusRanking;
use CXGN::Phenome::Allele;
use CXGN::Chado::Dbxref;
use CXGN::Contact;
use CXGN::People::PageComment;
use CXGN::Tools::Text qw / sanitize_string /;
sub new {
    my $class=shift;
    my $self= $class->SUPER::new(@_);
    $self->set_script_name("publication.pl");
    return $self;
}


sub define_object {
    my $self=shift;
    $self->set_dbh(CXGN::DB::Connection->new() );
    my %args= $self->get_args();
    foreach my $k (keys %args) {
	$args{$k} = sanitize_string($args{$k});
    }
    my $pub_id= $args{pub_id};
    
    unless (!$pub_id || $pub_id =~m /^\d+$/) { $self->get_page->message_page("No publication exists for identifier: $pub_id"); }
    $self->set_object_id($pub_id);
    $self->set_object(CXGN::Chado::Publication->new($self->get_dbh, $self->get_object_id));
    
    $self->set_primary_key("pub_id");
    $self->set_owners();
}


sub display_page {
    my $self=shift;
    my %args = $self->get_args();
    my $publication=$self->get_object();
    my $pub_id = $self->get_object_id();
    my $pub_title = $publication->get_title();
    my $page="/chado/publication.pl?pub_id=?";
    my $action= $args{action} || "";
    if (!$pub_title && $action ne 'new' && $action ne  'store') { $self->get_page->message_page("No publication exists for this identifier");}
    #import javascript libraries    
    $self->get_page()->jsan_use("CXGN.Phenome.Locus");
    $self->get_page()->jsan_use("Prototype");
    $self->get_page()->jsan_use("CXGN.Phenome.Publication");
    
    $self->get_page->header("SGN publication $pub_title");
    print page_title_html("Publication:\t$pub_title\n");
    
    my $edit_links=$self->get_edit_links();
    
    my $pub_html=$edit_links. "<br />". $self->get_form->as_table_string(). "<br />";
    if ($action eq 'new') { print qq |<p><b><a href = "/chado/add_publication.pl?action=new&amp;type=$args{type}&amp;type_id=$args{type_id}&amp;reffering_page=$args{reffering_page}">Store PubMed publication.</a></b></p>|; }
    print info_section_html(title    => 'Publication details',
                            contents => $pub_html ,
			    );
    if ($args{refering_page}) { print qq |<a href="$args{refering_page}">Go back to refering page.</a><br />|; }
    
    my $dbxref_html=$self->get_dbxref_html($publication->get_dbxrefs());
    
    print info_section_html(title    => 'External resources',
                            contents => $dbxref_html ,
			    );
    my $loci_link;
    my @loci= $publication->get_loci();
    foreach my $locus(@loci)  {
	my $locus_id = $locus->get_locus_id();
	my $locus_symbol= $locus->get_locus_symbol();
	my $cname=$locus->get_common_name();
	$loci_link .= qq|<a href="/phenome/locus_display.pl?locus_id=$locus_id">$cname '$locus_symbol'</a><br />| if $locus->get_obsolete() eq 'f';
    }
    print info_section_html(title    => 'Associated loci',
			    contents => $loci_link ,
			    );
    my $user_type= $self->get_user()->get_user_type();
    if ($args{get_ranked_loci} && $user_type eq 'curator' ) { $self->rank_loci_now(); }
    
    my $ranked_loci= $self->get_ranked_loci();
    print info_section_html(title    => 'Matched loci',
			    contents => $ranked_loci ,
			    collapsible=>1,
			    collapsed =>1,
			    );
    ########
    if ($user_type eq 'curator') {
	# the text-indexing function does not do the right thing now
	# have to modify it so the search will be against just the current  publication
        print info_section_html(title    => 'Curator Tools',
				contents => $self->get_curator_tools(),
				);
    }
    #######
    my $page_comment_obj = CXGN::People::PageComment->new($self->get_dbh(), "pub", $pub_id, $self->get_page()->{request}->uri()."?".$self->get_page()->{request}->args()); 
    print $page_comment_obj->get_html();
    
    $self->get_page()->footer();
}

sub store { 

    my $self = shift;
    
    my $publication = $self->get_object();
    my $sp_person_id=$self->get_user()->get_sp_person_id();
    
    my %args = $self->get_args();
      
    my $action=$args{action};
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or allele or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
   
    my $script_name= $self->get_script_name();    
    my $db_name= "SGN_ref";
    
    #db_name, accession, and uniquename will not be changed when updating..
    if (!$publication->get_db_name()) {  $publication->set_db_name($db_name); }
    print STDERR "adding db_name " . $publication->get_db_name() . "!!\n\n";
    print STDERR "adding dbxref full_accession " .  "$db_name:" . $publication->get_title() . " (" .$publication->get_pyear() .")\n\n";
    
    #########
    $publication->set_cvterm_name('journal'); #this should be implemented in the form framework- maybe a drop down list with publication types from cvterm table??
    ########
    
    $self->SUPER::store(1);
    
    #my $dbxref_id= $publication->get_dbxref_id_by_db($db_name);
    #my $dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $dbxref_id);
    my @dbxrefs=$publication->get_dbxrefs();
    foreach my $dbxref(@dbxrefs) {
	my ($locus, $allele);
	if ($type eq 'locus') {  
	    $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $type_id); 
	    $locus->add_locus_dbxref($dbxref, undef, $sp_person_id);
	}
	elsif ($type eq 'allele') { 
	    $allele= CXGN::Phenome::Allele->new($self->get_dbh(), $type_id);
	    $allele->add_allele_dbxref($dbxref, undef, $sp_person_id);
	}
    }
    my $pub_id= $publication->get_pub_id();
    if ($refering_page) {
	$self->get_page()->client_redirect("/chado/add_publication.pl?type=$type&type_id=$type_id&refering_page=$refering_page&action=new");
    }else {
	$self->get_page()->client_redirect("/chado/publication.pl?pub_id=$pub_id");
    }
}

sub generate_form {
    my $self=shift;
    $self->init_form();
    my $publication=$self->get_object();

    my %args=$self->get_args();
    my $type = $args{type};
    my $type_id = $args{type_id};
    my $refering_page= $args{refering_page};
    
   my $author_example = tooltipped_text('Authors', 'Author names should be entered in the order of  last name, followed by "," then first name followed by ".". e.g Darwin, Charles. van Rijn, Henk. Giorgio,AB'); 

    $self->get_form()->add_textarea(
                                 display_name => "Title",
                                 field_name  => "title",
                                 object => $publication,
                                 getter => "get_title",
                                 setter => "set_title",
				 validate=>'string',
				 columns => 80,
				 rows => 1,
			      );
   
    $self->get_form()->add_field(
                                 display_name => "Series name",
                                 field_name  => "series_name",
                                 object => $publication,
                                 getter => "get_series_name",
                                 setter => "set_series_name",
                                 validate=>'string',
				 );
    $self->get_form()->add_field(
                                 display_name => "Volume",
                                 field_name  => "volume",
                                 object => $publication,
                                 getter => "get_volume",
                                 setter => "set_volume",
                                 validate=>'integer',
				 );
    $self->get_form()->add_field(
                                 display_name => "Issue",
                                 field_name  => "issue",
                                 object => $publication,
                                 getter => "get_issue",
                                 setter => "set_issue",
				 );
    
    $self->get_form()->add_field (
				  display_name => "Year",
				  field_name  => "pyear",
				  object => $publication,
				  getter => "get_pyear",
				  setter => "set_pyear",
				  validate => 'integer',
				  );
    $self->get_form()->add_field (
				  display_name => "Pages",
				  field_name  => "pages",
				  object => $publication,
				  getter => "get_pages",
				  setter => "set_pages",
				  validate => 'string',
				  );				     
    
    $self->get_form()->add_textarea (   
					display_name=> $author_example,
					field_name => "author",
					object => $publication,
					getter => "get_authors_as_string",
					setter => "set_author_string",
					columns => 80,
					rows =>1,
					
					);
    $self->get_form()->add_textarea (
				     display_name=> "Abstract",
				     field_name => "abstract",
				     object => $publication,
				     getter => "get_abstract",
				     setter => "set_abstract",
				     columns => 80,
				     rows => =>12,
				     );
    
    
    $self->get_form()->add_hidden (
                                   field_name => "pub_id",
				   contents   =>$args{pub_id},
				   object => $publication,
				   getter => "get_pub_id",
				   setter => "set_pub_id",
				   );			

    $self->get_form()->add_hidden (
                                   field_name => "type",
				   contents   => $type,
			           
				   );
    
    $self->get_form()->add_hidden (
                                   field_name => "type_id",
				   contents   =>$type_id,
				   );                            
    $self->get_form()->add_hidden( 
				   field_name=>"refering_page", 
				   contents=>$refering_page,
				   );				  
    
    
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    
    if ($self->get_action=~ /view|edit/) {
	$self->get_form->from_database();
    }
    elsif ($self->get_action=~ /store/) {
        $self->get_form->from_request($self->get_args());
	$self->send_publication_email('store');
    }
}

sub delete { 
    my $self = shift;
    my %args = $self->get_args();
    $self->check_modify_privileges();
    my $publication=$self->get_object();
    my $pub_title;
    my $pub_id = $publication->get_pub_id();
    if ($pub_id) { 
	$pub_title = $publication->get_title();
	my $message = $publication->delete();
	if (!$message) { 
	    $self->send_publication_email('delete');
	}else { $self->get_page()->message_page($message) ; }
    }
    
    $self->get_page()->message_page("Deleted publication $pub_id ($pub_title) from database");
}




#overriding to allow access only to curators
sub check_modify_privileges { 
    my $self = shift;
    
    # implement quite strict access controls by default
    # 
    my $person_id = $self->get_login()->verify_session();
    my $user =  CXGN::People::Person->new($self->get_dbh(), $person_id);
    my $user_id = $user->get_sp_person_id();
    if ($user->get_user_type() eq 'curator' || $user->get_user_type() eq 'submitter' || $user->get_user_type eq 'sequencer') {
        return 0;
    }else {
	$self->get_page()->message_page("This page is only available for SGN curators!!");
    }
}

sub get_dbxref_html {
    my $self=shift;
    my @dbxrefs=@_;
    my $html;
    foreach my $d(@dbxrefs) {
	my $db=$d->get_db_name();
	if ($db  ne 'SGN_ref') { 
	    my $url = $d->get_urlprefix() . $d->get_url() . $d->get_accession();
	    $html .=  qq| <a href= "$url" >| . "$db:" . $d->get_accession() . "</a>";
	}
    }
    return $html;
}

sub get_ranked_loci {
    my $self=shift;
    my $pub=$self->get_object();
    my $loci_hash=$pub->get_ranked_loci();
    my $pubs="";
    my ($val_pubs, $rej_pubs, $pending_pubs, $a_pubs)= ("" x 4);
    my $locus_link;
    my @pub;
    my $user_type= $self->get_user()->get_user_type();
 
    foreach(sort  { $loci_hash->{$b} <=>  $loci_hash->{$a} } keys %$loci_hash )  {
	my $locus=CXGN::Phenome::Locus->new($self->get_dbh, $_);
	my $locus_symbol= $locus->get_locus_symbol();
	my $locus_name= $locus->get_locus_name();
	my $common_name= $locus->get_common_name();
	my $pub_id = $pub->get_pub_id(); 
	my $dbxref_id = $pub->get_dbxref_id_by_db('PMID');
	
	my $locusRank = CXGN::Phenome::Locus::LocusRanking->new($self->get_dbh(), $_, $pub_id);
	my $validated = $locusRank->get_validate() || "";
	my $score = $locusRank->get_rank();
	
	my $val_form= "<BR><BR>";
	if ($user_type eq 'curator') {
	    $val_form= qq|
	      <div id='locusPubForm_$pub_id'>
	      <div id='pub_dbxref_id_$dbxref_id'>
	      <input type="hidden" 
		value=$dbxref_id
		id="dbxref_id_$pub_id">
	      <select id="$dbxref_id"  >
		<option value="" selected></option>
		<option value="no">no</option>
		<option value="yes">yes</option>
		<option value="maybe">maybe</option>
	      </select>
	     <input type="button"
		id="associate_pub_button"
		value="Validate match"
		onclick="Locus.addLocusDbxref('$_', '$dbxref_id');this.disabled=false;">
	     </div>
	     </div>
	     <BR>
	   |;
	}
	my $associated= $pub->is_associated_publication('locus', $_);
	my $val_string; 
	if ($validated) { $val_string = "(validated: $validated)"; }
	$locus_link .=  qq| <a href="/phenome/locus_display.pl?locus_id=$_">$locus_symbol.</a> $common_name '$locus_name' <b> Match score = $score </b> $val_string | . $val_form;
	
    }
    return $locus_link;
}


    
sub send_publication_email {

    my $self=shift;
    my %args= $self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $accession= $args{accession};
   
    
    my $action= $self->get_action();
    my $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $type_id);
    my $locus_id=$locus->get_locus_id();
    my $name= $locus->get_locus_name();
    my $symbol= $locus->get_locus_symbol();
    
    
    my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
    my $sp_person_id=$self->get_user()->get_sp_person_id();

    my $locus_link= qq | http://sgn.cornell.edu/phenome/locus_display.pl?locus_id=$type_id|;
    my $user_link = qq | http://sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
   
    my $usermail=$self->get_user()->get_contact_email();
    my $fdbk_body;
    my $subject;
   
    
if ($action eq 'store') {

        $subject="[New non PubMed  publication associated with locus: $locus_id]";
	$fdbk_body="$username($user_link) has associated a non pubmed publication $accession with locus:$locus_id"; 
   }
    elsif($action eq 'delete') {
	$subject="[A publication-locus association removed from locus: $locus_id]";
	$fdbk_body="$username ($user_link) has removed a publication from locus: $locus_id ($locus_link)"; 
    }
    
    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
}


sub get_edit_links {
    my $self =shift;
    my $form_name = shift;
    return $self->get_new_link_html($form_name)." ".
	$self->get_edit_link_html($form_name) ." ". $self->get_delete_link_html($form_name);

}

sub get_edit_link_html {
    my $self = shift;
    my $form_name = shift;
    my $edit_link = "";
    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();
    
    my $user_id= $self->get_user()->get_sp_person_id();
    if (($self->get_user()->get_user_type() eq "curator") || ($self->get_user()->get_user_type() eq "submitter") || ( $self->get_user()->get_user_type() eq "sequencer") ) {
	$edit_link = qq { <a href="$script_name?action=edit&amp;form=$form_name&amp;$primary_key=$object_id">[Edit]</a> };
	
    }else {
	$edit_link = qq { <span class="ghosted">[Edit]</span> };
    }
    if ($self->get_action() eq "edit") { 
	$edit_link = qq { <a href="$script_name?action=view&amp;form=$form_name&amp;$primary_key=$object_id">[Cancel Edit]</a> };
    }
    if ($self->get_action() eq "new") { 
	$edit_link = qq { <span class="ghosted">[Edit]</span> };
    }
    return $edit_link;
}

sub get_delete_link_html {
    my $self = shift;
    my $form_name = shift;
    my $delete_link = "";
    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();
    my $user_id= $self->get_user()->get_sp_person_id();
    if (($self->get_user()->get_user_type() eq "curator") || ($self->get_user()->get_user_type() eq "submitter") || ( $self->get_user()->get_user_type() eq "sequencer") ) {
   	$delete_link = qq { <a href="$script_name?action=confirm_delete&amp;form=$form_name&amp;$primary_key=$object_id">[Delete]</a> };
    }else {
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
    }
    if ($self->get_action() eq "edit") { 
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
    }
    if ($self->get_action() eq "new") { 
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
    }
    return $delete_link;
}



sub get_curator_tools {
    my $self=shift;
    my $pub_id= $self->get_object_id();
    

#add AJAX form for validating publication status. Current status is selected by default
    my $stat=$self->get_object()->get_status();
    my @stat_options= ("curated","pending", "irrelevant", "no gene");
    my $stat_options= qq|<option value=""></option>|;
    foreach my $s(@stat_options) { 
	my $selected = qq|selected="selected"| if $s eq $stat || undef;
	$stat_options .= qq|<option value="$s" $selected >$s</option>| 
    }
    my $stats=  qq|<select id="pub_stat" onchange="Publication.updatePubCuratorStat(this.value, $pub_id)">
                    $stat_options
                    </select> 
                   |;
    #add AJAX form for assigning curator. Assigned curator is selected by default
    my $assigned_to_id= $self->get_object()->get_curator_id();
    my @curators= CXGN::People::Person::get_curators($self->get_dbh());
    my %names = map {$_ => CXGN::People::Person->new($self->get_dbh(), $_)->get_first_name() }  @curators;
    my $curator_options=qq|<option value=""></option>|;
    for my $curator_id (keys %names) {
	my $curator= $names{$curator_id};
	my $selected = qq|selected="selected"| if $curator_id==$assigned_to_id || undef;
	$curator_options .=qq|<option value="$curator_id" $selected>$curator</option>|;
    }
    my $curators=qq|<select id="pub_curator_select" onchange="Publication.updatePubCuratorAssigned(this.value, $pub_id)">
                     $curator_options
                     </select>
                    | ; 
    

    my $form = qq |
	<form action="" method="get">
	<input id="" type="hidden" value="1" name="get_ranked_loci"/>
	<input id="" type="hidden" value="$pub_id" name="pub_id"/>
	
        <input type="submit" value="Get ranked loci"/>
	</form>
	
	|;
    my $html = <<EOHTML;
    Publications are automatically indexed when inserted into the database. A nightly cron job connects publications with loci based on text matching. You may run the matching algorithm manually to see now the possible matching loci. This might take a few minutes to load. After clicking this link the page will automatically reload. If matching loci are found these will be printed in the 'Matched loci' section above.
	$form
	
EOHTML

    my $search = qq|Go back to <a href="/search/pub_search.pl">literature search page</a>.|;
    return info_table_html('Publication status'=>$stats, 
			   'Assigned to curator'=> $curators , 
			   'Text index'=> $html)
	. $search;
}


sub rank_loci_now {
    my $self=shift;
    my $pub=$self->get_object();
    my $pub_id= $self->get_object_id();
    my $title_string= $pub->title_tsvector_string();
    $title_string =~ s/\'//g; 
   
    print STDERR "title_string = $title_string ! \n";
    my @match_words = split (/\s/, $title_string);
    #print STDERR "match_words= @match_words\n";
    my $abstract_string= $pub->abstract_tsvector_string();
    $abstract_string =~ s/\'//g; 
    push (@match_words, (split /\s/, $abstract_string) );

    #hash for storing unique loci. 
    my %loci_subset=();
    MATCH: foreach (@match_words) {
	$_= "%$_%";
	print STDERR "...matching $_ ...\n";
	my $get_loci_q= ("SELECT distinct locus_id FROM phenome.locus WHERE locus_name SIMILAR TO ?
                      OR  locus_symbol SIMILAR TO ? OR gene_activity SIMILAR TO ? OR description SIMILAR TO ?  
                      ORDER BY  locus_id");
	my $l_sth=$self->get_dbh()->prepare($get_loci_q);
	$l_sth->execute($_, $_, $_, $_);
	my (@loci)=$l_sth->fetchrow_array();
	
	##limiting the number of hits to 20 to keep this function from extremely slowing down the page.
	if (scalar(@loci) > 20 ) { print STDERR " Found ". scalar(@loci) . "loci! skipping...\n"; next MATCH; }
     	else {  foreach(@loci) { $loci_subset{$_}++; } }
    }
    foreach my $locus_id (sort {$loci_subset{$a} <=> $loci_subset{$b} } keys %loci_subset) {
	my $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $locus_id);
	eval {
	    my %pub= $locus->add_locus_pub_rank($pub_id);
	    #while ( my ($match_type, $value) = each(%pub) ) {
	    #    print STDERR ("$match_type=> $value\n");
	    #}
	};
    }
}
