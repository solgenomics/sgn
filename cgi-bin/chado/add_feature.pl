use strict;

my $add_feature_page = CXGN::Chado::AddFeaturePage->new();

package CXGN::Chado::AddFeaturePage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / info_section_html page_title_html html_optional_show /;
use CXGN::Page::Form::EditableCheckbox;
use CXGN::Chado::Feature;

use CXGN::Phenome::Locus;
use CXGN::Phenome::Allele;

use CXGN::Tools::FeatureFetch;
use CXGN::Tools::Pubmed;
use CXGN::Chado::Organism;
use Bio::Chado::Schema;

use CXGN::Chado::Publication;
use CXGN::Tools::Text qw / sanitize_string /;
use base qw / CXGN::Page::Form::SimpleFormPage /;


sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("add_feature.pl");
    
    #my $schema= CXGN::DB::DBICFactory->open_schema( 'Bio::Chado::Schema') ;

    # $self->set_schema($schema);
    return $self; 
}



sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{feature_id});
    $self->set_object(CXGN::Chado::Feature->new( $self->get_dbh(), $self->get_object_id() )
		      );
    $self->set_primary_key("feature_id");		    
    $self->set_owners();
}

sub store { 
    my $self = shift;
    
    my $feature = $self->get_object();
    my $sp_person_id=$self->get_user()->get_sp_person_id();
    
    my %args = $self->get_args();
    
    my $action=$args{action};
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or allele or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $GBaccession= sanitize_string($args{accession});
    my $checkbox_value = $args{publications_checkbox};
    my $script_name= $self->get_script_name();
    
    my ($locus, $allele);
    
    #retrieve the locus or allele objects based on their type_id
    if ($type eq 'locus') {  $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $type_id); }
    elsif ($type eq 'allele') { $allele= CXGN::Phenome::Allele->new($self->get_dbh(), $type_id); }
    my $dbxref_id;
    my $feature_id;
    
    $feature->set_name($GBaccession);
    
    my $existing_feature = $feature->feature_exists();
    if ($existing_feature) {
	#if the feature is already stored in dbxref, we need its dbxref_id for storing it in the feature_dbxref linking table
	$feature=CXGN::Chado::Feature->new($self->get_dbh(), $existing_feature);
	$dbxref_id= $feature->get_dbxref_id();
    }
    
    #If the feature exists then fetch the dbxref object with that dbxref_id
    my $dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $dbxref_id);
    
    my ($associated_feature, $obsolete);
    if ($type eq 'locus') {
	$associated_feature = $locus->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	$obsolete = $locus->get_locus_dbxref($dbxref)->get_obsolete();
    }
    elsif ($type eq 'allele') {
	$associated_feature= $allele->get_allele_dbxref($dbxref)->get_allele_dbxref_id();
	$obsolete = $allele->get_allele_dbxref($dbxref)->get_obsolete();
    }
    #Fetch the feature from genbank:
    my $db_name = 'DB:GenBank_GI';
    $feature->set_db_name($db_name);
    $feature->set_name($GBaccession);
    CXGN::Tools::FeatureFetch->new($feature);

    #the feature exists in our database but is not associated (checked in confirm_store) with the sequence. Associate the two and then exit the function.
    if ($dbxref_id ) {
	if ($type eq 'locus') {
	    $locus->add_locus_dbxref($dbxref, $associated_feature, $sp_person_id);
	}
	elsif ($type eq 'allele') {
	    $allele->add_allele_dbxref($dbxref, $associated_feature, $sp_person_id);
	}
	#
	#only store the publications if the user specified to do so
	if($checkbox_value eq 'on'){
	    $self->store_publications($feature);
	    #the pubmed_ids aren't stored in the database for features so we need to re-fetch them. There may be a better way to do this. 
	    #CXGN::Tools::FeatureFetch->new($feature);
	    #if ($message) { $self->get_page->message_page($message); }
	    #else { $self->store_publications($feature); }
	}
    }else { # need to fetch the feature and give it a new dbxref_id
	
	my $mol_type= $feature->get_molecule_type();
	#if (!$mol_type) { 
	$feature->set_molecule_type('DNA') ;  #this default value has to be resolved in a better way
	#molecule type in entrez XML does not always follow SO names.
	
	#only store the publications if the user specified to do so
	if($checkbox_value eq 'on'){
	    $self->store_publications($feature);
	}
	$self->SUPER::store(1); #this gives the feature a  dbxref id, and stores it in feature, and featre_dbxref
	
	#instantiate a new dbxref object
	$dbxref_id=$feature->get_dbxref_id();
	$dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $dbxref_id);
        
	#store the new locus_dbxref..
	if ($type eq 'locus') { $locus->add_locus_dbxref($dbxref, undef, $sp_person_id); }
	elsif ($type eq 'allele') { $allele->add_allele_dbxref($dbxref, undef, $sp_person_id); }
	
    }
    
    $self->send_feature_email('store');
    $self->get_page()->client_redirect("$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new");
}

