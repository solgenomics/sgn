
use strict;

my $add_publication_page = CXGN::Chado::AddPublicationPage->new();

package CXGN::Chado::AddPublicationPage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / info_section_html page_title_html html_optional_show/;
use CXGN::Chado::Publication;
use CXGN::Phenome::Locus;
use CXGN::Phenome::Allele;

use CXGN::People;
use CXGN::Contact;
use CXGN::Tools::Pubmed;
use CXGN::Tools::Text qw / sanitize_string /;
use Bio::Chado::Schema;
use CXGN::Chado::Stock;
use CatalystX::GlobalContext qw( $c );

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("add_publication.pl");
    return $self; 
}
 

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{pub_id});
    $self->set_object(CXGN::Chado::Publication->new( $self->get_dbh(), $self->get_object_id() )
		      );
    $self->set_primary_key("pub_id");		      
#    $self->set_object_owner($self->get_object()->get_sp_person_id); #publications do not have owners, but object_dbxref linking tables do!

    $self->set_owners( ());
    $self->set_schema($c->dbic_schema('Bio::Chado::Schema', 'sgn_chado') );
}

# override store to check if a publication with the submitted ID (pubmed accession?) already exists

sub store { 
    my $self = shift;
    
    my $publication = $self->get_object();
    my $sp_person_id=$self->get_user()->get_sp_person_id();
    
    my %args = $self->get_args();
    
   
    my $action=$args{action};
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or allele or stock...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $accession= sanitize_string($args{accession});
    my $script_name= $self->get_script_name();

    my ($locus, $allele, $pop, $ind, $stock);

    if ($type eq 'locus') {  $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $type_id); }
    elsif ($type eq 'allele') { $allele= CXGN::Phenome::Allele->new($self->get_dbh(), $type_id); }
    elsif ($type eq 'stock') { $stock= CXGN::Chado::Stock->new($self->get_schema(), $type_id); }

    my $pub_id;
    my $dbxref_id=undef;
    my $existing_publication= CXGN::Chado::Publication->get_pub_by_accession($self->get_dbh(),$accession );
    if ($pub_id = $existing_publication->get_pub_id) {
	#if the publication is already stored in dbxref, we need it's dbxref_id for storing it in the object_dbxref linking table
        $publication=CXGN::Chado::Publication->new($self->get_dbh(), $pub_id);
	$dbxref_id= $publication->get_dbxref_id_by_db('PMID');
    }
    $publication->set_accession($accession);
    $publication->add_dbxref("PMID:$accession");
    
    #dbxref object...
    my $dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $dbxref_id);

    #now check if the publication exists and associated and if it has been obsoleted..
    my ($associated_publication, $obsolete);
    #for stocks
    my $stock_pub;
    if ($type eq 'locus') {
	$associated_publication= $locus->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	$obsolete = $locus->get_locus_dbxref($dbxref)->get_obsolete();
    }elsif ($type eq 'allele') {
	$associated_publication= $allele->get_allele_dbxref($dbxref)->get_allele_dbxref_id();
	$obsolete = $allele->get_allele_dbxref($dbxref)->get_obsolete();
    }
#	##the publication exists but not associated with the object
    if ($dbxref_id ) {
	if ($type eq 'locus') {$locus->add_locus_dbxref($dbxref, $associated_publication, $sp_person_id); }
	elsif ($type eq 'allele') { $allele->add_allele_dbxref($dbxref, $associated_publication, $sp_person_id);}
        elsif ($type eq 'stock') { $stock->get_object_row->find_or_create_related('stock_pubs' , {
            pub_id => $pub_id } );
        }
	$self->send_publication_email();
	if (!$type && !$type_id) {
	    $self->get_page()->client_redirect("/publication/$pub_id/view"); 
	} else {
	    $self->get_page()->client_redirect("$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new");
	}
    }
    #fetch the publication from pubmed:
    my $pubmed= CXGN::Tools::Pubmed->new($publication); 
    my $e_id = $publication->get_eid;
    if ($e_id) {
	$publication->add_dbxref("DOI:$e_id");
    }
    $self->SUPER::store(1); #this gives the publication a  dbxref id, and stores it in pub, pub_dbxref pubabstract(change to pubprop!!), and pub_author

    #instantiate a new dbxref object 
    my $dbxref= CXGN::Chado::Dbxref->new($self->get_dbh(), $publication->get_dbxref_id_by_db('PMID') );

    #store the new locus_dbxref..
    if ($type eq 'locus') { $locus->add_locus_dbxref($dbxref, undef, $sp_person_id); }
    elsif ($type eq 'allele') { $allele->add_allele_dbxref($dbxref, undef, $sp_person_id); }
    elsif ($type eq 'stock') { $stock->get_object_row->find_or_create_related('stock_pubs' , {
        pub_id => $publication->get_pub_id } );
    }
    $self->send_publication_email();	
    if ($type && $type_id) { #if the publication is also associated with another object 
	$self->get_page()->client_redirect("$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new"); 
    }else { 
	my $pub_id  = $publication->get_pub_id();
	$self->get_page()->client_redirect("/publication/$pub_id/view"); 
    } 
}


