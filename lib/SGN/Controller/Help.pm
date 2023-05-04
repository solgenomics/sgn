
package SGN::Controller::Help;

use Moose;

BEGIN { extends "Catalyst::Controller"; }

sub about: Path('/about') Args(0) {
    my $self = shift;
    
    $self->help(@_);
}

sub help : Path('/help') Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/help/index.mas';
}

sub help_section : Path('/help') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $section = shift;
    $section =~ s/\.\.//g; # prevent shenanigans

    
    my $component = '/help/'.$section.".mas";
    if ($c->view("Mason")->interp->comp_exists($component)) { 
	$c->stash->{basepath} = $c->config->{basepath};
	$c->stash->{documents_subdir} = $c->config->{documents_subdir};
	$c->stash->{template} = '/help/'.$section.".mas";

	
    }
    else { 
    	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message}  = 'The requested page could not be found. <br /><a href="/help">Help page</a>';
    }
}

1;
