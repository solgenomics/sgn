use strict;
use warnings;
use lib 't/lib';
use Test::More;
use File::Temp qw(tempdir);
use JSON ();
use SGN::Test::Fixture;
use CXGN::Trial::TrialCreate;
use CXGN::Phenotypes::ParseUpload::Plugin::Observations;
use CXGN::Phenotypes::StorePhenotypes;

my $f=SGN::Test::Fixture->new;
my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $dir=tempdir(CLEANUP=>1);
my $prefix="audit_unit_name_identity_$$";
my $name="${prefix}_shared_plot";
my $parser=CXGN::Phenotypes::ParseUpload::Plugin::Observations->new;
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 my $organism=$s->resultset('Organism::Organism')->create({genus=>'Audit',species=>$prefix});
 my $accession=$s->resultset('Stock::Stock')->create({name=>"${prefix}_accession",uniquename=>"${prefix}_accession",organism_id=>$organism->organism_id,type_id=>$template->type_id});
 my @ids;
 for my $i (1..2) {
  # Native trial creation supplies complete supported layout metadata first.
  my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_trial_$i",trial_description=>'Rollback-only explicit observation-unit identity test',trial_year=>2030,design_type=>'CRD',design=>{1=>{plot_name=>"${prefix}_plot_$i",plot_number=>1,stock_name=>$i==1 ? 'test_accession1' : $accession->uniquename,block_number=>1,rep_number=>1,row_number=>1,col_number=>1}}})->save_trial;
  die 'Native trial fixture setup failed' if !$created->{trial_id};
  my $plot=$s->resultset('Stock::Stock')->find({uniquename=>"${prefix}_plot_$i"});push @ids,$plot->stock_id;
  # Chado's actual stock constraint permits equal names for different organisms.
  # Simulate that valid stored state; no existing fixture stock is changed.
  $plot->update({uniquename=>$name,name=>$name});
 }
 is($dbh->selectrow_array('SELECT count(*) FROM stock WHERE uniquename=?',undef,$name),2,'two distinct IDs share the permitted name across different organisms');
 for my $i (0..1) {
  $s->txn_begin;
  my $parsed=$parser->parse([{observationUnitDbId=>"$ids[$i]",observationVariableDbId=>'70666',value=>'23',observationTimeStamp=>'2030-11-03T10:00:00Z'}],1,'stocks',$s,undef,'janedoe',undef,undef,undef);
  like($parsed->{error}||'',qr/ambiguous|more than one|multiple.*name/i,'explicit unit ID with ambiguous storage name is refused before name-keyed storage');
  if (!$parsed->{error}) {
   my $accepted=eval {
   my $store=CXGN::Phenotypes::StorePhenotypes->new({basepath=>$f->config->{basepath},dbhost=>$f->config->{dbhost},dbname=>$f->config->{dbname},dbuser=>$f->config->{dbuser},dbpass=>$f->config->{dbpass},temp_file_nd_experiment_id=>"$dir/exp_$i",bcs_schema=>$s,metadata_schema=>$f->metadata_schema,phenome_schema=>$f->phenome_schema,user_id=>41,stock_list=>$parsed->{units},trait_list=>$parsed->{variables},values_hash=>$parsed->{data},has_timestamps=>1,overwrite_values=>0,metadata_hash=>{operator=>'janedoe',date=>'2030-11-03_12:00:00'},composable_validation_check_name=>$f->config->{composable_validation_check_name}});
   my($warning,$error)=$store->verify;die "Fixture verification failed: $error" if $error;
   my($store_error)=$store->store;die "Actual Store failed: $store_error" if $store_error;
   1;
   };my $storage_exception=$@;
   my $actual=$dbh->selectcol_arrayref('SELECT DISTINCT stock_id FROM phenotype JOIN nd_experiment_phenotype USING(phenotype_id) JOIN nd_experiment_stock USING(nd_experiment_id) WHERE stock_id=ANY(?) AND cvalue_id=70666',undef,\@ids);
   if ($accepted) {
    is_deeply([sort {$a<=>$b} @$actual],[$ids[$i]],'any accepted new observation is stored only against the addressed stock ID');
   } else {
    like($storage_exception,qr/more than one|ambiguous/i,'existing owner guard refused ambiguous name during storage preparation');
    is(scalar(@$actual),0,'ambiguous-name failure did not write any observation');
   }
   diag(JSON::encode_json({requested=>$ids[$i],actual=>$actual,name=>$name,storage_exception=>$storage_exception}));
  }
  $s->txn_rollback;
 }
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'explicit-ID ambiguity scenario completed and all fixtures rolled back') or diag($error);
done_testing;