sub delete {
    my $self  = shift;
    $self->check_modify_privileges();
    my $script_name= $self->get_script_name();
    my %args= $self->get_args();
    my $type= $args{type};
    my $type_id= $args{type_id};
    my $refering_page=$args{refering_page};

    my $publication = $self->get_object();

    if ($type eq 'locus') {
 	my $locus_dbxref_obj=CXGN::Phenome::LocusDbxref->new($self->get_dbh, $args{object_dbxref_id});
	$locus_dbxref_obj->obsolete();

    } elsif ($type eq 'allele') {
 	my $allele_dbxref_obj=CXGN::Phenome::AlleleDbxref->new($self->get_dbh, $args{object_dbxref_id});
	$allele_dbxref_obj->delete();

    } elsif ($type eq 'stock') {
 	#need to pass the stock_pub_id as object_pub_id arg
        $self->get_schema->resultset("Stock::StockPub")->find( { stock_pub_id => $args{object_pub_id} } )
            ->delete;

    }else { print qq | <h3> What are you trying to delete here? </h3>| };

    $self->send_publication_email();
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
    my $type_id= $args{type_id}; #the id of the object we want to associate to the publication

    my $object_name;
    my $object_pub_id = $args{object_pub_id};
    my $object_dbxref_id= $args{object_dbxref_id};

    if ( $object_dbxref_id ) { 
	if ($type eq 'locus') {
	    my $locus = CXGN::Phenome::Locus->new($self->get_dbh(), $type_id);
	    $object_name = $locus->get_locus_name();
        }elsif ($type eq 'allele') {
	    my $allele = CXGN::Phenome::Allele->new($self->get_dbh(), $type_id);
	    $object_name = $allele->get_allele_name();
        }
	$object_dbxref_id= $args{object_dbxref_id};
    }
    if ( $object_pub_id ) {
        if ($type eq 'stock') {
            my $stock = $self->get_schema->resultset("Stock::Stock")->find( {
                stock_id => $type_id } );
            $object_name = $stock->name;
        }
    }
    my $back_link= qq |<a href="javascript:history.back(1)">Go back without deleting</a> |;

    $self->get_page()->header();

    page_title_html();
    print qq {
	<form>
	    Delete publication association with $type ($object_name)? 
	    <input type="hidden" name="action" value="delete" />
	    <input type="hidden" name="$field_name" value="$object_id" />	    
	    <input type="hidden" name="type" value="$type" />
	    <input type="hidden" name="type_id" value="$type_id" />
	    <input type="hidden" name="object_dbxref_id" value="$object_dbxref_id" />
	    <input type="hidden" name="object_pub_id" value="$object_pub_id" />
	    <input type="hidden" name="refering_page" value="$args{refering_page}" />	
	    <input type="submit" value="Delete" />
	    </form>

	    $back_link
	};

    $self->get_page()->footer();
}


