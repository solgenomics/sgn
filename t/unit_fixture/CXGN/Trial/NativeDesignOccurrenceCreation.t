use strict;
use warnings;
use lib 't/lib';
use Test::More;
use JSON ();
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::TrialDesign;
use CXGN::Trial::TrialCreate;
use CXGN::Trial::AccessionChange;
use CXGN::Trial::DesignReplication;

# Actual native TrialDesign plugins execute agricolae through YapRI, and the
# returned book is passed unchanged to TrialCreate. No fabricated Alpha/Lattice
# grouping, fallback design, or synthetic replacement of the generator is used.
my $f=SGN::Test::Fixture->new;my $s=$f->bcs_schema;my $dbh=$s->storage->dbh;
$s->storage->auto_savepoint(1);
my $prefix='audit_native_design_occurrence_'.$$;my %types;
sub term {my($n,$cv)=@_;return $types{"$cv/$n"} ||= SGN::Model::Cvterm->get_cvterm_row($s,$n,$cv)->cvterm_id}
sub prop {my($id,$name)=@_;my $r=$s->resultset('Stock::Stockprop')->find({stock_id=>$id,type_id=>term($name,'stock_property'),rank=>0});return $r ? $r->value : undef}
sub accession {my($plot)=@_;return $s->resultset('Stock::StockRelationship')->find({subject_id=>$plot,type_id=>term('plot_of','stock_relationship')})->object_id}
sub physical_rows {my($ids)=@_;return $dbh->selectall_arrayref('SELECT stock_id,type_id,value,rank FROM stockprop WHERE stock_id=ANY(?) AND type_id=ANY(?) ORDER BY stock_id,type_id,rank',undef,$ids,[map {term($_,'stock_property')} ('design_replicate','block','plot number','row_number','col_number')])}
sub assert_occurrences {
 my($ids,$label)=@_;my %by_accession;
 for my $id (@$ids) {push @{$by_accession{accession($id)}},$id}
 my(@actual,@expected);
 for my $stock (sort {$a<=>$b} keys %by_accession) {
  my @plots=sort {prop($a,'plot number')<=>prop($b,'plot number') || $a<=>$b} @{$by_accession{$stock}};
  push @actual,map {prop($_,'replicate')} @plots;push @expected,1..scalar(@plots);
 }
 is_deeply(\@actual,\@expected,$label);
}
sub pool_sample {
 my($trial,$name,$parents,$stock)=@_;
 my $template=$s->resultset('Stock::Stock')->find($stock);
 my $sample=$s->resultset('Stock::Stock')->create({name=>$name,uniquename=>$name,organism_id=>$template->organism_id,type_id=>term('tissue_sample','stock_type')});
 for my $parent (@$parents) {$sample->create_related('stock_relationship_subjects',{object_id=>$parent,type_id=>term('tissue_sample_of','stock_relationship')})}
 $sample->create_related('stock_relationship_subjects',{object_id=>$stock,type_id=>term('tissue_sample_of','stock_relationship')});
 my($experiment)=$dbh->selectrow_array('SELECT ne.nd_experiment_id FROM nd_experiment ne JOIN nd_experiment_project nep USING(nd_experiment_id) WHERE nep.project_id=? AND ne.type_id=?',undef,$trial,term('field_layout','experiment_type'));
 $sample->create_related('nd_experiment_stocks',{nd_experiment_id=>$experiment,type_id=>term('field_layout','experiment_type')});
 $sample->create_related('stockprops',{type_id=>term('replicate','stock_property'),value=>77,rank=>0});
 CXGN::Trial::DesignReplication::set($s,$sample->stock_id,undef);
 return $sample->stock_id;
}
sub sample_accessions {my($id)=@_;return $dbh->selectcol_arrayref('SELECT DISTINCT r.object_id FROM stock_relationship r JOIN stock o ON o.stock_id=r.object_id WHERE r.subject_id=? AND r.type_id=? AND o.type_id=? ORDER BY r.object_id',undef,$id,term('tissue_sample_of','stock_relationship'),term('accession','stock_type'))}
my $tx=0;END {eval{$s->txn_rollback if $tx} if $s}
$s->txn_begin;$tx=1;
my $ran=eval {
 $s->resultset('Cv::Cvterm')->create_with({name=>'design_replicate',cv=>'stock_property',definition=>'Recorded physical replication tag'});
 $s->resultset('Cv::Cvterm')->create_with({name=>'accession_occurrence_version',cv=>'project_property',definition=>'Whole-field occurrence conversion version'});
 my $template=$s->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});my @stocks;
 for my $i (1..16) {$stocks[$i-1]=$s->resultset('Stock::Stock')->create({name=>"${prefix}_A$i",uniquename=>"${prefix}_A$i",organism_id=>$template->organism_id,type_id=>$template->type_id})}
 for my $config (['Alpha',12,3,3,12],['Lattice',16,3,undef,12],['RCBD',4,2,undef,2],['CRD',4,3,undef,3]) {
  my($kind,$n,$repetitions,$block_size,$rows)=@$config;
  next if $ENV{AUDIT_NATIVE_DESIGN} && $ENV{AUDIT_NATIVE_DESIGN} ne $kind;
  subtest "actual native $kind generation, storage and accession merge"=>sub {
   $s->txn_begin;
   my $ok=eval {
    my $trial_name="${prefix}_$kind";my @names=map {$_->uniquename} @stocks[0..$n-1];
    my $generator=CXGN::Trial::TrialDesign->new;
    $generator->set_trial_name($trial_name);$generator->set_stock_list(\@names);$generator->set_design_type($kind);
    $generator->set_number_of_reps($repetitions);$generator->set_number_of_blocks($repetitions) if $kind eq 'RCBD';
    $generator->set_block_size($block_size) if defined($block_size);
    $generator->set_plot_start_number(1);$generator->set_plot_number_increment(1);$generator->set_plot_numbering_scheme('consecutive');
    $generator->set_plot_layout_format('serpentine');$generator->set_fieldmap_row_number($rows);$generator->set_randomization_seed(20261103);
    ok($generator->calculate_design,'native generator completed') or die 'Actual generator failed';
    my $design=$generator->get_design;is(scalar(keys %$design),$n*$repetitions,'actual book has the legal treatment-by-replication size');
    my %book=map {my $entry=$design->{$_};($entry->{plot_name}=>{map {$_=>$entry->{$_}} qw(stock_name rep_number block_number plot_number row_number col_number)})} keys %$design;
    ok(!(grep {!defined($_->{rep_number}) || !defined($_->{block_number})} values %book),'actual book provides explicit recorded group and block for every plot');
    if ($kind eq 'Alpha' || $kind eq 'Lattice') {
     my %groups;for my $entry(values %book){$groups{$entry->{rep_number}}{$entry->{block_number}}++}
     is(scalar(keys %groups),$repetitions,'actual incomplete-block book contains the declared true replication groups');
     ok(!(grep {scalar(keys %{$groups{$_}})<2} keys %groups),'every actual replication group contains multiple blocks');
    }
    diag(JSON::encode_json({generator=>$kind,treatments=>$n,repetitions=>$repetitions,block_size=>$block_size,seed=>20261103,source=>'CXGN::Trial::TrialDesign native plugin / agricolae'}));
    my $created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>$trial_name,trial_year=>2031,trial_description=>'Actual native generator occurrence/design regression',design_type=>$kind,design=>$design})->save_trial;
    my $trial=$created->{trial_id};ok($trial,'actual generator book stored') or die 'Native store failed';
    my @plots=map {$s->resultset('Stock::Stock')->find({uniquename=>$_})->stock_id} sort keys %book;
    my $resolved=CXGN::Trial::DesignReplication::read($s,\@plots);
    is_deeply([map {$resolved->{$_}{recorded}} @plots],[(1)x@plots],'creation records every design group before occurrence normalization');
    is_deeply([map {$resolved->{$_}{value}} @plots],[map {$book{$s->resultset('Stock::Stock')->find($_)->uniquename}{rep_number}} @plots],'stored design groups exactly match the actual native book');
    is_deeply([map {prop($_,'block')} @plots],[map {$book{$s->resultset('Stock::Stock')->find($_)->uniquename}{block_number}} @plots],'stored blocks exactly match the actual native book');
    is_deeply([map {$resolved->{$_}{occurrence_ready}} @plots],[(1)x@plots],'native field creation completes occurrence cutover');
    assert_occurrences(\@plots,'native stored occurrences are consecutive within each accession');
    my $physical=physical_rows(\@plots);my $service=CXGN::Trial::AccessionChange->new({schema=>$s,trial_id=>$trial});
    my $changes=$service->changes_for_stock($stocks[1]->stock_id,$stocks[0]->stock_id);
    is(scalar(@$changes),$repetitions,'merge addresses the complete second native accession');
    $service->apply($changes,{curator=>1,rename_plots=>'none'});
    assert_occurrences(\@plots,'all-design correction numbers the merged final accession consecutively');
    is_deeply(physical_rows(\@plots),$physical,'merge preserves every actual native design group, block and coordinate');
    my @merged=grep {accession($_)==$stocks[0]->stock_id} @plots;
    is(scalar(@merged),2*$repetitions,'both sets of real native plots are retained');
    my %counters=map {prop($_,'replicate')=>1} @merged;
    is_deeply([sort {$a<=>$b} keys %counters],[1..2*$repetitions],'merged occurrence labels extend beyond original design replication count');
    if ($kind eq 'RCBD') {
     # A valid pooled stock graph in this real native field layout. This tests
     # actual service behavior, not public creation of a pooled sample.
     my @parents=grep {$book{$s->resultset('Stock::Stock')->find($_)->uniquename}{stock_name} eq $stocks[0]->uniquename} @plots;
     is(scalar(@parents),2,'pooled source parents are the two original A plots');
     my $pooled=pool_sample($trial,"${prefix}_pooled",\@parents,$stocks[0]->stock_id);
     my($unrelated)=grep {accession($_)==$stocks[3]->stock_id} @plots;
     my $parent_before=[map {prop($_,'replicate')} @parents];
     $service->apply([{plot_id=>$unrelated,new_stock_id=>$stocks[2]->stock_id}],{curator=>1,rename_plots=>'none'});
     is_deeply([map {prop($_,'replicate')} @parents],$parent_before,'unrelated correction leaves both source occurrence numbers unchanged');
     is(prop($pooled,'replicate'),undef,'pooled occurrence is unknown even when neither source number changed');
     my $split=eval {$service->apply([{plot_id=>$parents[0],new_stock_id=>$stocks[2]->stock_id}],{curator=>1,rename_plots=>'none'});1};
     ok(!$split,'partial source correction cannot split a pooled scalar germplasm identity');
     like($@,qr/Pooled sample.*multiple germplasm identities/,'refusal identifies the pooled provenance conflict');
     is_deeply(sample_accessions($pooled),[$stocks[0]->stock_id],'refused correction preserves the original single germplasm');
     my $roots=$dbh->selectcol_arrayref('SELECT object_id FROM stock_relationship WHERE subject_id=? AND type_id=? AND object_id=ANY(?) ORDER BY object_id',undef,$pooled,term('tissue_sample_of','stock_relationship'),\@parents);
     is_deeply($roots,[sort {$a<=>$b} @parents],'both physical source-parent relationships remain intact');
     my $group=CXGN::Trial::DesignReplication::read($s,[$pooled])->{$pooled};
     ok($group->{recorded} && !defined($group->{value}),'pooled differing design groups remain explicitly recorded unknown');
     is(prop($pooled,'replicate'),undef,'pooled counter is not arbitrarily assigned from either changed parent');
     $service->apply([map {{plot_id=>$_,new_stock_id=>$stocks[2]->stock_id}} @parents],{curator=>1,rename_plots=>'none'});
     is_deeply(sample_accessions($pooled),[$stocks[2]->stock_id],'a coherent all-parent correction retains one final sample identity');
     # A fresh child may directly belong only to this trial but have a second
     # source in another actual native field. Equal tag text across studies
     # is not one physical group, including after the main trial cutover.
     my $other_generator=CXGN::Trial::TrialDesign->new;
     $other_generator->set_trial_name("${prefix}_other_native_field");$other_generator->set_stock_list([map {$_->uniquename} @stocks[0..3]]);
     $other_generator->set_design_type('RCBD');$other_generator->set_number_of_blocks(2);$other_generator->set_number_of_reps(2);
     $other_generator->set_randomization_seed(20261104);$other_generator->set_plot_start_number(1);$other_generator->set_plot_number_increment(1);
     $other_generator->set_plot_numbering_scheme('consecutive');$other_generator->set_plot_layout_format('serpentine');$other_generator->set_fieldmap_row_number(2);
     ok($other_generator->calculate_design,'second source field is also generated by the actual native RCBD plugin') or die 'Second native source generator failed';
     my $other_design=$other_generator->get_design;
     my $other_created=CXGN::Trial::TrialCreate->new({chado_schema=>$s,dbh=>$dbh,owner_id=>41,operator=>'janedoe',program=>'test',trial_location=>'test_location',trial_name=>"${prefix}_other_native_field",trial_year=>2031,trial_description=>'Independent actual native source field',design_type=>'RCBD',design=>$other_design})->save_trial;
     ok($other_created->{trial_id},'second native source field stored') or die 'Second native source field failed';
     my $first_group=CXGN::Trial::DesignReplication::read($s,[$parents[0]])->{$parents[0]}{value};
     my($other_entry)=grep {$_->{stock_name} eq $stocks[2]->uniquename && $_->{rep_number} eq $first_group} values %$other_design;
     die 'No matching native source group' if !$other_entry;
     my $other_plot=$s->resultset('Stock::Stock')->find({uniquename=>$other_entry->{plot_name}})->stock_id;
     is(CXGN::Trial::DesignReplication::read($s,[$other_plot])->{$other_plot}{value},$first_group,'both actual source books use the same recorded tag text');
     my $cross=pool_sample($trial,"${prefix}_fresh_cross_field_pool",[$parents[0],$other_plot],$stocks[2]->stock_id);
     $s->resultset('Stock::Stockprop')->search({stock_id=>$cross,type_id=>term('design_replicate','stock_property')})->delete;
     my $before_cross=CXGN::Trial::DesignReplication::read($s,[$cross])->{$cross};
     is_deeply($before_cross->{field_projects},[$trial],'fresh pooled stock directly belongs only to the first field layout');
     ok(!$before_cross->{recorded} && $before_cross->{missing_after_cutover},'fresh pool has no recorded snapshot after the main field cutover');
     my($remaining_d)=grep {accession($_)==$stocks[3]->stock_id} @plots;
     die 'Missing unrelated remaining D plot' if !defined($remaining_d);
     $service->apply([{plot_id=>$remaining_d,new_stock_id=>$stocks[2]->stock_id}],{curator=>1,rename_plots=>'none'});
     my $cross_state=CXGN::Trial::DesignReplication::read($s,[$cross])->{$cross};
     ok($cross_state->{recorded},'normalization records a snapshot for the fresh pooled descendant');
     is($cross_state->{value},undef,'identical source tag text across different fields is recorded unknown, never guessed');
     is(prop($cross,'replicate'),undef,'cross-field pooled child has no single plot occurrence');

    }
    1;
   };my $error=$@;$s->txn_rollback;
   ok($ok,'actual native generation/storage scenario completed and rolled back') or diag($error);
  };
 }
 1;
};
my $error=$@;$s->txn_rollback;$tx=0;
ok($ran,'all native generator fixtures rolled back') or diag($error);
done_testing;