sub delete_dialog { 
    my $self = shift;
    my %args = $self->get_args();
    $self->check_modify_privileges();
 
    my $title = shift;
    my $object_name = shift;
    my $field_name = shift;
    my $object_id = shift;
    

    my $type = $args{type}; 
    my $type_id= $args{type_id}; #the id of the object we want to associate to the feature
    
    my $object_dbxref_id= undef;
    my ($locus,$locus_name, $allele, $allele_name);
    
    if ($args{object_dbxref_id}) { 
	if ($type eq 'locus') {
	    $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $type_id);
	    $locus_name = $locus->get_locus_name();
	    $object_name=$locus_name;
	    print STDERR "!!!*$locus_name $object_name\n";
	}elsif ($type eq 'allele') {
	    $allele = CXGN::Phenome::Allele->new($self->get_dbh(), $type_id);
	    $allele_name = $allele->get_allele_name();
	    $object_name=$allele_name;
	}
	$object_dbxref_id= $args{object_dbxref_id};
    }
    
    my $back_link= qq |<a href="javascript:history.back(1)">Go back without deleting</a> |;
    
    $self->get_page()->header();
    
    
    page_title_html();
    print qq { 	
	<form>
	    Delete the sequence association with $type ($object_name)? 
	    <input type="hidden" name="action" value="delete" />
	    <input type="hidden" name="$field_name" value="$object_id" />	    
	    <input type="hidden" name="type" value="$type" />
	    <input type="hidden" name="type_id" value="$type_id" />
	    <input type="hidden" name="object_dbxref_id" value="$object_dbxref_id" />
	    <input type="hidden" name="refering_page" value="$args{refering_page}" />	
	    <input type="submit" value="Delete" />
	    </form>
	    
	    $back_link
	};
    
    $self->get_page()->footer();		   
 #
}


sub delete { 
    my $self  = shift;
    $self->check_modify_privileges();
    my $script_name= $self->get_script_name();
    my %args= $self->get_args();
    my $type= $args{type};
    my $type_id= $args{type_id};
   
    my $refering_page=$args{refering_page};

    my $feature = $self->get_object();
    
    if ($type eq 'locus') {
 	my $locus_dbxref_obj=CXGN::Phenome::LocusDbxref->new($self->get_dbh, $args{object_dbxref_id});
	$locus_dbxref_obj->obsolete();
    }elsif ($type eq 'allele') {
 	my $allele_dbxref_obj=CXGN::Phenome::AlleleDbxref->new($self->get_dbh, $args{object_dbxref_id});
	$allele_dbxref_obj->delete();
    }else { print qq | <h3> What are you trying to delete here? </h3>| ; exit();}
    
    $self->send_feature_email('delete');
    $self->get_page()->client_redirect("$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new");
}


