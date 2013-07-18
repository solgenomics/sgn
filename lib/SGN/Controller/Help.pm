
package SGN::Controller::Help;

use Moose;

BEGIN { extends "Catalyst::Controller"; }



sub help : Path('/help') Args(0) { 
    my $self = shift;
    my $c = shift;

    $c->stash->{template} = '/help/index.mas';
}

sub help_section : Path('/help') Args(1) { 
    my $self = shift;
    my $c = shift;
    my $section = shift;
    $section =~ s/\.\.|\///g; # clean for shenanigans

    
    eval { 
	$c->stash->{basepath} = $c->config->{basepath};
	$c->stash->{documents_subdir} = $c->config->{documents_subdir};
	$c->stash->{template} = '/help/'.$section.".mas";
    };
    if ($@) { 
	$c->stash->{template} = '/generic_message.mas';
	$c->stash->{message}  = 'The page requested could not be found.';
    }
}

1;
