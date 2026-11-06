use strict;use warnings;use Test::More;use JSON ();use Bio::Chado::Schema;use CXGN::Metadata::Schema;use CXGN::Phenome::Schema;use CXGN::People::Schema;use CXGN::BrAPI::v1::Observations;use CXGN::BrAPI::v2::Observations;
# The owning read adapter must pass the same live SQL policy for JSON booleans
# and query-string booleans. Any attempted database access fails this unit test.
sub schema {$_[0]->connect(sub {die 'Read flag contract must not access a database'})}
my %args=(bcs_schema=>schema('Bio::Chado::Schema'),metadata_schema=>schema('CXGN::Metadata::Schema'),phenome_schema=>schema('CXGN::Phenome::Schema'),people_schema=>schema('CXGN::People::Schema'),page=>0,page_size=>10,status=>[]);
{package FlagPolicyNative;sub search {return([],[])}} ## no critic (Modules::RequireFilenameMatchesPackage) -- This test embeds its named test double beside the assertions.
my $exclude;
no warnings 'redefine';
local *CXGN::Phenotypes::SearchFactory::instantiate=sub {my($class,$engine,$params)=@_;$exclude=$params->{exclude_rejected};return bless{},'FlagPolicyNative'};
for my $version(qw(v1 v2)) {
 my$class="CXGN::BrAPI::${version}::Observations";
 for my$case ([undef,1,'default'],['true',0,'query-string true'],[JSON::true,0,'JSON true'],[JSON::false,1,'JSON false']) {
  my$m=$class->new({%args,context=>undef,status=>[]});$exclude=undef;
  my$r=$m->search({defined($case->[0])?(includeRejected=>$case->[0]):()});
  is($exclude,$case->[1],"$version $case->[2] selects the expected rejection policy");
 }
}
done_testing;
