use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Trial::AccessionChange;
use CXGN::BrAPI::DataAuthorization;
use JSON;
my $f=SGN::Test::Fixture->new;
my $schema=$f->bcs_schema;
$schema->storage->auto_savepoint(1);
my $trial=$schema->resultset('Project::Project')->find({name=>'test_trial'})->project_id;
my $plot=$schema->resultset('Stock::Stock')->find({uniquename=>'test_trial210'})->stock_id;
my $plotof=SGN::Model::Cvterm->get_cvterm_row($schema,'plot_of','stock_relationship')->cvterm_id;
my $original_acc=$schema->resultset('Stock::StockRelationship')->find({subject_id=>$plot,type_id=>$plotof})->object_id;
sub prop {
 my($name,$value)=@_;
 my $rs=$schema->resultset('Stock::Stockprop')->search({stock_id=>$plot,type_id=>SGN::Model::Cvterm->get_cvterm_row($schema,$name,'stock_property')->cvterm_id});
 if(@_>1){$rs->delete; $rs->create({stock_id=>$plot,type_id=>SGN::Model::Cvterm->get_cvterm_row($schema,$name,'stock_property')->cvterm_id,value=>$value,rank=>0}) if defined $value;}
 my $row=$rs->first; return $row?$row->value:undef;
}
sub ac { CXGN::Trial::AccessionChange->new({schema=>$schema,trial_id=>$trial}) }
sub scenario {
 my($name,$code)=@_;
 subtest $name=>sub {
  $schema->txn_begin;
  my $ok=eval {$code->();1}; my $err=$@;
  $schema->txn_rollback;
  ok($ok,'scenario completed and rolled back') or diag($err);
 };
}
scenario 'A preview must notice a plot label edited by another operator'=>sub {
 my $changes=[{plot_id=>$plot,new_stock_id=>$original_acc,new_plot_name=>'audit_reviewed_plot_label'}];
 my $svc=ac(); my $options={rename_plots=>'none'};
 my $before=$svc->plan($changes,$options);
 is_deeply($before->{errors},[],'initial preview valid');
 my $digest=$svc->plan_digest($before);
 $schema->resultset('Stock::Stock')->find({stock_id=>$plot})->update({name=>'audit_other_operator_label',uniquename=>'audit_other_operator_label'});
 isnt($svc->plan_digest($svc->plan($changes,$options)),$digest,'preview digest changes with the old plot label'); # codespell:ignore isnt
 my $ok=eval {$svc->apply($changes,{%$options,plan_digest=>$digest});1};
 ok(!$ok,'stale preview refused');
 is($schema->resultset('Stock::Stock')->find({stock_id=>$plot})->uniquename,'audit_other_operator_label','other operator label retained');
};
scenario 'Two active accessions sharing a name must require an explicit identity'=>sub {
 my $template=$schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
 my $org=$schema->resultset('Organism::Organism')->create({genus=>'Audit',species=>'identity_20261102',abbreviation=>'AUD'});
 my @stocks=map {$schema->resultset('Stock::Stock')->create({name=>'audit_duplicate_name',uniquename=>'audit_duplicate_name',type_id=>$template->type_id,organism_id=>$_})} ($template->organism_id,$org->organism_id);
 my $plan=ac()->plan([{plot_id=>$plot,new_stock_name=>'audit_duplicate_name'}],{rename_plots=>'none'});
 ok(@{$plan->{errors}}>0,'ambiguous name refused instead of choosing the lowest stock ID');
 diag('Chosen stock ID: '.($plan->{changes}->[0]->{new_stock_id}//'<none>').'; candidate IDs: '.join(',',map {$_->stock_id} @stocks));
};
scenario 'Writes use actual program membership, not a submitted study name'=>sub {
 my $people=$schema->storage->dbh;
 my($curator)=$people->selectrow_array("SELECT sp_person_id FROM sgn_people.sp_person WHERE username='janedoe'");
 my($submitter)=$people->selectrow_array("SELECT sp_person_id FROM sgn_people.sp_person WHERE username='johndoe'");
 my($ordinary)=$people->selectrow_array("SELECT sp_person_id FROM sgn_people.sp_person WHERE username='freddy'");
 is(CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$curator,[$plot]),undef,'curator may write valid unit');
 is(CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$submitter,[$plot]),undef,'submitter of actual program may write');
 is(CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$ordinary,[$plot])->{code},403,'ordinary user refused');
 my $programs=CXGN::BreedersToolbox::Projects->new({schema=>$schema})->get_breeding_programs_by_trial($trial);
 my($role)=$people->selectrow_array('SELECT sp_role_id FROM sgn_people.sp_roles WHERE name=?',undef,$programs->[0][1]);
 $people->do('DELETE FROM sgn_people.sp_person_roles WHERE sp_person_id=? AND sp_role_id=?',undef,$submitter,$role);
 is(CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$submitter,[$plot])->{code},403,'generic submitter role alone cannot write another program');
 is(CXGN::BrAPI::DataAuthorization::observation_units_error($schema,$curator,[2147483000])->{code},404,'unknown unit is controlled not-found');
};
done_testing;
