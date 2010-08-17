package SGN::Role::Site::Mason;

use Moose::Role;
use namespace::autoclean;
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

has '_mason_interp' => (
    is         => 'ro',
    lazy_build => 1,
   ); 

sub _build__mason_interp {
    my $self = shift;
    my %params = @_;

    my $site_mason_root  = $self->path_to( 'mason' );

    $params{comp_root} = [ [ "site", $site_mason_root ] ];

    # add a global mason root if defined
    if( my $global_mason_root = $self->get_conf('global_mason_lib') ) {
        push @{$params{comp_root}}, [ "global", $global_mason_root ];
    }

    my $data_dir = $self->path_to( $self->tempfiles_subdir('mason_cache_'.getpwuid($>)) );

    $params{data_dir}  = join ":", grep $_, ($data_dir, $params{data_dir});

    # have a global $self for the SGN::Context (later to be Catalyst object)
    my $interp = HTML::Mason::Interp->new( allow_globals => [qw[ $c ]],
                                            %params,
                                            );
    $interp->set_global( '$c' => $self );

    return $interp;
}

sub forward_to_mason_view {
    my $self = shift;
    my ($comp,@args) = @_;

    if( $ENV{SERVER_SOFTWARE} =~ /HTTP-Request-AsCGI/ ) {
        my @args = @_;
        $self->_trap_mason_error( sub { $self->_mason_interp->exec( @args ) } );
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

my $render_mason_outbuf;
has '_bare_mason_interp' => (
    is         => 'ro',
    lazy_build => 1,
);

sub _build__bare_mason_interp {
    return shift->_build__mason_interp(
        autohandler_name => '', #< turn off autohandlers
        out_method       => \$render_mason_outbuf,
        );
}

sub render_mason {
    my $self = shift;
    my $view = shift;
    my @args = @_;

    $render_mason_outbuf = '';
    $self->_trap_mason_error( sub { $self->_bare_mason_interp->exec( $view, @args ) });

    return $render_mason_outbuf;
}

sub _trap_mason_error {
    my ( $self, $sub ) = @_;

    eval { $sub->() };
    my $error = $@;
    if( $error ) {
        if( blessed($error) && $error->can('as_brief') ) {
            my $t = $error->as_text;
            # munge mason compilation errors for better backtraces on devel debug screens
            $t =~ s/^Error during compilation of[^\n]+\n// unless $self->get_conf('production_server');
            die $t;
        }
        die $error if $error;
    }
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

  rmtree( $_ ) for glob $self->path_to( $self->tempfiles_subdir('mason_cache_*') );
}

1;
