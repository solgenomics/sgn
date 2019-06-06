
package SGN::Controller::AJAX::Search::Image;

use Moose;

BEGIN { extends 'Catalyst::Controller::REST' }

use Data::Dumper;
use JSON;
use CXGN::Image::Search;

__PACKAGE__->config(
    default   => 'application/json',
    stash_key => 'rest',
    map       => { 'application/json' => 'JSON', 'text/html' => 'JSON' },
   );


sub image_search :Path('/ajax/search/images') Args(0) {
    my $self = shift;
    my $c = shift;
    print STDERR "Image search AJAX\n";
    my $schema = $c->dbic_schema("Bio::Chado::Schema", 'sgn_chado');
    my $people_schema = $c->dbic_schema("CXGN::People::Schema");
    my $phenome_schema = $c->dbic_schema("CXGN::Phenome::Schema");
    my $params = $c->req->params() || {};
    #print STDERR Dumper $params;

    my $owner_first_name;
    my $owner_last_name;
    if (exists($params->{image_person} ) && $params->{image_person} ) {
        my $editor = $params->{image_person};
        my @split = split ',' , $editor;
        $owner_first_name = $split[0];
        $owner_last_name = $split[1];
        $owner_first_name =~ s/\s+//g;
        $owner_last_name =~ s/\s+//g;
    }

    my $rows = $params->{length};
    my $offset = $params->{start};
    my $limit = defined($offset) && defined($rows) ? ($offset+$rows)-1 : undef;

    my $image_search = CXGN::Image::Search->new({
        bcs_schema=>$schema,
        people_schema=>$people_schema,
        phenome_schema=>$phenome_schema,
        limit=>$limit,
        offset=>$offset,
    });
    my ($result, $records_total) = $image_search->search();

    my $draw = $params->{draw};
    if ($draw){
        $draw =~ s/\D//g; # cast to int
    }

    print STDERR Dumper $result;
    my @return;
    foreach (@$result){
    }

    #print STDERR Dumper \@return;
    $c->stash->{rest} = { data => [ @return ], draw => $draw, recordsTotal => $records_total,  recordsFiltered => $records_total };
}

1;