sub generate_form { 
    my $self = shift;

    my %args = $self->get_args();
    my $publication = $self->get_object();
    my $pub_id = $self->get_object_id();
    
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
    $self->get_form()->add_field(display_name=>"Enter a PubMed ID: ", 
				 field_name=>"accession", 
				 length=>20, 
				 object=>$publication, 
				 getter=>"get_accession", 
				 setter=>"set_accession", 
				 validate=>"token"
				 );
    
   
    $self->get_form()->add_hidden( field_name=>"action", contents=>"confirm_store" );
    $self->get_form()->add_hidden( field_name=>"pub_id", contents=>$pub_id );
    
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

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();
    #my $cvterm_name = $args{cvterm_name};
    # generate an appropriate edit link
    #
    
    $self->get_page->jsan_use("CXGN.Phenome.Tools");
    $self->get_page->jsan_use("MochiKit.DOM");
    $self->get_page->jsan_use("Prototype");
    
    my $script_name = $self->get_script_name();
    my @publications = ();
    my @obsoleted= ();
    my ($locus, $allele, $pop, $ind, @dbxref_objs, $object_dbxref_id, $obsolete, $name_dbxref_id, $stock, $pubs); #add vars here if you want this script to work with other object types..
    
    # render the form
    $self->get_page()->header();
    
    print page_title_html( qq { SGN publication upload page } );

    print qq { <b> Publications list</b> };

    if ($args{type} eq 'locus') { 
	$locus = CXGN::Phenome::Locus->new($self->get_dbh(), $args{type_id});
	@dbxref_objs= $locus->get_dbxrefs(); #array of dbxref objects
	print "for locus '".$locus->get_locus_name()."'<br /><br />\n";
    
    }elsif ($args{type} eq 'allele') {
	$allele = CXGN::Phenome::Allele->new($self->get_dbh(), $args{type_id});
	@dbxref_objs=$allele->get_all_allele_dbxrefs(); #array of dbxref objects
	print "for allele '".$allele->get_allele_name()."'<br /><br />\n";
    }
    elsif ($args{type} eq 'stock') {
	$stock = CXGN::Chado::Stock->new($self->get_schema, $args{type_id});
	$pubs = $stock->get_object_row->search_related('stock_pubs');
        $pubs = $pubs->search_related('pub') if $pubs;
       	print "for stock '".$stock->get_name ."'<br /><br />\n";
        if ($pubs) {
            while (my $pub = $pubs->next ) {
                my $pub_id = $pub->pub_id;
                my $db_name = $pub->pub_dbxrefs->first->dbxref->db->name;
                my $accession = $pub->pub_dbxrefs->first->dbxref->accession;
                my $author_string = $self->author_string($pub);
                my $object_pub_id = $stock->get_object_row->search_related('stock_pubs', pub_id => $pub_id)->first->stock_pub_id if $stock;
                print "<a href= /publication/$pub_id/view>$db_name:$accession</a> " . $pub->title() . " (" . $pub->pyear() . ") <b>" . $author_string . "</b>" . qq { \n <a href="add_publication.pl?pub_id=$pub_id&amp;type=$args{type}&amp;type_id=$args{type_id}&amp;object_pub_id=$object_pub_id&amp;action=confirm_delete&amp;refering_page=$args{refering_page}">[Remove]</a> <br /><br />\n };
            }
        }
    }
    foreach my $dbxref (@dbxref_objs) {
        my $db_name=$dbxref->get_db_name();
	my $pub= $dbxref->get_publication();

	my $pub_id = $pub->get_pub_id();
	my $accession= $dbxref->get_accession();

	if ($args{type} eq 'locus') {
	    #$name_dbxref_id= 'locus_dbxref_id';
	    $object_dbxref_id= $locus->get_locus_dbxref($dbxref)->get_object_dbxref_id();
	    $obsolete= $locus->get_locus_dbxref($dbxref)->get_obsolete();
	}elsif  ($args{type} eq 'allele') {
	    #$name_dbxref_id= 'allele_dbxref_id';
	    $object_dbxref_id= $allele->get_allele_dbxref($dbxref)->get_allele_dbxref_id();
	    $obsolete= $allele->get_allele_dbxref($dbxref)->get_obsolete();
        }
	if ($db_name eq 'SGN_ref') { $accession= $pub_id; }
	if ($obsolete eq 'f') {
	    if ($pub_id && $object_dbxref_id) {print "<a href= /publication/$pub_id/view>$db_name:$accession</a>" . $pub->get_title() . " (" . $pub->get_pyear() . ") <b>" . $pub->get_authors_as_string() . "</b>" . qq { \n <a href="add_publication.pl?pub_id=$pub_id&amp;type=$args{type}&amp;type_id=$args{type_id}&amp;object_dbxref_id=$object_dbxref_id&amp;action=confirm_delete&amp;refering_page=$args{refering_page}">[Remove]</a> <br /><br />\n }; } 
	}elsif($pub_id)  {
	    push @obsoleted, [$pub, $object_dbxref_id] ; #an array of obsoletes pub objects
	}
    }

    if (@obsoleted) { $self->print_obsoleted($args{type}, $args{type_id}, @obsoleted) ; }

    print qq { <br /><br /><b>Associate a publication with this $args{type}</b>: };
    print qq { <center> };
    $self->get_form()->as_table();
    print qq { </center> };

    print qq {<br /> <br /><b> For publications not in Pubmed <a href="/publication/0/new">click here</a> <br /> };

    if ($args{refering_page}) { print "<a href=\"$args{refering_page}\">[Go back]</a><br /><br />\n"; }

    $self->get_page()->footer();
}


