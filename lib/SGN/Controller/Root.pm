package SGN::Controller::Root;
use Moose;
use namespace::autoclean;

use Scalar::Util 'weaken';
use CatalystX::GlobalContext ();

use CXGN::Login;
use CXGN::People::Person;
use List::MoreUtils 'uniq';
use JSON::XS;
use Data::Dumper;


BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=head1 NAME

SGN::Controller::Root - Root Controller for SGN

=head1 DESCRIPTION

Web application to run the SGN web site.

=head1 PUBLIC ACTIONS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    my $schema = $c->dbic_schema('Bio::Chado::Schema', 'sgn_chado');

    my $role;
    if ($c->user) {
	($role) = $c->user()->roles(); # get the highest role
    }
    
    if ($c->config->{homepage_display_phenotype_uploads}){
        my @file_array;
        my %file_info;
        my $q = "SELECT file_id, m.create_date, p.sp_person_id, p.username, basename, dirname, filetype, project_id, project.name FROM nd_experiment_project JOIN project USING(project_id) JOIN nd_experiment_phenotype USING(nd_experiment_id) JOIN phenome.nd_experiment_md_files ON (nd_experiment_phenotype.nd_experiment_id=nd_experiment_md_files.nd_experiment_id) LEFT JOIN metadata.md_files using(file_id) LEFT JOIN metadata.md_metadata as m using(metadata_id) LEFT JOIN sgn_people.sp_person as p ON (p.sp_person_id=m.create_person_id) WHERE m.obsolete = 0 and NOT (metadata.md_files.filetype='generated from plot from plant phenotypes') and NOT (metadata.md_files.filetype='direct phenotyping')";
        my $h = $schema->storage()->dbh()->prepare($q);
        $h->execute();

        while (my ($file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype, $project_id, $project_name) = $h->fetchrow_array()) {
            $file_info{$file_id}->{project_ids}->{$project_id} = $project_name;
            $file_info{$file_id}->{metadata} = [$file_id, $create_date, $person_id, $username, $basename, $dirname, $filetype, $project_id];
        }
        foreach (sort {$b <=> $a} keys %file_info){
            push @file_array, $file_info{$_};
        }
        #print STDERR Dumper \@file_array;
        $c->stash->{phenotype_files} = \@file_array;
    }

    my $projects = CXGN::BreedersToolbox::Projects->new( { schema=> $schema } );
    my $breeding_programs = $projects->get_breeding_programs();
    $c->stash->{locations} = $projects->get_location_geojson_data();
    $c->stash->{breeding_programs} = $breeding_programs;
    $c->stash->{preferred_species} = $c->config->{preferred_species};
    $c->stash->{timestamp} = localtime;

    my @editable_stock_props = split ',', $c->config->{editable_stock_props};
    my %editable_stock_props = map { $_=>1 } @editable_stock_props;
    $c->stash->{editable_stock_props} = \%editable_stock_props;

    my @editable_stock_props_definitions = split ',', $c->config->{editable_stock_props_definitions};
    my %def_hash;
    foreach (@editable_stock_props_definitions) {
        my @term_def = split ':', $_;
        $def_hash{$term_def[0]} = $term_def[1];
    }
    $c->stash->{editable_stock_props_definitions} = \%def_hash;

    my $genotyping_facilities = $c->config->{genotyping_facilities};
    my @facilities = split ',',$genotyping_facilities;
    $c->stash->{facilities} = \@facilities;

    my $field_management_factors = $c->config->{management_factor_types};
    my @management_factor_types = split ',',$field_management_factors;
    $c->stash->{management_factor_types} = \@management_factor_types;

    my $design_type_string = $c->config->{design_types};
    my @design_types = split ',',$design_type_string;
    $c->stash->{design_types} = \@design_types;

    $c->stash->{schema}   = $c->dbic_schema('SGN::Schema');
    $c->stash->{static_content_path} = $c->config->{static_content_path};

    if ($c->user() && $c->config->{personalized_homepage} == 1) {
	my $user = $c->user()->get_object();
	$c->stash->{username} = $user->get_username();
	$c->stash->{first_name} = $user->get_first_name();
	$c->stash->{last_name} = $user->get_last_name();
	$c->stash->{sp_person_id} = $user->get_sp_person_id();
	$c->stash->{template} = '/index_logged_in_user.mas';
	$c->stash->{role} = $role;
    }
    else { 
	$c->stash->{template} = '/index.mas';
    }
 
}

=head2 default

Attempt to find index.pl pages, and prints standard 404 error page if
nothing could be found.

=cut

sub default :Path {
    my ( $self, $c ) = @_;

    return 1 if $c->forward('/redirects/find_redirect');

    $c->throw_404;
}

=head2 bare_mason

Render a bare mason component, with no autohandler wrapping.
Currently used for GBrowse integration (GBrowse makes a subrequest for
the mason header and footer).

=cut

sub bare_mason :Path('bare_mason') {
    my ( $self, $c, @args ) = @_;

    # figure out our template path
    my $t = File::Spec->catfile( @args );
    $t .= '.mas' unless $t =~ m|\.[^/\\\.]+$|;
    $c->stash->{template} = $t;

    # TODO: check that it exists

    $c->forward('View::BareMason');
}

=head1 PRIVATE ACTIONS

=head2 end

Attempt to render a view, if needed.

=cut

