use strict;
use CGI qw();
use CXGN::DB::DBICFactory;

our $c;
my $q = new CGI;
my %args = (
    schema => CXGN::DB::DBICFactory->open_schema('Bio::Chado::Schema')
);

# Feature types
# DNA, snRNA, scRNA, rRNA, genomic_clone, mRNA, assembly, repeat_family, protein, RNA, BAC_clone, EST

my $feature_name = $q->param('feature');

if ( defined $feature_name ) {
    my $bcs = $args{schema};
    my $matching_features = $bcs->resultset('Sequence::Feature')
                                ->search({ name => $feature_name });

    my $count = $matching_features->count;
    $c->throw( message => "too many features for $feature_name") if $count > 1;
    $c->throw( message => "feature $feature_name not found") if $count < 1;

    my $feature   = $matching_features->next;
    my $type_name = $feature->type->name;

    $c->forward_to_mason_view(
        "/feature/$type_name.mas",
        type    => $type_name,
        feature => $feature,
    );
} else {
    $c->forward_to_mason_view(
        "/feature/main.mas",
        %args
    );
}
