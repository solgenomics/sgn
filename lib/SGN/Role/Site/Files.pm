package SGN::Role::Site::Files;

use Moose::Role;
use namespace::autoclean;

use Carp;
use Cwd;
use File::Spec;
use File::Temp;
use File::Path qw/ mkpath rmtree /;
use URI;

requires qw(
            get_conf
            path_to
            config
            setup_finalize
           );


=head2 before setup_finalize

attempt to chown tempfiles_subdir and children to the web user

=cut

before 'setup_finalize' => sub {
    my $c = shift;

    print STDERR "CURRENT USER IDS: $<, $>\n";
    # the tempfiles_subdir() function makes and chmods the given
    # directory.  with no arguments, will make and chmod the main
    # tempfiles directory
    my $temp_subdir = Path::Class::Dir->new( $c->path_to( $c->get_conf('tempfiles_subdir') ) );
    my $temp_base   = $c->tempfiles_base;

    print STDERR "TEMP_SUBDIR: $temp_subdir\n";
    print STDERR "TEMP_BASE: $temp_base\n";
    

    # if clear_tempfiles_on_restart, attempt to delete our temp_base dir
    if( $c->config->{clear_tempfiles_on_restart} ) {
        $c->log->debug("clear_tempfiles_on_restart set, cleaning $temp_base") if $c->debug;
        rmtree( [ $temp_base ] );
        if( -e $temp_base ) {
            $c->log->warn(
                "WARNING: clear_tempfiles_on_restart set, but failed to completely clean out tempfiles_base '$temp_base':\n"
                .`find '$temp_base' -ls`
               );
        }
    }

    print STDERR "symlinking tempfiles_base '$temp_base' -> legacy location '$temp_subdir'\n";
    $c->make_generated_dir($temp_base);

    # Only symlink if it doesn't exist already
    unless( -l $temp_subdir ) {
        symlink $temp_base, $temp_subdir or warn "ERROR! $! linking $temp_base => $temp_subdir";
    }
    else { 
	print STDERR "$temp_subdir successfully linked to $temp_base\n";
    }

#     unless( $temp_subdir eq $temp_base ) {
#         $c->log->warn("WARNING: symlinking tempfiles_subdir() $temp_subdir to $temp_base");
#         unlink $temp_subdir;
#         symlink $temp_subdir, $temp_base
#             or die "$! symlinking $temp_subdir => $temp_base";
#     }

    $c->chown_generated_dir( $temp_base ); #< force-set the
                                             # permissions on the
                                             # main tempfiles dir

    # also chown any subdirs that are in the temp dir.
    # this line should be removed eventually, the application itself should take
    # care of creating temp dirs if it wants.
    $c->chown_generated_dir( $_ ) for grep -d, $temp_base->children;

};

=head2 generated_file_uri

  Usage: my $dir = $c->generated_file_uri('align_viewer','temp-aln-foo.png');
  Desc : get a URI for a file in this site's web-server-accessible
         tempfiles directory, relative to the site's base dir.  Use
         $c->path_to() to convert it to an absolute path if
         necessary
  Args : path components to append to the base temp dir, just
         like the args taken by File::Spec->catfile()
  Ret : path to the file relative to the site base dir.  includes the
        leading slash.
  Side Effects: attempts to create requested directory if does not
                exist.  dies on error

  Example:

    my $temp_rel = $c->generated_file_uri('align_viewer','foo.txt')
    # might return
    /documents/tempfiles/align_viewer/foo.txt
    # and then you might do
    $c->path_to( $temp_rel );
    # to get something like
    /data/local/cxgn/core/sgn/documents/tempfiles/align_viewer/foo.txt

=cut

sub generated_file_uri {
  my ( $self, @components ) = @_;

  @components
      or croak 'must provide at least one path component to generated_file_uri';

  my $filename = pop @components;

  my $dir = $self->tempfiles_subdir( @components );

  return URI->new( "$dir/$filename" );
}


=head2 tempfile

  Usage   : $c->tempfile( TEMPLATE => 'align_viewer/bar-XXXXXX',
                          UNLINK => 0 );
  Desc    : a wrapper for File::Temp->new(), to make web-accessible temp
            files.  Just runs the TEMPLATE argument through
            $c->generated_file_uri().  TEMPLATE can be either just a
            filename, or an arrayref of path components.
  Returns : a L<File::Temp> object
  Args    : same arguments as File::Temp->new(), except:

              - TEMPLATE is relative to the site tempfiles base path,
                  and can be an arrayref of path components,
              - UNLINK defaults to 0, which means that by default
                  this temp file WILL NOT be automatically deleted
                  when it goes out of scope
  Side Eff: dies on error, attempts to create the tempdir if it does
            not exist.
  Example :

    my ($aln_file, $aln_uri) = $c->tempfile( TEMPLATE =>
                                               ['align_viewer',
                                                'aln-XXXXXX'
                                               ],
                                             SUFFIX   => '.png',
                                           );
    render_image( $aln_file );
    print qq|Alignment image: <img src="$aln_uri" />|;

=cut

sub tempfile {
  my ( $self, %args ) = @_;

  $args{UNLINK} = 0 unless exists $args{UNLINK};

  my @path_components = ref $args{TEMPLATE} ? @{$args{TEMPLATE}}
                                            : ($args{TEMPLATE});

  my $uri = $self->generated_file_uri( @path_components );

  my $temp = File::Temp->new( %args,
                              # override TEMPLATE with abs path
                              TEMPLATE => '' . $self->path_to( $uri ),
                             );

  # replace the XXXXs in the URI template
  ( my $temp_regex = "$uri" ) =~ s/(X+)$/'(\w{'.length($1).'})'/e;
  my ($uniq_chars) = "$temp" =~ /$temp_regex/;
  my $new_uri = "$uri";
  $new_uri =~ s/X+$/$uniq_chars/ or die;
  $new_uri .= $args{SUFFIX} if defined $args{SUFFIX};

  return ( $temp, URI->new( $new_uri ) );
}