sub generate_form { 
    my $self = shift;

    my %args = $self->get_args();
    my $feature = $self->get_object();
    my $feature_id = $self->get_object_id();
    
    $self->init_form();

    # generate the form with the appropriate values filled in.
    # if we view, then take the data straight out of the database
    # if we edit, take data from database and override with what's
    # in the submitted form parameters.
    # if we store, only take the form parameters into account.
    # for new, we don't do anything - we present an empty form.
    #
    
    # add form elements
    #
    $self->get_form()->add_field(display_name=>"Enter a Genbank accession: ", 
				 field_name=>"accession", 
				 length=>20, 
				 object=>$feature, 
				 getter=>"get_name", 
				 setter=>"set_name", 
				 validate=>"token"
				 );
    
   
    $self->get_form()->add_hidden( field_name=>"action", contents=>"confirm_store" );
    $self->get_form()->add_hidden( field_name=>"feature_id", contents=>$feature_id );
    
    $self->get_form()->add_hidden( field_name=>"type_id", 
				   contents=>$args{type_id}  );
   
    $self->get_form()->add_hidden( field_name=>"type", 
				   contents=>$args{type}  );

    $self->get_form()->add_hidden( field_name=>"refering_page", 
				   contents=>$args{refering_page}  );

     
    if ($self->get_action()=~/store/i) {
	$self->get_form()->from_request(%args);
    }    
}

=head2 display_page

 Usage:
 Desc: This is the function that actually displays the web page with the included form
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();

    # generate an appropriate edit link
    #
    my $script_name = $self->get_script_name();
    
   
    my @features = ();
    my @obsoleted= ();
    my ($locus, $allele, @dbxref_objs, $object_dbxref_id, $obsolete, $name_dbxref_id); #add vars here if you want this script to work with other object types..
    
    # render the form
    $self->get_page()->header();
    
    print page_title_html( qq { SGN feature upload page } );

    print qq { <b> Features list</b> };

    if ($args{type} eq 'locus') { 
	$locus = CXGN::Phenome::Locus->new($self->get_dbh(), $args{type_id});
	@dbxref_objs= $locus->get_dbxrefs(); #array of dbxref objects
	print "for locus '".$locus->get_locus_name()."'<br /><br />\n";
    
    }elsif ($args{type} eq 'allele') {
	$allele = CXGN::Phenome::Allele->new($self->get_dbh(), $args{type_id});
	@dbxref_objs=$allele->get_all_allele_dbxrefs(); #array of dbxref objects
	print "for allele '".$allele->get_allele_name()."'<br /><br />\n";
    }

    foreach my $dbxref (@dbxref_objs) {

	my $feature= $dbxref->get_feature();
	my $GBaccession= $feature->get_name();
	my $feature_id = $feature->get_feature_id();
	my $accession= $dbxref->get_accession();
	my $description = $dbxref->get_description();
	
	if ($args{type} eq 'locus') { 
	    $object_dbxref_id= $locus->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	    $obsolete= $locus->get_locus_dbxref($dbxref)->get_obsolete();
	}elsif  ($args{type} eq 'allele') {
	    $object_dbxref_id= $allele->get_allele_dbxref($dbxref)->get_allele_dbxref_id();
	    $obsolete= $allele->get_allele_dbxref($dbxref)->get_obsolete();
	}
	
	if ($obsolete eq 'f') {
	    my $genbank_link= "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=nuccore&list_uids=$accession";
	    if ($feature_id && $object_dbxref_id) {print "<a href= $genbank_link target=blank>$GBaccession </a>" . $description . qq { \n <a href="add_feature.pl?feature_id=$feature_id&amp;type=$args{type}&amp;type_id=$args{type_id}&amp;object_dbxref_id=$object_dbxref_id&amp;action=confirm_delete&amp;refering_page=$args{refering_page}">[Remove]</a> <br />\n }; } 
	}elsif ($feature_id)  {
	    push @obsoleted, $feature ; #an array of obsoletes feature objects
	}
    }
    
    if (@obsoleted) { print_obsoleted(@obsoleted) ; }
    
    print qq { <br /><br /><b>Associate a sequence with this $args{type}</b>: };
    print qq { <center> };
    $self->get_form()->as_table();
    print qq { </center> };
    
    if ($args{refering_page}) { print "<a href=\"$args{refering_page}\">[Go back]</a><br /><br />\n"; }
    $self->get_page()->footer();
}


