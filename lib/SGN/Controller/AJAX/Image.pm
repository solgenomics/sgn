
=head1 NAME

    SGN::Controller::AJAX::Image - image ajax requests

=head1 DESCRIPTION

Implements the following endpoints:

 GET /ajax/image/<image_id> 

 GET /ajax/image/<image_id>/stock/<stock_id>/display_order

 POST /ajax/image/<image_id>/stock/<stock_id>/display_order/<display_order>

 GET /ajax/image/<image_id>/locus/<locus_id>/display_order

 POST /ajax/image/<image_id>/locus/<locus_id>/display_order/<display_order>

=head1 AUTHOR

Lukas Mueller <lam87@cornell.edu>

=cut

package SGN::Controller::AJAX::Image;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' };

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


# parse /ajax/image/<image_id>
#
sub basic_ajax_image :Chained('/') PathPart('ajax/image') CaptureArgs(1) ActionClass('REST') {  }

sub basic_ajax_image_GET { 
    my $self = shift;
    my $c = shift;
    
    $c->stash->{image_id} = shift;
    print STDERR "Stashing image...\n";
    $c->stash->{image} = SGN::Image->new($c->dbc->dbh(), $c->stash->{image_id});    
}

sub basic_ajax_image_POST { 
    my $self = shift;
    my $c = shift;
    $c->stash->{image_id} = shift;

    print STDERR "Stashing image...\n";
    $c->stash->{image} = SGN::Image->new($c->dbc->dbh(), $c->stash->{image_id});
}

# endpoint /ajax/image/<image_id>
#    
sub image_info :Chained('basic_ajax_image') PathPart('') Args(0) ActionClass('REST') {}

sub image_info_GET { 
    my $self = shift;
    my $c = shift;

    my @display_order_info = $c->stash->{image}->get_display_order_info();
    
    
    my $response = { 
	thumbnail => $c->stash->{image}->get_image_url("thumbnail"),
	small => $c->stash->{image}->get_image_url("small"),
	medium => $c->stash->{image}->get_image_url("medium"),
	large => $c->stash->{image}->get_image_url("large"),
	sp_person_id => $c->stash->{image}->get_sp_person_id(),
        md5sum => $c->stash->{image}->get_md5sum(),	    
	display_order => \@display_order_info
    };
    
    $c->stash->{rest} = $response;
}


# parse /ajax/image/<image_id>/stock/<stock_id>
#
sub image_stock_connection :Chained('basic_ajax_image') PathPart('stock') CaptureArgs(1) ActionClass('REST') { }

sub image_stock_connection_GET { 
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $self->image_stock_connection_POST($c, $stock_id);
}

sub image_stock_connection_POST {  
    my $self = shift;
    my $c = shift;

    $c->stash->{stock_id} = shift;
}

# GET endpoint /ajax/image/<image_id>/stock/<stock_id>/display_order
#
sub get_image_stock_display_order : Chained('image_stock_connection') PathPart('display_order') Args(0) ActionClass('REST') { }

sub get_image_stock_display_order_GET { 
    my $self = shift;
    my $c = shift;
    
    my $do = $c->stash->{image}->get_stock_page_display_order($c->stash->{stock_id});
    $c->stash->{rest} = { stock_id => $c->stash->{stock_id},
                          image_id => $c->stash->{image_id},
			  display_order => $do,
    };
}

# POST endpoint /ajax/image/<image_id>/stock/<stock_id>/display_order/<display_order>
#
sub add_image_stock_display_order :Chained('image_stock_connection') PathPart('display_order') Args(1) ActionClass('REST') { }

sub add_image_stock_display_order_GET { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    $self->add_image_stock_display_order_POST($c, $display_order);
}

sub add_image_stock_display_order_POST { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    if (!$c->user()) { 
	$c->stash->{rest} = { error => "you need to be logged in to modify the display order of images"};
	return;
    }
    
    if (!$c->user()->check_roles("curator") && $c->stash->{image}->get_sp_person_id() != $c->user()->get_object()->get_sp_person_id()) { 
	$c->stash->{rest} = { error => "You cannot modify an image that you don't own.\n" };
	return;
    }

    my $error = $c->stash->{image}->set_stock_page_display_order($c->stash->{stock_id}, $display_order);    
    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} = { success => 1 };
    }    
}

# parse /ajax/image/<image_id>/locus/<locus_id>
#
sub image_locus_connection :Chained('basic_ajax_image') PathPart('locus') CaptureArgs(1) ActionClass('REST') { }

sub image_locus_connection_GET { 
    my $self = shift;
    my $c = shift;
    my $stock_id = shift;

    $self->image_locus_connection_POST($c, $stock_id);
}

sub image_locus_connection_POST {  
    my $self = shift;
    my $c = shift;

    $c->stash->{locus_id} = shift;

    if (!$c->user()) { 
	$c->stash->{rest} = { error => "you need to be logged in to modify the display order of images"};
	return;
    }
    
    if (!$c->user()->check_roles("curator") && $c->stash->{image}->get_sp_person_id() != $c->user()->get_object()->get_sp_person_id()) { 
	$c->stash->{rest} = { error => "You cannot modify an image that you don't own.\n" };
	return;
    }
}

# GET endpoint /ajax/image/<image_id>/locus/<locus_id>/display_order
#
sub get_image_locus_display_order :Chained('image_locus_connection') PathPart('display_order') Args(0) ActionClass('REST') { }

sub get_image_locus_display_order_GET { 
    my $self = shift;
    my $c = shift;
    
    my $do = $c->stash->{image}->get_locus_page_display_order($c->stash->{locus_id});
    $c->stash->{rest} = { locus_id => $c->stash->{locus_id},
                          image_id => $c->stash->{image_id},
			  display_order => $do,
    };
}

# POST endpoint /ajax/image/<image_id>/locus/<locus_id>/display_order/<display_order>
#
sub add_image_locus_display_order :Chained('image_locus_connection') PathPart('display_order') Args(1) ActionClass('REST') { }

sub add_image_locus_display_order_GET { 
    my $self = shift;
    my $c = shift;
    my $display_order = shift;

    $self->add_image_locus_display_order_POST($c, $display_order);
}

sub add_image_locus_display_order_POST { 
    my $self = shift;
    my $c = shift;

    my $display_order = shift;
    
    my $error = $c->stash->{image}->set_locus_page_display_order($c->stash->{image_id}, $display_order);

    if ($error) { 
	$c->stash->{rest} = { error => $error };
    }
    else { 
	$c->stash->{rest} = { success => 1 };
    }
}


1;