=head2 tempfiles_subdir

  Usage: my $dir = $page->tempfiles_subdir('some','dir');
  Desc : get a URI for this site's web-server-accessible tempfiles directory.
  Args : (optional) one or more directory names to append onto the tempdir root
  Ret  : path to dir, relative to doc root, include the leading slash
  Side Effects: attempts to create requested directory if does not exist.  dies on error
  Example:

    $page->tempfiles_subdir('foo')
    # might return
    /documents/tempfiles/foo

=cut

sub tempfiles_subdir {
  my ( $self, @dirs ) = @_;

  my $temp_base = $self->get_conf('tempfiles_subdir')
      or die 'no tempfiles_subdir conf var defined!';

  my $dir =  File::Spec->catdir( $temp_base, @dirs );

  my $abs = $self->path_to($dir);
  -d $abs
      or $self->make_generated_dir( $abs )
      or warn "tempfiles dir '$abs' does not exist, and could not create ($!)";

  -w $abs
      or $self->chown_generated_dir( $abs )
      or warn "could not change permissions of tempdir abs, and '$abs' is not writable.";

  $dir = "/$dir" unless $dir =~ m!^/!;

  return $dir;
}

sub tempfiles_base {
    my $self = shift;
    return Path::Class::Dir->new( $self->config->{tempfiles_base} || $self->_default_temp_base );
}

# make a path like /tmp/www-data/SGN-site
sub _default_temp_base {
    my ($self) = @_;
    return File::Spec->catdir(
        File::Spec->tmpdir,
        $self->config->{www_user},
        ($self->config->{name}.'-site' || die '"name" conf value is not set'),
       );
}

sub make_generated_dir {
    my ( $self, $tempdir ) = @_;

    eval { mkpath( readlink($tempdir) || $tempdir ); };

    if ($@) { 
	print STDERR "the following error occurred while attempting to generate $tempdir : $@ (may be ok)\n";
    }
    else { print STDERR "Successfully created dir $tempdir.\n";  }

    unless( -d $tempdir ) {
        warn "dir '$tempdir' creation failed ($!)";
        return;
    }

    $self->chown_generated_dir( $tempdir );
    return 1;
}

# takes one argument, a path in the filesystem, and chowns it appropriately
# intended only to be used here, and in SGN::Apache2::Startup
sub chown_generated_dir {
    my ( $self, $temp ) = @_;

    if ($< != 0) { 
	print STDERR "Not running as root - skipping chown of $temp.\n";
	return;
    }

    # NOTE:  $temp can be either a dir or a file

    my $www_uid = $self->_www_uid; #< this will warn if group is not set correctly
    my $www_gid = $self->_www_gid; #< this will warn if group is not set correctly

    return unless $www_uid && $www_gid;

    print STDERR "CHOWNING WITH $www_uid, $www_gid\n";

    chown $www_uid, $www_gid, $temp;

    # 02775 = sticky group bit (makes files created in that dir belong to that group),
    #         rwx for user,
    #         rwx for group,
    #         r-x for others

    # to avoid version control problems, site maintainers should just
    # be members of the www-data group
    chmod 02775, $temp;

    return 1;
}
sub _www_gid {
    my $self = shift;
    my $grname = $self->config->{www_group};
    my $gid = (getgrnam $grname )[2];
    defined $gid or warn "WARNING: www_group '$grname' does not exist, please check configuration\n";
    return $gid;
}
sub _www_uid {
    my $self = shift;
    my $uname = $self->config->{www_user};
    my $uid = (getpwnam( $uname ))[2];
    defined $uid or warn "WARNING: www_user '$uname' does not exist, please check configuration\n";
    return $uid;
}

=head2 uri_for_file

  Usage: $page->uri_for_file( $absolute_file_path );
  Desc : for a file on the filesystem, get the URI for clients to
         access it
  Args : absolute file path in the filesystem
  Ret  : L<URI> object
  Side Effects: dies on error

  This is intended to be similar to Catalyst's $c->uri_for() method,
  to smooth our transition to Catalyst.

=cut

sub uri_for_file {
    my ( $self, @abs_path ) = @_;

    my $abs = File::Spec->catfile( @abs_path );
    $abs = Cwd::realpath( $abs );

    my $basepath = $self->get_conf('basepath')
      or die "no base path conf variable defined";
    -d $basepath or die "base path '$basepath' does not exist!";
    $basepath = Cwd::realpath( $basepath );

    $abs =~ s/^$basepath//;
    $abs =~ s!\\!/!g;

    return URI->new($abs);
}

=head2 site_cluster_shared_dir

 Usage:      my $dir = $c->site_cluster_shared_dir();
 Desc:        based on the hostname, formulates  the site-specific subdir that is cluster shareable.
 Ret:          the absolute path to site-specific subdir in the cluster shareable dir.
 Args:       none
 Side Effects: none
 Example:       

=cut

sub site_cluster_shared_dir { 
    my $self = shift;

    my $cluster_dir = $self->config->{cluster_shared_tempdir};
    my $host = $self->config->{main_production_site_url}; 
    $host    =~ s/(https?)|(:\d+)|\/|://g;
    $host    =~ s/(www\.)//;
    my $host_dir    = File::Spec->catdir($cluster_dir, $host);

    return $host_dir;

}

1;