sub print_obsoleted {
    my @features=@_;
    my $obsoleted_features;
    foreach my $feature (@features) {
	my $GBaccession = $feature->get_name();
	my $description = $feature->get_description();
	my $genbank_link= "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=nuccore&list_uids=$GBaccession";
	$obsoleted_features .=  qq |<a href= $genbank_link target=blank> $GBaccession - $description </a>  <br />\n |;
    }
	


    my $print_obsoleted= "<br>" . 
	html_optional_show('obsoleted_features',
			   'Show obsolete',
			   qq|<div class="minorbox">$obsoleted_features</div> |,
			   );
    
    print $print_obsoleted;
    #return $print_obsoleted;
}



sub confirm_store {
    my $self=shift;
    my %args=$self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or allele or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $GBaccession= sanitize_string($args{accession});
    my $feature= $self->get_object();
    
    if ($GBaccession =~ m/^[a-z]/i) { #the accession submitted looks like a GenBank accession
	$feature->set_name($GBaccession);
	print STDERR "****add_feature.pl is setting feature name $GBaccession...\n\n";
    }elsif ($GBaccession=~ m/^\d/) { #the user submitted an accession that looks like a GenBank GI number!
	$self->get_page->message_page("Please type a valid genBank accession !!");
	print STDERR "^^^^add_feature.pl found an accession that looks like a gi number...\n\n";
    } 
    
   
    #$feature->set_name($GBaccession);
    my $feature_id = $feature->get_feature_id();
    my $dbxref_id = $feature->get_dbxref_id();
   
############
    #my $dbxref_id=undef;
   
    $self->get_page()->header();
        
    #need to check if the feature is already in the database and associated with the object (locus..)
    my $existing_feature= $feature->feature_exists($feature->set_name($GBaccession) );
    my ($locus, $allele);
    if ($type eq 'locus') { $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $args{type_id}); }
    elsif ($type eq 'allele') {  $allele=CXGN::Phenome::Allele->new($self->get_dbh(), $args{type_id}); }
    
    if ($existing_feature) {
	
	#this feature exists, now we need to check if it's associated with the refering object
	$feature=CXGN::Chado::Feature->new($self->get_dbh(), $existing_feature);
	my @temp_pubmeds = $feature->get_pubmed_ids();
	$dbxref_id= $feature->get_dbxref_id();
	
        ##dbxref object...
	my $dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $dbxref_id);
	my ($associated_feature, $obsolete);
	if ($type eq 'locus') {
	    $associated_feature= $locus->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	    $obsolete = $locus->get_locus_dbxref($dbxref)->get_obsolete();
	}elsif ($type eq 'allele' ) {
	    $associated_feature= $allele->get_allele_dbxref($dbxref)->get_allele_dbxref_id();
	    $obsolete = $allele->get_allele_dbxref($dbxref)->get_obsolete();  
	}
	print STDERR "$type _ dbxref obsolete = '$obsolete' !!!!!\n";
	if  ($associated_feature && $obsolete eq 'f') {
	    print  "<h3>Sequence '$GBaccession' is already associated with $args{type}  $args{type_id} </h3>";
	    print qq { <a href="javascript:history.back(1)">back to features</a> };
	    $self->get_page()->footer();		   
	    
	}else{  ##the feature exists but not associated with the object
	    print STDERR "*add_feature.pl: confirm_store...calling print_confirm_form (feature exists but not associated)\n";

	    $self->print_confirm_form(); 
	   
	}
    } else { # the feature doesn't exist in our database
	print STDERR "*add_feature.pl: confirm_store...calling print_confirm_form (feature does not exist in db)\n";
	
	$self->print_confirm_form();
			
    }

}


