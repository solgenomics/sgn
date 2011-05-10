package SGN::Role::Site::Mason;

use Moose::Role;
use namespace::autoclean;
use File::Basename;
use File::Path;
use Path::Class;
use HTML::Mason::Interp;
use Scalar::Util qw/blessed/;

requires
    qw(
       path_to
       get_conf
       tempfiles_subdir
       setup_finalize
      );


=head2 forward_to_mason_view

  Usage: $c->forward_to_mason_view( '/some/thing', foo => 'bar' );
  Desc : call a Mason view with the given arguments and exit
  Args : mason component name (with or without .mas extension),
         hash-style list of arguments for the mason component
  Ret  : nothing.  terminates the program afterward.
  Side Effects: exits after calling the component

  This replaces CXGN::MasonFactory->new->exec( ... )

=cut

sub forward_to_mason_view {
    my $self = shift;
    my ($comp,@args) = @_;

    if( $ENV{SERVER_SOFTWARE} && $ENV{SERVER_SOFTWARE} =~ /HTTP-Request-AsCGI/ ) {
        print $self->view('Mason')->render( $self, $comp, { %{$self->stash}, @args} );
        die ["EXIT\n",0]; #< weird thing for working with Catalyst's CGIBin controller
    } else {
        $self->stash->{template} = $comp;
        %{$self->stash} = ( %{$self->stash}, @args );
        $self->view('Mason')->process( $self );
    }
}


=head2 render_mason

  Usage: my $string = $c->render_mason( '/page/page_title',
                                        title => 'My Page'  );
  Desc : call a Mason component without any autohandlers, just
         render the component and return its output as a string
  Args : mason component name (with or without .mas),
         hash-style list of component arguments
  Ret  : string of component's output
  Side Effects: none for this function, but the component could
                access the database, or whatnot
  Example :

     print '<div>Blah blah: '.$c->render_mason('/foo').'</div>';

=cut

sub render_mason {
    my $self = shift;
    my $view = shift;

    return $self->view('BareMason')->render( $self, $view, { %{$self->stash}, @_ } );
}

=head2 clear_mason_tempfiles

  Usage: $c->clear_mason_tempfiles
  Desc : delete mason cached tempfiles to force mason components to
         reload.  in normal operation, called only on server restart
  Args : none
  Ret  : nothing meaningful
  Side Effects: dies on error
  Example :

  This is run at app startup as a setup_finalize hook.

=cut

after 'setup_finalize' => \&clear_mason_tempfiles;

sub clear_mason_tempfiles {
  my ( $self ) = @_;

  for my $temp ( $self->path_to( $self->tempfiles_subdir() )->children ) {
      rmtree( "$temp" ) if -d $temp && basename("$temp") =~ /^mason_cache_/;
  }
}

1;
