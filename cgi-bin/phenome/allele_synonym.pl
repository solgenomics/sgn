
use strict;
use warnings; 


my $allele_synonym_detail_page = CXGN::Phenome::AlleleSynonymDetailPage->new();

package CXGN::Phenome::AlleleSynonymDetailPage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / info_section_html page_title_html /;
use CXGN::Phenome::AlleleSynonym;
use CXGN::Phenome::Allele;
use CXGN::Phenome::Locus;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("allele_synonym.pl");

    return $self; 
}
 

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    my $allele_alias_id= $args{allele_alias_id};
   
    $self->set_object_id($allele_alias_id);
    $self->set_object(CXGN::Phenome::AlleleSynonym->new($self->get_dbh(), $self->get_object_id())
		      );
    $self->set_primary_key("allele_alias_id");		      
    $self->set_owners();
}

# override store to check if an allele  synonym with the submitted name already exists

sub store { 
    my $self = shift;

    my $allele_synonym = $self->get_object();

    my $allele_synonym_id = $self->get_object_id();
    my %args = $self->get_args();
    
    
    my $not_new_allele_synonym = "";
    #  print STDERR "*** STORING ALLELE SYNONYM ***\n";
    my $existing_id = CXGN::Phenome::AlleleSynonym::exists_allele_synonym_named($self->get_dbh(), $args{allele_alias}, $args{allele_id});
    if ($existing_id) { 
	print STDERR "**Allele Synonym already exists...\n";

	$self->get_page()->header();
	print $not_new_allele_synonym = "Allele synonym '".$args{allele_alias}. "' already exists <br />";
	print qq { <a href="javascript:history.back(1)">back to allele synonyms</a> };
	$self->get_page()->footer();
	exit();
    }
    else { 
	$self->SUPER::store(1);
    }
    
    my $allele;
    my $image;
    my $allele_id= $self->get_object()->get_allele_id();
    if ( $allele_id ) { 
	$allele = CXGN::Phenome::Allele->new($self->get_dbh(), $args{allele_id});
	$allele->add_allele_aliases($allele_synonym);
	
	$self->get_page()->client_redirect("/phenome/allele_synonym.pl?allele_id=$allele_id&action=new");
    }
}

sub delete_dialog { 
    my $self  = shift;
    $self->delete();
}

sub delete { 
    my $self = shift;
    my %args = $self->get_args();
   
    $self->check_modify_privileges();

    my ($allele, $allele_name, $allele_symbol);
   
    my $allele_synonym_name = $self->get_object()->get_allele_alias();

    if ($args{allele_id}) { 
	$allele = CXGN::Phenome::Allele->new($self->get_dbh(), $args{allele_id});
	$allele_name = $allele->get_allele_name();
	$allele_symbol= $allele->get_allele_symbol();
	$allele->remove_allele_alias($args{allele_alias_id});
	
    }
  
    $self->get_page()->header();
    
    if ($allele) { 
	print qq { Removed allele synonym "$allele_synonym_name" association from allele "$allele_symbol" ($allele_name).<br /> }; 
	print qq { <a href="allele_synonym.pl?allele_id=$args{allele_id}&amp;action=new">Back to allele synonyms page</a> };
    }
  
    $self->get_page()->footer();		   
	
}

sub generate_form { 
    my $self = shift;

    my %args = $self->get_args();
    my $allele_synonym = $self->get_object();
    my $allele_synonym_id = $self->get_object_id();
    
   
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
    $self->get_form()->add_field(display_name=>"Allele synonym: ", 
				 field_name=>"allele_alias", 
				 length=>20, 
				 object=>$allele_synonym, 
				 getter=>"get_allele_alias", 
				 setter=>"set_allele_alias", 
				 validate=>"token"
				 );
    
   
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    $self->get_form()->add_hidden( field_name=>"allele_alias_id", contents=>$allele_synonym_id );
    
    $self->get_form()->add_hidden( field_name=>"allele_id", 
				   contents=>$args{allele_id}, 
				   object=>$allele_synonym, 
				   getter=>"get_allele_id", 
				   setter=>"set_allele_id"
				   );

    $self->get_form()->add_hidden (
				   field_name => "sp_person_id",
				   contents   =>$self->get_user()->get_sp_person_id(), 
				   object     => $allele_synonym,
				   setter     =>"set_sp_person_id", 
				   );
  
    # populate the form
    # (do nothing here because synonyms cannot be edited).
    #if ($self->get_action()=~/view|edit/i) { 
#	$self->get_form()->from_database();
#    }
    if ($self->get_action()=~/store/i) {
	$args{allele_alias}=lc($args{allele_alias}); # somehow this doesn't work -- would like to lowercase all tags...
	$self->get_form()->from_request(%args);
    }


}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();

    # generate an appropriate edit link
    #
    my $script_name = $self->get_script_name();
   
    # generate some locus and/or image information
    #
    my $allele;
    my $allele_name;
    my $allele_symbol;
    my $allele_id; 
    my @allele_synonyms = ();
    my $locus_id;
    # render the form
    #
    $self->get_page()->header();
    
    print page_title_html( qq { <h3>SGN <a href="/search/direct_search.pl?search=loci">genes</a> database } );

    print qq { <b>Allele synonyms</b> };

    if ($args{allele_id}) { 
	$allele = CXGN::Phenome::Allele->new($self->get_dbh(), $args{allele_id});
	@allele_synonyms=$allele->get_allele_aliases();
	$allele_id = $allele->get_allele_id();
	$locus_id= $allele->get_locus_id();
	print "for allele ".$allele->get_allele_symbol()." (".$allele->get_allele_name().")<br /><br />\n";
	foreach my $as (@allele_synonyms) { 
	    my $allele_synonym_id = $as->get_allele_alias_id();
	    print $as->get_allele_alias(). qq { \n <a href="allele_synonym.pl?allele_id=$allele_id&amp;allele_alias_id=$allele_synonym_id&amp;locus_id=$locus_id&amp;action=confirm_delete">[Remove]</a> <br />\n };
	}

    }
  
    if (!@allele_synonyms) { print "<b>None found</b><br /><br />\n"; }

    print qq { <br /><br /><b>Add another allele synonym</b>: };
    
    print qq { <center> };
    
    $self->get_form()->as_table();
    
    print qq { </center> };
    
    print qq { <a href = "allele.pl?allele_id=$allele_id&amp;action=view">back to allele page</a><br> };
    print qq { <a href="locus_display.pl?locus_id=$locus_id&amp;action=view">back to locus page</a> };
    
    $self->get_page()->footer();
    
}