=head2 print_confirm_form

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub print_confirm_form {
    my $self=shift;
    my %args= $self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $GBaccession= sanitize_string($args{accession});
    my $user_type = $self->get_user()->get_user_type();
    my $script_name= $self->get_script_name();
    
    my $feature = $self->get_object();
        
############
    my $dbxref_id=undef;
    
    #first fetch the sequence from genbank:
    $feature->set_name($GBaccession);
    CXGN::Tools::FeatureFetch->new($feature);
    
    my $feature_seqlen=$feature->get_seqlen();
    #add genbank verification step	
    if ($feature->get_message() ) { $self->get_page->message_page("FeatureFetch.pm returned message: " . $feature->get_message()); }
    if ( !$feature_seqlen ) {
	print  qq |<h3> $GBaccession is not a valid GenBank accession. </h3>  |;
	print  qq |<a href="$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new">Go back</a>|;
	$self->get_page()->footer();		   
	exit(0);
    }

    #check to see if the sequence has a valid organism (one that is already in our database)
       
    my $organism = CXGN::Chado::Organism->new_with_taxon_id($self->get_dbh(), $feature->get_organism_taxon_id() );
    
    if( !$organism->get_organism_id() ){
	my $organism_name = $feature->get_organism_name();
	print  qq |<h3> The requested sequence ($GBaccession) corresponds to an unsubmittable organism: $organism_name. If you think this organism should be submittable please contact <a href="mailto:sgn-feedback\@sgn.cornell.edu">sgn-feedback\@sgn.cornell.edu</a></h3>  |;
	print qq |<a href="$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new">Go back</a><br />|;
	
	$self->get_page()->footer();		   
	exit(0);
    }
    
############
    my $print_feature =$feature->get_name();#"";
    #my @names = $feature->get_names();
    ##The first element in the accessions, or "names" under the chado schema, is the nucleotide accession we are interested in.
    #my $primary_name = $names[0];
    $print_feature .=  ".".$feature->get_version() . " - " . $feature->get_description();
        
    my @print_publications=undef;
    

    my @pubmed_ids=undef;
    @pubmed_ids = $feature->get_pubmed_ids();
    print STDERR "****pubmed_ids in print_confirm_form are: @pubmed_ids \n";
    my $first_pubmed_id = $pubmed_ids[0]; #don't set print_publication to anything if theres no publications to store
    my $pubmed_link="";

    my $is_associated = undef;
    my $show_checkbox = undef;
    
    my $locus=CXGN::Phenome::Locus->new($self->get_dbh(), $type_id);
       
    my $print_associations;

    my @loci_feature=$feature->associated_loci();
    if (@loci_feature) {$print_associations .= "this sequence is already associated with locus:"; }

    foreach my $l(@loci_feature) { 
	my $l_id= $l->get_locus_id();
	my $l_name=$l->get_locus_name();
	$print_associations .= qq | <a href= "../phenome/locus_display.pl?locus_id=$l_id">$l_name</a> |;
    }
    
    foreach my $pubmed_id (@pubmed_ids){
	my $print_publication = undef;
	#don't show the publications if they are already associated with this object (locus or allele)
	$is_associated= $locus->associated_publication($pubmed_id);
	my $pub_obj=CXGN::Chado::Publication->new($self->get_dbh());
	my $publication= $pub_obj->get_pub_by_accession($self->get_dbh(), $pubmed_id) ;
	if ($publication && !$is_associated) {
	    my @associated_with_loci = $publication->get_loci();
	    if (@associated_with_loci) {
		$print_associations .= "<br> this publication is already associated with locus: ";
		foreach my $a(@associated_with_loci) {
		    my $a_locus_id= $a->get_locus_id;
		    my $a_locus_name=$a->get_locus_name;
		    $print_associations .= qq | <a href= "/phenome/locus_display.pl?locus_id=$a_locus_id">$a_locus_name</a> |;
		}
	    }
	}
	#########
	if(!$is_associated){
	    $show_checkbox = "yes";
	    my $publication = CXGN::Chado::Publication->new($feature->get_dbh());
	    $publication->set_accession($pubmed_id);
	    $publication->add_dbxref("PMID:$pubmed_id");
	    CXGN::Tools::Pubmed->new($publication);
	    
	    $pubmed_link= "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&list_uids=$pubmed_id";
	    $print_publication .= "<a href= $pubmed_link target=blank>PMID: $pubmed_id </a>";
	    
	    my @authors= $publication->get_authors();
	    foreach my $a (@authors) {
		$print_publication .=$a .", ";
	    }
	    
	    chop $print_publication;
	    chop $print_publication;

	    $print_publication .= ". (" . $publication->get_pyear() . ") " . $publication->get_title() . " " . $publication->get_series_name(). " (" . $publication->get_volume() . "):" . $publication->get_pages() . ". <br><br>";
	    push(@print_publications, $print_publication);
	}
    }

    print qq | <br/> <h3>The following sequence will be stored in the database and associated with $args{type}  $args{type_id}: </h3> $print_feature|;
    if (@print_publications) { 
	print qq|<br><br><b>Publications related to this sequence:</b><br><br>@print_publications|;
    }

    print qq | <b> $print_associations </b> |;

    $self->init_form();

    if ($show_checkbox eq "yes"){ #don't display the checkbox if theres no publications to store
	$self->get_form()->add_checkbox( field_name=>"publications_checkbox",
					 display_name=>"<b>Check here to also associate and store the above publication(s)</b>",
					 object=>$self, 
					 getter=>"get_checkbox_value", 
					 setter=>"set_checkbox_value");
    }

    $self->get_form()->add_hidden( field_name=>"accession", contents=>$GBaccession );
    $self->get_form()->add_hidden( field_name=>"type", contents=>$args{type} );
    $self->get_form()->add_hidden( field_name=>"type_id", contents=>$args{type_id} );
    $self->get_form()->add_hidden( field_name=>"refering_page", contents=>$args{refering_page} );
    
    
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    
    page_title_html("Confirm store");
    
    print qq { <center><br> };
    
    $self->get_form()->as_table();
    
    print qq { </center> };
    
    if ($self->get_action()=~/store/i) {
	$self->get_form()->from_request(%args);
    }
    print qq | <BR> <a href="javascript:history.back(1)">Go back without storing the sequence</a> | ;
    
    $self->get_page()->footer();
    
}

