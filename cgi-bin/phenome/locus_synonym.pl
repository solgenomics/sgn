
use strict;

my $locus_synonym_detail_page = CXGN::Phenome::LocusSynonymDetailPage->new();

package CXGN::Phenome::LocusSynonymDetailPage;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / info_section_html page_title_html /;
use CXGN::Phenome::LocusSynonym;
use CXGN::Phenome::Locus;
use CXGN::Feed;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("locus_synonym.pl");

    return $self; 
}
 

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{locus_alias_id});
    $self->set_object(CXGN::Phenome::LocusSynonym->new($self->get_dbh(), $self->get_object_id())
		      );
    $self->set_primary_key("locus_alias_id");		      
    $self->set_owners();
}

# override store to check if a locus synonym with the submitted name already exists

sub store { 
    my $self = shift;

    my $locus_synonym = $self->get_object();

    my $locus_synonym_id = $self->get_object_id();
    my %args = $self->get_args();
    
    
    my $not_new_locus_synonym = "";
  #  print STDERR "*** STORING LOCUS SYNONYM ***\n";
    my ($existing_id, $obsolete) = CXGN::Phenome::LocusSynonym::exists_locus_synonym_named($self->get_dbh(), $args{locus_alias}, $args{locus_id});
    print STDERR "******$existing_id, $obsolete\n";
    if ($existing_id && $obsolete == 0) { 
	print STDERR "**Locus Synonym already exists...\n";

	$self->get_page()->header();
	print $not_new_locus_synonym = "Locus synonym '".$args{locus_alias}. "' already exists <br />";
	print qq { <a href="javascript:history.back(1)">back to locus synonyms</a> };
	$self->get_page()->footer();
	exit();
    }else { 
	$self->SUPER::store(1);
	$self->send_synonym_email();
    }
     
    my $locus_id= $args{locus_id};
    $self->get_page()->client_redirect("/phenome/locus_synonym.pl?locus_id=$locus_id&action=new");
}

sub delete_dialog { 
    my $self  = shift;
    $self->delete();
}

sub delete { 
    my $self = shift;
    my %args = $self->get_args();
   
    $self->check_modify_privileges();

    my $locus;
    my $locus_name;
    my $image;
    my $image_name;

    my $locus_synonym_name = $self->get_object()->get_locus_alias();

    if ($args{locus_id}) { 
	$locus = CXGN::Phenome::Locus->new($self->get_dbh(), $args{locus_id});
	$locus_name = $locus->get_locus_name();
	$locus->remove_locus_alias($args{locus_alias_id});
	$self->send_synonym_email('delete');
    }

        
    if ($locus) { 
	my $locus_id= $args{locus_id};
	$self->get_page()->client_redirect("/phenome/locus_synonym.pl?locus_id=$locus_id&action=new");
    }	
}

sub generate_form { 
    my $self = shift;

    my %args = $self->get_args();
    my $locus_synonym = $self->get_object();
    my $locus_synonym_id = $self->get_object_id();
    
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
    $self->get_form()->add_field(display_name=>"Locus synonym: ", 
				 field_name=>"locus_alias", 
				 length=>20, 
				 object=>$locus_synonym, 
				 getter=>"get_locus_alias", 
				 setter=>"set_locus_alias", 
				 validate=>"string"
				 );
    
   
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    $self->get_form()->add_hidden( field_name=>"locus_alias_id", contents=>$locus_synonym_id );
    
    $self->get_form()->add_hidden( field_name=>"locus_id", 
				   contents=>$args{locus_id}, 
				   object=>$locus_synonym, 
				   getter=>"get_locus_id", 
				   setter=>"set_locus_id"
				   );
    $self->get_form()->add_hidden (
				   field_name => "sp_person_id",
				   contents   =>$self->get_user()->get_sp_person_id(), 
				   object     => $locus_synonym,
				   setter     =>"set_sp_person_id", 
				   );
  
    # populate the form
    # (do nothing here because synonyms cannot be edited).
    #if ($self->get_action()=~/view|edit/i) { 
#	$self->get_form()->from_database();
#    }
    if ($self->get_action()=~/store/i) {
	$args{locus_alias}=lc($args{locus_alias}); # somehow this doesn't work -- would like to lowercase all tags...
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
    my $locus;
    my $locus_name;
    my $image;
    my $image_name;
    
    my @locus_synonyms = ();
    my @image_tags = ();
    my @experiment_tags = ();

    # render the form
    #
    $self->get_page()->header();
    
    print page_title_html( qq { SGN <a href="/search/direct_search.pl?search=loci">genes</a> database } );

    print qq { <b>Locus synonyms</b> };

    if ($args{locus_id}) { 
	$locus = CXGN::Phenome::Locus->new($self->get_dbh(), $args{locus_id});
	@locus_synonyms=$locus->get_locus_aliases('f', 'f');
	my $locus_id = $locus->get_locus_id();
	print "for locus ".$locus->get_locus_name()."<br /><br />\n";
	foreach my $ls (@locus_synonyms) { 
	    my $locus_synonym_id = $ls->get_locus_alias_id();
	    print $ls->get_locus_alias(). qq { \n <a href="locus_synonym.pl?locus_id=$locus_id&amp;locus_alias_id=$locus_synonym_id&amp;action=confirm_delete">[Remove]</a> <br />\n };
	}

    }
 
    if (!@locus_synonyms && !@image_tags) { print "<b>None found</b><br /><br />\n"; }

    print qq { <br /><br /><b>Add another locus synonym</b>: };
    
    print qq { <center> };
    
    $self->get_form()->as_table();
    
    print qq { </center> };
    
    print qq { <a href="locus_display.pl?locus_id=$args{locus_id}&amp;action=view">back to locus page</a> };
    
    $self->get_page()->footer();
    

}


sub send_synonym_email {
    my $self=shift;
    my $action=shift;
    my %args = $self->get_args();
    my $locus_id= $args{locus_id};
    
    my $locus_synonym_id=$self->get_object()->get_locus_alias_id();
    my $locus_synonym_name= $self->get_object->get_locus_alias();
   
    my $username= $self->get_user()->get_first_name()." ".$self->get_user()->get_last_name();
    my $sp_person_id=$self->get_user()->get_sp_person_id();
    my $usermail=$self->get_user()->get_private_email();
    my $locus_link= qq |http://www.sgn.cornell.edu/phenome/locus_display.pl?locus_id=$locus_id|;
    my $user_link = qq |http://www.sgn.cornell.edu/solpeople/personal-info.pl?sp_person_id=$sp_person_id|;
    
    my $fdbk_body;
    my $subject;
    if ($action eq 'delete') {
	$subject="[A locus synonym deleted] locus $locus_id";
	$fdbk_body="$username ($user_link)\n has deleted locus synonym $locus_synonym_name \n from locus ($locus_link)\n"; }
    else {
	$subject="[New locus synonym stored] locus $locus_id";
	$fdbk_body="$username ($user_link)\n has submitted a new synonym $locus_synonym_name \n for locus ($locus_link)\n"; }
    
    
    CXGN::Contact::send_email($subject,$fdbk_body, 'sgn-db-curation@sgn.cornell.edu');
    CXGN::Feed::update_feed($subject,$fdbk_body);
}
