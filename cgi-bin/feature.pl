use strict;
use CGI qw();
use CXGN::DB::DBICFactory;
use Data::Dumper;

our $c;
my $q = new CGI;
my %args = (
    schema => CXGN::DB::DBICFactory->open_schema('Bio::Chado::Schema')
);
my $bcs = $args{schema};

# Feature types
# DNA, snRNA, scRNA, rRNA, genomic_clone, mRNA, assembly, repeat_family, protein, RNA, BAC_clone, EST

my $params = $q->Vars;

if ( $params->{id} ) {
    my $feature_id = $params->{id};
    my $matching_features = $bcs->resultset('Sequence::Feature')
                                ->search({ feature_id => $feature_id });
    validate($matching_features, feature_id => $feature_id );
    delegate_component($matching_features);

} elsif ( $params->{name} ) {
    my $feature_name = $params->{name};
    my $matching_features = $bcs->resultset('Sequence::Feature')
                                ->search({ name => $feature_name });

    validate($matching_features,feature_name => $feature_name);
    delegate_component($matching_features);

} else {
    $c->forward_to_mason_view(
        "/feature/main.mas",
        %args
    );
}

sub validate
{
    my ($matching_features,$key, $val) = @_;
    my $count = $matching_features->count;
#   EVIL HACK: We need a disambiguation process before merging
#   $c->throw( message => "too many features where $key='$val'") if $count > 1;
    $c->throw( message => "feature with $key='$val' not found") if $count < 1;
}
sub delegate_component
{
    my ($matching_features) = @_;
    my $feature   = $matching_features->next;
    my @children  = $feature->child_features;
    my @parents   = $feature->parent_features;
    my $type_name = $feature->type->name;

    $c->forward_to_mason_view(
        "/feature/$type_name.mas",
        type    => $type_name,
        feature => $feature,
        children=> \@children,
        parents => \@parents,
    );

}