sub store_publications {
    my $self = shift;
    my $feature = shift;

    my $sp_person_id=$self->get_user()->get_sp_person_id();
    
    my %args = $self->get_args();
    
    my $type= $args{type};  #locus or allele or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)

    my ($locus, $allele);
    
    ##retrieve the locus or allele objects based on their type_id
    if ($type eq 'locus') {  $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $type_id); }
    elsif ($type eq 'allele') { $allele= CXGN::Phenome::Allele->new($self->get_dbh(), $type_id); }

    ##store the publications associated with the feature
    my @pubmed_ids = $feature->get_pubmed_ids();
    if(@pubmed_ids) {
	print STDERR "***the pubmeds array exists and has the following values: @pubmed_ids";
	foreach my $pubmed_id (@pubmed_ids){
	    my $publication = CXGN::Chado::Publication->new($feature->get_dbh()); 
	    $publication->set_accession($pubmed_id);
	    $publication->add_dbxref("PMID:$pubmed_id");
	    CXGN::Tools::Pubmed->new($publication);
	    my $existing_publication = $publication->get_pub_by_accession($self->get_dbh(),$pubmed_id);
	    if(!($existing_publication->get_pub_id)) { #publication does not exist in our database
		
		print STDERR "storing publication now. pubmed id = $pubmed_id";
		my $pub_id = $publication->store();
		my $publication_dbxref_id = $publication->get_dbxref_id_by_db('PMID');
		my $publication_dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $publication_dbxref_id);

		if ($type eq 'locus') {
		    $locus->add_locus_dbxref($publication_dbxref, undef, $sp_person_id);
		}
		elsif ($type eq 'allele'){
		    $allele->add_allele_dbxref($publication_dbxref, undef, $sp_person_id);
		}
	    }
	    else { #publication exists but is not associated with the object
		print STDERR "***the publication exists but is not associated.";
		$publication=CXGN::Chado::Publication->new($self->get_dbh(), $existing_publication->get_pub_id());
		if (!($publication->is_associated_publication($type, $type_id))) {
		    my $publication_dbxref_id= $publication->get_dbxref_id_by_db('PMID');
		    my $publication_dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $publication_dbxref_id);

		    my ($associated_feature, $obsolete);
		    if ($type eq 'locus') {
			$associated_feature = $locus->get_locus_dbxref($publication_dbxref)->get_object_dbxref_id();
			$obsolete = $locus->get_locus_dbxref($publication_dbxref)->get_obsolete();
		    }
		    elsif ($type eq 'allele') {
			$associated_feature= $allele->get_allele_dbxref($publication_dbxref)->get_allele_dbxref_id();
			$obsolete = $allele->get_allele_dbxref($publication_dbxref)->get_obsolete();
		    }

		    if ($publication_dbxref_id ) {
			if ($type eq 'locus') {$locus->add_locus_dbxref($publication_dbxref, $associated_feature, $sp_person_id);}
			elsif ($type eq 'allele') { $allele->add_allele_dbxref($publication_dbxref, $associated_feature, $sp_person_id);}
			print STDERR  "associating publication now.";
		    }
		}
	    }
	}
    }
}

