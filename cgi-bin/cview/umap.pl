
use strict;

my $user_map_detail_page = CXGN::Cview::Map::SGN::UserMapDetailPage->new();

package CXGN::Cview::Map::SGN::UserMapDetailPage;


use CXGN::Cview::Map::SGN::User;
use CXGN::Cview::MapOverviews::Generic;
use CXGN::People::UserMap;
use CXGN::People::UserMapData;
use CXGN::Page::Form::SimpleFormPage;
use CXGN::Page::FormattingHelpers qw | page_title_html blue_section_html |;
use CXGN::People::Person;

use base qw | CXGN::Page::Form::SimpleFormPage |; 

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    return $self;
}

sub define_object { 
    my $self = shift;
    my %args = $self->get_args();
    $self->set_object_id($args{user_map_id});
    #if (($args{is_public} ne 'f' && exists($args{is_public}))) { $args{is_public}=1; }
    #else { 
#	$args{is_public}=0;
#    }   
 #   $self->set_args(%args);
    $self->set_object(CXGN::People::UserMap->new($self->get_dbh(), $self->get_object_id()));
    $self->set_primary_key("user_map_id");
    $self->set_owners($self->get_object()->get_sp_person_id());
}

sub delete { 
    my $self = shift;
    $self->check_modify_privileges();
    my $map = $self->get_object();
    my $map_name = $map->get_short_name();
    my $error = $map->delete();
    $self->get_page()->message_page("The map has been deleted.");
}

sub generate_form { 
    my $self = shift;
 
    $self->init_form();
    my %args = $self->get_args();
    
#    my %field = ();
    
    my $selected= undef;
    print STDERR "*******\nIS PUBLIC IS CURRNETLY SET TO : $args{is_public}\n******\n";
    if ($args{is_public}) { $selected =1; } else { $selected=0; }

    $self->get_form()->add_field( display_name => "Short Name", field_name=>"short_name", 
				   length=>30, object=>$self->get_object(),
				  getter=>"get_short_name", setter=>"set_short_name", validate=>"string"
				  );
    $self->get_form()->add_field( display_name => "Long Name", field_name=>"long_name", 
				   length=>60, object=>$self->get_object(),
				  getter=>"get_long_name", setter=>"set_long_name"
				  );
    $self->get_form()->add_textarea(display_name=>"Abstract", field_name=>"abstract", 
				    object=>$self->get_object(),
				    getter=>"get_abstract", setter=>"set_abstract",
				    rows=>10, columns=>60
				   );
    
    $self->get_form()->add_field(display_name=>"Parent 1", field_name=>"parent1",
				  object=>$self->get_object(),
				 getter=>"get_parent1", setter=>"set_parent1"
				 );
    $self->get_form()->add_field(display_name=>"Parent 2", field_name=>"parent2",
				  object=>$self->get_object(),
				 getter=>"get_parent2", setter=>"set_parent2"
				 );
    $self->get_form()->add_hidden( field_name=>"user_map_id", contents=>$self->get_object_id() );
    $self->get_form()->add_hidden( field_name=>"action", contents=>"store" );

    

    $self->get_form()->add_checkbox (display_name=>"Is public", field_name=>"is_public",
				     selected => $selected, contents=>$selected,
				     object=>$self->get_object(),
				     getter=>"get_is_public", setter=>"set_is_public"
				     );

    $self->get_form()->add_hidden( field_name=>"sp_person_id", contents=>$self->get_login()->has_session() );

    # populate the form
    #
    if ($self->get_action()=~/edit|view/i) { 
	$self->get_form()->from_database();
    }
    if ($self->get_action()=~/store/i) { 


	$self->get_form()->from_request(%args);
    }

}

sub display_page { 
    my $self = shift;

    # get the map object
    #
    my $map = CXGN::Cview::Map::SGN::User->new($self->get_dbh(), $self->get_object_id());

    if (!defined($map)) { 
	$self->get_page()->message_page("This map does not exist, has been deleted, or it is not set to public view.");
    }

    # get the submitter name for display
    #
    my $user = CXGN::People::Person->new($self->get_dbh(), $self->get_login()->has_session());
    my $name = $user->get_first_name()." ".$user->get_last_name();

    # generate map overview
    #
    my $force = 1;
    my $map_overview = CXGN::Cview::MapOverviews::Generic->new($map, $force);
    $map_overview->render_map();
    my $image_html = $map_overview->get_image_html();
    
    # generate page and form
    #
    $self->get_page()->header();
    
    

    print page_title_html("User Map \"".$self->get_object()->get_short_name()."\"");

    my %args = $self->get_args();

    print STDERR "Form Contents\n===========\n";
    foreach my $field ($self->get_form()->get_fields()) { 
	print STDERR $field->get_field_name()." ". $field->get_contents()."\n";
    }

    print $image_html;
    
    # print the edit links. The new link has to be changed to point to
    # upload_usermap.pl (this is not the default behaviour of course).
    print "<a href=\"upload_usermap.pl\">[New]</a> | ";
    print $self->get_edit_link_html()." | ".$self->get_delete_link_html()." <br /><br />\n";
    $self->get_form()->as_table();
    
    print "<br /><p>Submitter: $name</p>\n";
    
    $self->get_page()->footer();
}

return 1;