sub render : ActionClass('RenderView') { }
sub end : Private {
    my ( $self, $c ) = @_;

    return if @{$c->error};

    # don't try to render a default view if this was handled by a CGI
    $c->forward('render') unless $c->req->path =~ /\.pl$/;

    # enforce a default text/html content type regardless of whether
    # we tried to render a default view
    $c->res->content_type('text/html') unless $c->res->content_type;

    if( $c->res->content_type eq 'text/html' ) {
        # insert any additional header html collected during rendering
        $c->forward('insert_collected_html');

        # tell caches our responses vary depending on the Cookie header
        $c->res->headers->push_header('Vary', 'Cookie');
    } else {
        $c->log->debug("skipping JS pack insertion for page with content type ".$c->res->content_type)
            if $c->debug;
    }

}

sub insert_collected_html :Private {
    my ( $self, $c ) = @_;

    $c->forward('/js/resolve_javascript_classes');
    $c->forward('resolve_css_paths');

    my $b = $c->res->body;
    my $inserted_head_pre  = $b && $b =~ s{<!-- \s* INSERT_HEAD_PRE_HTML \s* --> }{ $self->_make_head_pre_html( $c )  }ex;
    my $inserted_head_post = $b && $b =~ s{<!-- \s* INSERT_HEAD_POST_HTML \s* -->}{ $self->_make_head_post_html( $c ) }ex;
    if( $inserted_head_pre || $inserted_head_post ) {
      $c->res->body( $b );

      # we have changed the size of the body.  remove the
      # content-length and let catalyst recalculate the content-length
      # if it can
      $c->res->headers->remove_header('content-length');

      delete $c->stash->{$_} for qw( add_head_html add_css_files add_js_classes );
  }
}

sub _make_head_pre_html {
    my ( $self, $c ) = @_;
    return join "\n", (
        @{ $c->stash->{head_pre_html} || [] },
        ( map {
            qq{<link rel="stylesheet" type="text/css" href="$_" />}
          } @{ $c->stash->{css_uris} || [] }
        ),
    );
}

sub _make_head_post_html {
    my ( $self, $c ) = @_;

    my $head_post_html = join "\n", (
        @{ $c->stash->{add_head_html} || [] },
        ( map {
            qq{<script src="$_" type="text/javascript"></script>}
          } @{ $c->stash->{js_uris} || [] }
        ),
    );

    return $head_post_html;
}

=head2 auto

Run for every request to the site.



=cut

sub auto : Private {
    my ($self, $c) = @_;
    CatalystX::GlobalContext->set_context( $c );
    $c->stash->{c} = $c;
    weaken $c->stash->{c};

    # gluecode for logins
    #
    unless( $c->config->{'disable_login'} ) {
        my $dbh = $c->dbc->dbh;
        if ( my $sp_person_id = CXGN::Login->new( $dbh )->has_session ) {
            #For audit system
            $dbh->do("CREATE temporary table IF NOT EXISTS logged_in_user (sp_person_id bigint)");

	    my $already_there_q = "SELECT sp_person_id FROM logged_in_user where sp_person_id=?";
	    my $already_there_h = $dbh->prepare($already_there_q);
	    $already_there_h->execute($sp_person_id);
	    my ($already_there) = $already_there_h->fetchrow_array();
	    if (!$already_there) {
		print STDERR "inserting $sp_person_id\n";
		my $insert_query = "INSERT INTO logged_in_user (sp_person_id) VALUES (?)";
		my $insert_handle = $dbh->prepare($insert_query);
		$insert_handle->execute($sp_person_id);
	    }
            my $count_q = "select count(*) from logged_in_user";
            my $count_h = $dbh -> prepare($count_q);
            $count_h -> execute();
            my ($count) = $count_h->fetchrow_array();
            # print STDERR "count: $count \n";

            my $logged_in_user_q = "select * from logged_in_user";
            my $logged_in_user_h = $dbh -> prepare($logged_in_user_q);
            $logged_in_user_h->execute();
            my $logged_in_user_arr = $logged_in_user_h->fetchall_arrayref();
            # print STDERR "logged in user in Root.pm: ".Dumper($logged_in_user_arr)."\n";

            my $sp_person = CXGN::People::Person->new($dbh, $sp_person_id);

            $c->authenticate({
                username => $sp_person->get_username(),
                password => $sp_person->get_password(),
            });
        }
    }

    return 1;
}


=head2 resolve_css_paths

    Compiles list of CSS files added by mason/import_css.mas

=cut

sub resolve_css_paths :Private {
    my ( $self, $c ) = @_;

    my $files = $c->stash->{css_paths}
        or return;

    my @files = uniq @{$files}; #< do not sort, load order might be important
    # assume paths are relative to /static/css/ if they are not absolute paths or urls
    for (@files) {
        s!^([^/])!/static/css/$1! if !(/^(.*?:\/)/);
    }

    $c->stash->{css_uris} = \@files;
}


############# helper methods ##########

sub _find_cgi_action {
    my ($self,$c,$path) = @_;

    $path =~ s!/+!/!g;
     my $cgi = $c->controller('CGI')
         or return;

    my $index_action = $cgi->cgi_action_for( $path )
        or return;

    $c->log->debug("found CGI index action '$index_action'") if $c->debug;

    return $index_action;
}

=head1 AUTHOR

Robert Buels, Jonathan "Duke" Leto

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