sub print_obsoleted {
    my $self=shift;
    my $type=shift;
    my $type_id=shift;
    my @publications=@_;
    my $obsoleted_pubs;
    foreach my $ref (@publications) {
	my $pub= $ref->[0];
	my $pub_id= $pub->get_pub_id();
	my $db_name= ($pub->get_dbxrefs())[0]->get_db_name();
	my $uniquename= $pub->get_uniquename();
	my ($accession, $title)= split ':', $uniquename;
	#if ($db_name eq 'SGN_ref') { $accession= $pub_id;}
	my $url="/publication/$pub_id/view";
	$obsoleted_pubs .=  qq |<a href= $url target=blank>$db_name:$accession</a> $uniquename | . $self->unobsolete_pub($type, $ref->[1])."<br />";
    }
    my $print_obsoleted= 
	html_optional_show('obsoleted_pubs',
			   'Show obsolete',
			   qq|<div class="minorbox">$obsoleted_pubs</div> |,
			   );
    
    print $print_obsoleted;
    #return $print_obsoleted;
}

sub unobsolete_pub {
    my $self =shift;
    my $type=shift;
    my $type_dbxref_id= shift;
    my $unobsolete_link = "";
   
    if (($self->get_user()->get_user_type() eq 'submitter') || ($self->get_user()->get_user_type() eq 'curator') || ($self->get_user()->get_user_type() eq 'sequencer')) {
	$unobsolete_link=qq| 
	    <a href="javascript:Tools.unobsoleteAnnot('$type', '$type_dbxref_id')">[unobsolete]</a>
	    
	    <div id='unobsoleteAnnotationForm' style="display: none">
            <div id='type_dbxref_id_hidden'>
	    <input type="hidden" 
	    value=$type_dbxref_id
	    id="$type_dbxref_id">
	    </div>
	    </div>
	    |;
    } 
    return $unobsolete_link;
}

sub confirm_store {

    my $self=shift;
    my %args=$self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or allele or stock...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $accession= sanitize_string($args{accession});
    
    my $publication= $self->get_object();
    $publication->set_accession($accession);
    
############
    my $dbxref_id=undef;
    
    #need to check if the publication is already in the database and associated with the object (locus..)
    my $existing_publication= CXGN::Chado::Publication->get_pub_by_accession($self->get_dbh(),$accession) ;

    if (my $pub_id = $existing_publication->get_pub_id) {
        my $publication=CXGN::Chado::Publication->new($self->get_dbh(), $pub_id);
	if($publication->is_associated_publication($type, $type_id)) {
	    $self->get_page()->header();
	    print  "<h3>Publication '$accession' is already associated with $args{type}  $args{type_id} </h3>";
	    print qq { <a href="javascript:history.back(1)">back to publications</a> };
	    $self->get_page()->footer();
	}
	else { #the publication isn't associated with this object
	    if (!$type && !$type_id) {
		$self->get_page()->client_redirect("/publication/$pub_id/view"); 
	    } else {
		$self->get_page()->header();
		$self->print_confirm_form();
	    }
	}
    } else { # the publication doesn't exist in our database
	$self->get_page()->header();
	$self->print_confirm_form();
    }
    
    
}