=head2 get_checkbox_value

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub get_checkbox_value {
  my $self=shift;
  return $self->{checkbox_value};

}

=head2 set_checkbox_value

 Usage:
 Desc:
 Ret:
 Args:
 Side Effects:
 Example:

=cut

sub set_checkbox_value {
  my $self=shift;
  $self->{checkbox_value}=shift;
}

sub init_form {
    my $self = shift;
    
    if ($self->get_action() =~/edit|^store|new/) { 
	$self->set_form( CXGN::Page::Form::Editable-> new() );
	
    }elsif ($self->get_action() =~/confirm_store/) {
	$self->set_form( CXGN::Page::Form::Editable->new() ) ; 
	
    }else  {
	$self->set_form( CXGN::Page::Form::Static -> new() );
    }
    
}

sub send_feature_email {
    my $self=shift;
    my $dbh= $self->get_dbh();
    my %args=$self->get_args();
    my $action=$args{action};
    my $locus_id=$args{type_id};
    my $locus=$args{type};
    my $GBaccession=sanitize_string($args{accession});
    my $feature_id_del = $args{feature_id};
    my $acc_obj = CXGN::Chado::Feature->new_with_accession($dbh, $GBaccession);
    my $accession;
    
    my $subject="[A Genbank accession is associated or obsoleted] locus $locus_id";
    my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
    my $sp_person_id=$self->get_user()->get_sp_person_id();

    my $locus_link= qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    
    my $usermail=$self->get_user()->get_private_email();
    my $fdbk_body;
    
    if ($action eq 'delete') {
	my $del_acc = CXGN::Chado::Feature->new($dbh, $feature_id_del);
	$accession .= $del_acc->get_accession_by_feature_id($GBaccession, $feature_id_del);
	my $genbank_deleted= "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=nuccore&list_uids=$accession";
	$fdbk_body="$username ($user_link) has dissociated GenBank accession: $genbank_deleted from  ($locus_link) \n"; }
   
    else {
	$accession .= $acc_obj->get_accession_by_feature_id($GBaccession);
	my $genbank_added= "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=nuccore&list_uids=$accession";
	$fdbk_body="$username ($user_link) has associated GenBank accession: $genbank_added to locus ($locus_link) \n"; }
    
    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
}

