use strict;

my $image_detail_page = CXGN::Image_detail_page->new();

package CXGN::Image_detail_page;


use CXGN::Page;
use CXGN::Page::FormattingHelpers qw / blue_section_html page_title_html /;
use SGN::Image;
use CXGN::Phenome::Individual;
use CXGN::Insitu::Experiment;

use base qw / CXGN::Page::Form::SimpleFormPage /;

sub new { 
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    $self->set_script_name("/image/index.pl");
    
    return $self; 
}

sub define_object { 
    my $self = shift;
    
    # call set_object_id, set_object and set_primary_key here
    # with the appropriate parameters.
    #
    my %args = $self->get_args();
    $self->set_object_id($args{image_id});
    $self->set_object(SGN::Image->new($self->get_dbh(),
						  $self->get_object_id())
		      );
    $self->set_primary_key("image_id");		      
    $self->set_owners($self->get_object()->get_sp_person_id());

}

sub delete {
    my $self = shift;
    my $image = $self->get_object();
    my %args = $self->get_args();

    eval { 
	$image->delete();
    };
    if ($@) { 
	$self->get_page()->message_page("An error occurred during deletion of the image.");
    }

    $self->get_page()->header();

    print qq { 
	The image has been successfully deleted. 
	    <a href="$args{calling_page}">Return to detail page.</a> };
    $self->get_page()->footer();
    exit();
}

sub get_edit_links { 
    my $self = shift;
    
    my $edit_link = "";
    my $delete_link = "";

    my $script_name = $self->get_script_name();
    my $primary_key = $self->get_primary_key();
    my $object_id = $self->get_object_id();
    
    #my $new_link = qq { <a href="$script_name?action=new">[New]</a> };
       #if (($self->get_user()->get_user_type() eq "curator") || grep{/^$user_id$/} @owners ) {
    my $user_id= $self->get_user()->get_sp_person_id();
    my @owners=$self->get_owners();
    if (!(grep{/^$user_id$/ } @owners) ) { 
	$edit_link = qq { <span class="ghosted">[Edit]</span> };
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
    }
    elsif ( (grep{/^$user_id$/ } @owners) ) { 
	$edit_link = qq { <a href="$script_name?action=edit&amp;$primary_key=$object_id">[Edit]</a> };
	$delete_link = qq { <a href="$script_name?action=confirm_delete&amp;$primary_key=$object_id">[Delete]</a> };
	
    }

    if ($self->get_action() eq "edit") { 
	$edit_link = qq { <a href="$script_name?action=view&amp;$primary_key=$object_id">[Cancel Edit]</a> };
	#$new_link = qq { <span class="ghosted">[New]</span> };
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
    }

    if ($self->get_action() eq "new") { 
	$edit_link = qq { <span class="ghosted">[Edit]</span> };
	$delete_link = qq { <span class="ghosted">[Delete]</span> };
	#$new_link = qq { <a onClick="history.go(-1)">[Cancel]</a> };
    }

    



    return "$edit_link  $delete_link";

}

sub generate_form { 
    my $self = shift;

    my $form;

    $self->init_form();

    my %args = $self->get_args();
    
    my $image = $self->get_object();
    my $image_id = $self->get_object_id();
    my $submitter = CXGN::People::Person->new($self->get_dbh(), $image->get_sp_person_id());
    my $sp_person_id= $submitter->get_sp_person_id();
    my $submitter_name = $submitter->get_first_name()." ".$submitter->get_last_name();
    my $submitter_link = qq |<a href="/solpeople/personal-info.pl?sp_person_id=$sp_person_id">$submitter_name </a> |;

    my $name = "";
    my $description = "";

    if ($self->get_action()=~/view|edit/i) { 
	$name = $image->get_name();
	$description = $image->get_description();
    }
    if ($self->get_action()=~/edit/i) { 
	$name ||= $args{name};
	$description ||= $args{description};
    }
    if ($self->get_action()=~/store/i) { 
	$name = $args{name};
	$description = $args{description};
    }

    my $form = undef;
    if ($self->get_action()=~/new|edit|store/ ) { 
	print STDERR "Generating EditableForm..\n";
	$form = CXGN::Page::Form::Editable->new();
    }
    else { 
	print STDERR "Generating static Form...\n";
	$form = CXGN::Page::Form::Static->new();
    }

    $form->add_field( display_name=>"Image Name:", field_name=>"name", contents=>$name, length=>15, object=>$image, getter=>"get_name", setter=>"set_name" );
    $form->add_field(  display_name=>"Image Description: ", field_name=>"description", contents=>$description, length=>40, object=>$image, getter=>"get_description", setter=>"set_description" );
    $form->add_hidden( display_name=>"Image ID", field_name=>"image_id", contents=>$image_id);
    $form->add_hidden(  display_name=>"Action", field_name=>"action", contents=>"store"  );
    $form->add_label( display_name=>"Uploaded by: ", 
				  field_name=>"submitter", 
				  contents=>$submitter_link,
				  );
    $self->set_form($form);
        
}

sub display_page { 
    my $self = shift;
    my %args = $self->get_args();
    
    my $image = $self->get_object();
    my $image_id = $self->get_object_id();

    my $check_id = $image->get_image_id(); # Supposed to return NULL if Image has been Deleted (obsoleted), or doesn't exist
    if ($check_id ne $image_id ) {  $self->get_page()->message_page("Requested Image does not exist or has been deleted."); }

    my $image_fullsize_url = $image->get_image_url("medium");
    my $image_id = $image->get_image_id();

    my $edit_links= $self->get_edit_links();
    $self->get_page()->header();
    
    print page_title_html(qq{ SGN Image });
    

    print qq { $edit_links <br /> };

    $self->get_form()->as_table();

    print "<br />Show image size: | ";

    if (!exists($args{size}) || $args{size} !~/thumbnail|small|medium|large|original/ ) { $args{size}="medium"; }
    
    foreach my $size ("thumbnail", "small", "medium", "large", "original") { 
	if ($args{size} eq $size) { print $size; }
	else { print qq { <a href="?image_id=$args{image_id}&amp;action=view&amp;size=$size">$size</a> }; }
	print " | ";
    }
    print "<br />\n";
		

    print qq { <br /><a href="$image_fullsize_url"> };
    print "<center>".($image->get_img_src_tag($args{size}))."</center>\n";
    print qq { </a><br /><br /> };

    print qq { <center><table><tr><td class="boxbgcolor5"><b>Note:</b> The above image may be subject to copyright. Please contact the submitter about permissions to use the image.</td></tr></table></center><br /> };

   my $tag_count = scalar($image->get_tags());
    print qq {<br><b>Associated tags</b> [<a href="/tag/index.pl?image_id=$image_id&amp;action=new">add/remove</a>]: ($tag_count) };
    foreach my $tag ($image->get_tags()) { 
	print $tag->get_name()."  ";
    }

    print qq { <br /><br /><b>Associated objects</b>: <br /> };

    print $image->get_associated_object_links();

    #print "S: ".$self->get_object()->get_sp_person_id()."\n";

    $self->get_page()->footer();
    
    
    
    exit();

}
