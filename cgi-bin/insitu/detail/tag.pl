
use strict;

my $tag_detail_page = CXGN::Insitu::Tag_detail_page->new();

package CXGN::Insitu::Tag_detail_page;

use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use CXGN::Insitu::Tag;
use CXGN::Insitu::Toolbar;
use CXGN::Insitu::Experiment;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_dbh(CXGN::DB::Connection->new("insitu"));
    $self->set_script_name("tag.pl");

    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{tag_id});
    $self->set_object(CXGN::Insitu::Tag->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("tag_id");		      
    $self->set_owners(0); # nobody owns tags...
}

# override store to check if a tag with the submitted name already exists

sub store { 
    my $self = shift;

    my $tag = $self->get_object();

    my $tag_id = $self->get_object_id();
    my %args = $self->get_args();
    
    
    my $not_new_tag = "";
#    print STDERR "*** STORING TAG ***\n";
    my $existing_id = CXGN::Insitu::Tag::exists_tag_named($self->get_dbh(), $args{tag});
    if ($existing_id) { 
	#print STDERR "Tag already exists...\n";
	$tag = CXGN::Insitu::Tag->new($self->get_dbh(), $existing_id);
	$self->set_object($tag);
	$self->set_object_id($existing_id);
	$not_new_tag = "Associated already existing tag.";
    }
    else { 
	$self->SUPER::store(1);
    }
    my %args = $self->get_args();
    $tag_id = $self->get_object_id();
    $tag = $self->get_object();

    my $experiment;
    my $image;

    if (exists($args{experiment_id}) && defined($args{experiment_id})) { 
	$experiment = CXGN::Insitu::Experiment->new($self->get_dbh(), $args{experiment_id});
	$experiment->add_tag($tag_id);
    }
    if (exists($args{image_id}) && defined($args{image_id})) { 
	$image = CXGN::Insitu::Image->new($self->get_dbh(), $args{image_id});
	$image->add_tag($self->get_object());
    }
    
    $self->get_page()->header();
   
    print "Adding tag ".$tag->get_name();
    if ($experiment) { 
	print " to experiment ".$experiment->get_name()."<br /><br />";
	print qq { view <a href="experiment.pl?experiment_id=$args{experiment_id}&amp;action=view">experiment</a> };
    }
    if ($image) { 
	print " to image ".$image->get_name()."<br /><br />";
	print qq { view <a href="image.pl?image_id=$args{image_id}&amp;action=view">image</a> };
    }

    $self->get_page()->footer();
    
    exit();
}
	

sub delete_dialog { 
    my $self  = shift;
    $self->delete();
}

sub delete { 
    my $self = shift;
    my %args = $self->get_args();

    my $experiment;
    my $experiment_name;
    my $image;
    my $image_name;

    my $tag_name = $self->get_object()->get_name();

    if ($args{experiment_id}) { 
	$experiment = CXGN::Insitu::Experiment->new($self->get_dbh(), $args{experiment_id});
	$experiment_name = $experiment->get_name();
	$experiment->remove_tag($args{tag_id});
	
    }
    if ($args{image_id}) { 
	$image = CXGN::Insitu::Image->new($self->get_dbh(), $args{image_id});
	$image_name = $image->get_name();
	$image ->remove_tag($self->get_object());
    }

    $self->get_page()->header();
    
    if ($experiment) { 
	print qq { Removed tag "$tag_name" association from experiment "$experiment_name". }; 
	print qq { <a href="experiment.pl?experiment_id=$args{experiment_id}&amp;action=view">back to experiment</a> };
    }
    elsif ($image) { 
	print qq { Removed tag "$tag_name" association from image "$image_name". };
	print qq { <a href="image.pl?image_id=$args{image_id}&amp;action=view">back to image detail page</a> };
    }
    if (!$args{image_id} && !$args{experiment_id}) { 
	print qq { No associations were deleted because no association information was provided. };
    }
	
    $self->get_page()->footer();		   
	
}

sub generate_form { 
    my $self = shift;

    my %args = $self->get_args();
    my $tag = $self->get_object();
    my $tag_id = $self->get_object_id();

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
    $self->get_form()->add_field(display_name=>"Tag name: ", 
				 field_name=>"tag", 
				 length=>20, 
				 object=>$tag, 
				 getter=>"get_name", 
				 setter=>"set_name", 
				 validate=>"string"
				 );
    
    #$self->get_form()->add_field( display_name=>"Description: ", 
	#			  field_name=>"description", 
	#			  length=>50, 
	#			  object=>$tag, 
	#			  getter=>"get_description", 
	#			  setter=>"set_description");
    
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );
    $self->get_form()->add_hidden( field_name=>"tag_id", contents=>$tag_id );
    $self->get_form()->add_hidden( field_name=>"experiment_id", contents=>$args{experiment_id} );
    $self->get_form()->add_hidden( field_name=>"image_id", contents=>$args{image_id} );
    
    # populate the form
    # (do nothing here because tags cannot be edited).
    #if ($self->get_action()=~/view|edit/i) { 
#	$self->get_form()->from_database();
#    }
    if ($self->get_action()=~/store/i) {
	$args{tag}=lc($args{tag}); # somehow this doesn't work -- would like to lowercase all tags...
	$self->get_form()->from_request(%args);
    }


}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();

    # generate an appropriate edit link
    #
    my $script_name = $self->get_script_name();
    
    # generate some experiment and/or image information
    #
    my $experiment;
    my $experiment_name;
    my $image;
    my $image_name;
    
    my @tags = ();
    my @image_tags = ();
    my @experiment_tags = ();

    # render the form
    #
    $self->get_page()->header();
    
    print page_title_html( qq { <h3><a href="/">Insitu</a> Database } );
    CXGN::Insitu::Toolbar::display_toolbar();    

    print qq { <b>Associated tags</b> };

    if ($args{experiment_id}) { 
	$experiment = CXGN::Insitu::Experiment->new($self->get_dbh(), $args{experiment_id});
	@experiment_tags = $experiment->get_tags();
	my $experiment_id = $experiment->get_experiment_id();
	print "for experiment ".$experiment->get_name()."<br /><br />\n";
	foreach my $t (@experiment_tags) { 
	    my $tag_id = $t->get_tag_id();
	    print $t->get_name(). qq { \n <a href="tag.pl?experiment_id=$experiment_id&amp;tag_id=$tag_id&action=delete">[Remove]</a> <br />\n };
	}

    }
    if ($args{image_id}) { 
	$image = CXGN::Insitu::Image->new($self->get_dbh(), $args{image_id});
	@image_tags = (@tags, $image->get_tags());
	my $image_id = $image->get_image_id();
	my $image_name = $image->get_name() || "Untitled";
	print qq { for image "$image_name"<br /><br />\n };

	foreach my $t (@image_tags) { 
	    my $tag_id = $t->get_tag_id(); 
	    print $t->get_name(). qq { <a href="tag.pl?image_id=$args{image_id}&amp;tag_id=$tag_id&action=delete">[Remove]</a> <br /> \n };
	}
    }
    if (!@experiment_tags && !@image_tags) { print "<b>None found</b><br /><br />\n"; }

    print qq { <br /><br /><b>Associate another tag</b>: };
    
    print qq { <center> };
    
    $self->get_form()->as_table();
    
    print qq { </center> };
    
    print qq { <a href="experiment.pl?experiment_id=$args{experiment_id}&amp;action=view">back to experiment page</a> };
    
    $self->get_page()->footer();
    


}
