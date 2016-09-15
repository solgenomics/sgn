package SGN::Controller::Folder;

use Moose;
use Data::Dumper;
use Try::Tiny;
use SGN::Model::Cvterm;
use Data::Dumper;
use CXGN::Trial::Folder;

BEGIN { extends 'Catalyst::Controller'; }

has 'schema' => (
    is       => 'rw',
    isa      => 'DBIx::Class::Schema',
    lazy_build => 1,
);
sub _build_schema {
    shift->_app->dbic_schema( 'Bio::Chado::Schema', 'sgn_chado' )
}

sub folder_page :Path("/folder") Args(1) {
    my $self = shift;
    my $c = shift;
    my $folder_id = shift;

    #print STDERR Dumper $folder_id;

    my $folder_project = $self->schema->resultset("Project::Project")->find( { project_id => $folder_id } );
    my $folder = CXGN::Trial::Folder->new({ bcs_schema => $self->schema, folder_id => $folder_id });

    my $children = $folder->children();
    my @crosses;
    my $cross_type_id = SGN::Model::Cvterm->get_cvterm_row($self->schema(), 'cross', 'stock_type')->cvterm_id();
    foreach (@$children) {
        if ($_->folder_type eq 'cross') {
            my $cross_stock = $self->schema->resultset("Project::Project")->search({ 'me.project_id' => $_->folder_id() })->search_related('nd_experiment_projects')->search_related('nd_experiment')->search_related('nd_experiment_stocks')->search_related('stock', {'stock.type_id'=>$cross_type_id})->first();
            if ($cross_stock) {
                push @crosses, [$cross_stock->stock_id(), $cross_stock->uniquename()];
            }
        }
    }
    #print STDERR Dumper \@crosses;

    $c->stash->{children} = $children;
    $c->stash->{crosses} = \@crosses;
    $c->stash->{project_parent} = $folder->project_parent();
    $c->stash->{breeding_program} = $folder->breeding_program();
    $c->stash->{folder_id} = $folder_id;
    $c->stash->{folder_name} = $folder_project->name();
    $c->stash->{folder_description} = $folder_project->description();
    if (!$folder->breeding_program) {
        $c->stash->{message} = "The requested folder does not exist or has been deleted.";
        $c->stash->{template} = 'generic_message.mas';
        return;
    }
    $c->stash->{template} = '/breeders_toolbox/folder/folder.mas';
}

1;