sub print_confirm_form {
    my $self=shift;
    my %args= $self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $accession= sanitize_string($args{accession});
    
    my $script_name= $self->get_script_name();
    
    my $publication= $self->get_object();
    $publication->set_accession($accession);
    
############
    my $dbxref_id=undef;
    
    #first fetch the publication from pubmed:
  
    my $pubmed= CXGN::Tools::Pubmed->new($publication); 
    my $pub_title=$publication->get_title();
   
    #check if NCBI server is down (See CXGN::Tools::Pubmed for set_message($message)
    if ($publication->get_message() ) { $self->get_page->message_page( $publication->get_message() ); }
    #add pubmed verification step	
    if ( !$pub_title ) {
	print  qq |<h3> $accession is not a valid pubmed ID. </h3>  |;
	print  qq |<a href="$script_name?type=$type&amp;type_id=$type_id&amp;refering_page=$refering_page&amp;action=new">Go back</a>|;
	$self->get_page()->footer();		   
	exit(0);
    }
    
    
############
    my $print_publication ="";
    my @authors= $publication->get_authors();
    foreach my $a (@authors) {
	$print_publication .=$a .", ";
    }
    
    chop $print_publication;
    chop $print_publication;
    $print_publication .= ". (" . $publication->get_pyear() . ") " . $publication->get_title() . " " . $publication->get_series_name(). " (" . $publication->get_volume() . "):" . $publication->get_pages() . ".";
    
    my $pyear= $publication->get_pyear(); #) $publication->get_title(). $publication->get_series_name() . $publication->get_volume() : $publication->get_pages() .  |; 
   
    my $print_associations;
   
    my $publication_exists= CXGN::Chado::Publication->get_pub_by_accession($self->get_dbh(), $accession);
    $publication->set_pub_id($publication_exists->get_pub_id()) if $publication_exists;
    
    if ($type eq 'locus') {
	my $locus= CXGN::Phenome::Locus->new($self->get_dbh(), $type_id);
	my $is_associated= $locus->associated_publication($accession);
	if ($publication && !$is_associated) {
	    my @associated_with_loci = $publication->get_loci();
	    if (@associated_with_loci) {
		$print_associations .= "<br> this publication is already associated with locus:<br> ";
		foreach my $a(@associated_with_loci) {
		    my $a_locus_id= $a->get_locus_id;
		    my $a_locus_name=$a->get_locus_name;
		    $print_associations .= qq | <a href= "/phenome/locus_display.pl?locus_id=$a_locus_id">$a_locus_name<br></a> |;
		}
	    }
	}
    }
    print qq | <br/> <h3>The following publication will be stored in the database and associated with $args{type}  $args{type_id}: </h3> $print_publication <br> <b> $print_associations </b>|;
    
    
    
    $self->init_form();
    
    $self->get_form()->add_hidden( field_name=>"accession", contents=>$accession );
    $self->get_form()->add_hidden( field_name=>"type", contents=>$args{type} );
    $self->get_form()->add_hidden( field_name=>"type_id", contents=>$args{type_id} );
    $self->get_form()->add_hidden( field_name=>"refering_page", contents=>$args{refering_page} );
    
    
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    
    page_title_html("Confirm store");
    
    
    
    $self->get_form()->as_table();
    
    if ($self->get_action()=~/store/i) {
	$self->get_form()->from_request(%args);
       

    }
   
    print qq | <BR> <a href="javascript:history.back(1)">Go back without storing the publication</a> | ;
   
    $self->get_page()->footer();
    
}

sub send_publication_email {

    my $self=shift;
    my %args= $self->get_args();
    my $refering_page=$args{refering_page};
    my $type= $args{type};  #locus or...?
    my $type_id = $args{type_id}; #the database id of the refering object (locus..)
    my $accession= sanitize_string($args{accession});
    my $deleted_pubid = $args{pub_id};


    my $action= $self->get_action();
    my $type_link;
    my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
    my $sp_person_id=$self->get_user()->get_sp_person_id();

    if ($type eq 'locus') {
	$type_link = qq | solgenomics.net/locus/$type_id/view|;
    }
    elsif ($type eq 'allele') {
	$type_link = qq | solgenomics.net/phenome/allele.pl?allele_id=$type_id|;
    }
    elsif ($type eq 'stock') {
	$type_link = qq | solgenomics.net/stock/view/id/$type_id|;
    }

    my $user_link = qq | solgenomics.net/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;

    my $usermail=$self->get_user()->get_contact_email();
    my $fdbk_body;
    my $subject;

    my $pubmed_link = qq | http://www.ncbi.nlm.nih.gov/pubmed/$accession |;

if ($action eq 'store') {

        $subject="[New publication associated with $type: $type_id]";
	$fdbk_body="$username ($user_link) has associated publication $pubmed_link \n with $type: $type_link"; 
   }
    elsif($action eq 'delete') {

	my $deleted_pub = CXGN::Chado::Publication->new($self->get_dbh(), $deleted_pubid);
	my $deleted_acc = $deleted_pub->get_accession();
	my $deleted_pubmed = qq | http://www.ncbi.nlm.nih.gov/pubmed/$deleted_acc |;
	$subject="[A publication-$type association removed from $type: $type_id]";
	$fdbk_body="$username ($user_link) has removed publication $deleted_pubmed \n from $type: $type_link"; 
    }

    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');

}


sub get_schema {
  my $self = shift;
  return $self->{schema}; 
}

sub set_schema {
  my $self = shift;
  $self->{schema} = shift;
}

sub author_string {
    my ($self, $pub) = @_;
    my $string;
    my $authors = $pub->search_related('pubauthors' , {}, { order_by => 'rank' } );
    while (my $author = $authors->next) {
	my $last_name  = $author->surname();
	my $first_names = $author->givennames();

	my ($first_name, $name) = split (/,/, $first_names);
	if ($name) {
	    $string .="$last_name, $name. ";
	} else { $string .= "$last_name, $first_name. "; }
    }
    chop $string;
    chop $string;
    return $string;
}
