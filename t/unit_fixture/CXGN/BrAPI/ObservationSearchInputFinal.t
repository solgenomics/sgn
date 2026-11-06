use strict;use warnings;use lib 't/lib';use Test::More;use SGN::Test::Fixture;use CXGN::BrAPI::JSONResponse;use CXGN::Phenotypes::SearchFactory;use CXGN::BrAPI::v1::Observations;use CXGN::BrAPI::v2::Observations;
my$f=SGN::Test::Fixture->new;my$s=$f->bcs_schema;
my%args=(bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,people_schema=>$f->people_schema,page=>0,page_size=>1,status=>[]);
for my$v(qw(v1 v2)) {
 my$class="CXGN::BrAPI::${v}::Observations";my$m=$class->new({%args,context=>undef});
 for my$bad({observationDbIds=>["0'"]},{studyDbIds=>{}},{observationVariableDbIds=>['invalid']},{seasonDbIds=>['not-a-year']}) {
  $m->status([]);my$r;my$ok=eval{$r=$m->search($bad);1};ok($ok && ($r->{http_code}//0)==400,"$v invalid identifiers/shapes return a controlled error") or diag($@);
 }
 $m->status([]);my$r;my$ok=eval{$r=$m->search({observationVariableNames=>["never_matching_audit'quoted_trait"]});1};ok($ok && ref($r->{result}{data})eq'ARRAY' && @{$r->{result}{data}}==0,"$v literal quotes in trait search do not break SQL") or diag($@);
}
done_testing;
