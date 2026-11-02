use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Stock::Accession;
use CXGN::Stock::RelatedStocks;
use CXGN::Pedigree::AddPedigrees;
use CXGN::Pedigree::AddProgeniesExistingAccessions;

my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
my $seed = $schema->resultset('Stock::Stock')->find({ uniquename => 'test_accession1' });
my %types = map { $_ => SGN::Model::Cvterm->get_cvterm_row($schema, $_.'_parent', 'stock_relationship')->cvterm_id } qw(female male);
my @created;
sub stock {
    my ($name, $type) = @_;
    my $type_id = SGN::Model::Cvterm->get_cvterm_row($schema, $type || 'accession', 'stock_type')->cvterm_id;
    my $row = $schema->resultset('Stock::Stock')->create({
        name => 'parentage_'.$name, uniquename => 'parentage_'.$name,
        type_id => $type_id, organism_id => $seed->organism_id,
    });
    push @created, $row;
    return CXGN::Stock->new(schema => $schema, stock_id => $row->stock_id);
}
sub relationships {
    my ($child) = @_;
    return $schema->resultset('Stock::StockRelationship')->search({
        object_id => $child->stock_id, type_id => { -in => [values %types] },
    }, { order_by => 'type_id' });
}
sub snapshot {
    my ($child) = @_;
    return [map { [$_->type_id, $_->subject_id, $_->value] } relationships($child)->all];
}
sub raw_parent {
    my ($child, $parent, $role, $value) = @_;
    return $schema->resultset('Stock::StockRelationship')->create({
        object_id => $child->stock_id, subject_id => $parent->stock_id,
        type_id => $types{$role}, value => $value,
    });
}
my $mother = stock('mother');
my $father = stock('father');
my $child = stock('child');

subtest 'one pedigree type on the maternal relationship and all readers' => sub {
    is($mother->add_parent('test_accession1', 'female', 'open'), undef, 'mother has a different breeding history');
    is($child->add_parents($mother->uniquename, $father->uniquename, 'biparental'), undef, 'save both parents');
    is(relationships($child)->search({type_id => $types{female}})->first->value, 'biparental', 'maternal value is the child type');
    is(relationships($child)->search({type_id => $types{male}})->first->value, undef, 'paternal value is SQL NULL');
    is($child->get_parents->{cross_type}, 'biparental', 'get_parents reads the child, not its mother');
    for my $parent ($mother, $father) {
        my $progenies = CXGN::Stock::RelatedStocks->new(dbic_schema => $schema, stock_id => $parent->stock_id)->get_progenies;
        my ($row) = grep { $_->[1] == $child->stock_id } @$progenies;
        is($row->[3], 'biparental', 'both parental views read the same child type');
    }
    my $rows = $child->get_pedigree_rows([$child->stock_id], 'parents_only', 'ancestors');
    like($rows->[0], qr/\tbiparental\n$/, 'pedigree download retains the stored type');
    my $before = snapshot($child);
    is($child->add_parents($mother->uniquename, $father->uniquename, 'biparental'), undef, 'repeat request succeeds');
    is_deeply(snapshot($child), $before, 'repeat request stores no duplicate');
    like($child->add_parents($father->uniquename, $mother->uniquename, 'biparental'), qr/cannot be replaced/, 'parent replacement is explicit');
    like($child->add_parents($mother->uniquename, $father->uniquename, 'self'), qr/cross type cannot be replaced/, 'known type is read-only');
    is_deeply(snapshot($child), $before, 'rejected changes preserve the pedigree');
};

subtest 'new pedigree requirements and cycle prevention' => sub {
    my $new = stock('validation');
    like($new->add_parents('', '', 'open'), qr/female parent is required/, 'female required');
    like($new->add_parents($mother->uniquename, '', ''), qr/cross type is required/, 'type must be selected');
    like($new->add_parents($mother->uniquename, '', 'biparental'), qr/male parent is required/, 'biparental requires father');
    like($new->add_parents($mother->uniquename, 'missing_parentage_parent', 'biparental'), qr/not found/, 'unknown second parent rejected');
    like($new->add_parents($mother->uniquename, $father->uniquename, 'multicross'), qr/Unsupported cross type/, 'multi-combination generator is not a single pedigree');
    like($new->add_parents($mother->uniquename, $father->uniquename, 'self'), qr/same parent/, 'self does not accept different parents');
    like($new->add_parents($mother->uniquename, $mother->uniquename, 'biparental'), qr/cannot be the same/, 'biparental needs different parents');
    is(relationships($new)->count, 0, 'all validation errors leave no half pedigree');
    like($new->add_parents($new->uniquename, $new->uniquename, 'self'), qr/own ancestor/, 'stock cannot parent itself');
    like($mother->add_parent($child->uniquename, 'male', ''), qr/own ancestor/, 'cycle through the opposite role is rejected');
    like($new->add_parent($mother->uniquename, 'invalid_role', 'open'), qr/female or male/, 'legacy role validation');
    like($new->add_parent($mother->uniquename, 'female', 'invented_type'), qr/Unsupported cross type/, 'legacy caller cannot introduce an invented type');
    my $derived = stock('legacy_derived');
    is($derived->add_parent($mother->uniquename, 'female', 'derived'), undef, 'legacy caller retains the standard derived type');
    for my $value (undef, '', 'null') {
        my $unknown = stock('legacy_unknown_'.scalar(@created));
        is($unknown->add_parent($mother->uniquename, 'female', $value), undef, 'legacy empty type is accepted');
        is(relationships($unknown)->first->value, undef, 'legacy empty type is stored as SQL NULL');
    }
    for my $type (qw(open self sib backcross reselected doubled_haploid dihaploid_induction polycross)) {
        my $c = stock('type_'.$type);
        my $male = $type eq 'open' ? '' : $type eq 'self' ? $mother->uniquename : $father->uniquename;
        is($c->add_parents($mother->uniquename, $male, $type), undef, "explicit parents accepted for $type");
    }
    my $population = stock('population', 'population');
    my $poly = stock('population_child');
    is($poly->add_parents($mother->uniquename, $population->uniquename, 'polycross'), undef, 'existing population may be the male parent');
    my $plot = stock('plot', 'plot');
    like($new->add_parents($plot->uniquename, '', 'open'), qr/unsupported stock type/, 'plot is not offered as a pedigree parent');
};

subtest 'database failure on the second insert rolls back the first' => sub {
    my $new = stock('rollback');
    my $dbh = $schema->storage->dbh;
    my $id = $new->stock_id;
    $dbh->do("CREATE FUNCTION pg_temp.parentage_reject_male() RETURNS trigger LANGUAGE plpgsql AS \$\$ BEGIN IF NEW.object_id = $id AND NEW.type_id = $types{male} THEN RAISE EXCEPTION 'test second parent failure'; END IF; RETURN NEW; END \$\$");
    $dbh->do('CREATE TRIGGER parentage_test_failure BEFORE INSERT ON stock_relationship FOR EACH ROW EXECUTE PROCEDURE pg_temp.parentage_reject_male()');
    my $error = $new->add_parents($mother->uniquename, $father->uniquename, 'biparental');
    $dbh->do('DROP TRIGGER parentage_test_failure ON stock_relationship');
    like($error, qr/No parents were changed/, 'storage error is reported');
    is(relationships($new)->count, 0, 'female insert was rolled back');
};

subtest 'completing historical pedigrees preserves recorded and missing values' => sub {
    for my $value ('derived', 'bulk', undef, '', 'null') {
        my $new = stock('legacy_'.scalar(@created));
        raw_parent($new, $mother, 'female', $value);
        is($new->add_parents($mother->uniquename, $father->uniquename, $value // ''), undef, 'add missing male without guessing a type');
        is(relationships($new)->search({type_id => $types{female}})->first->value, $value, 'original maternal value is unchanged');
        is(relationships($new)->search({type_id => $types{male}})->first->value, undef, 'new male has no duplicate type');
    }
    my $new = stock('missing_type');
    raw_parent($new, $mother, 'female', undef);
    is($new->add_parents($mother->uniquename, $father->uniquename, 'biparental'), undef, 'unknown type may be supplied explicitly');
    is(relationships($new)->search({type_id => $types{female}})->first->value, 'biparental', 'explicit type is saved');
    my $male_only = stock('male_only');
    raw_parent($male_only, $father, 'male', 'historical_value');
    is($male_only->add_parents($mother->uniquename, $father->uniquename, 'biparental'), undef, 'male-only legacy pedigree can be completed');
    is(relationships($male_only)->search({type_id => $types{male}})->first->value, 'historical_value', 'unrelated legacy male value is not migrated');
    my $duplicates = stock('duplicates');
    raw_parent($duplicates, $mother, 'female', 'open');
    raw_parent($duplicates, $father, 'female', 'open');
    my $before = snapshot($duplicates);
    like($duplicates->add_parents($mother->uniquename, '', 'open'), qr/More than one female/, 'ambiguous saved pedigree requires review');
    is_deeply(snapshot($duplicates), $before, 'ambiguous rows are preserved');
};

subtest 'BrAPI accession model uses the shared female-only writer' => sub {
    my $new = stock('brapi_model');
    my $accession = CXGN::Stock::Accession->new(schema => $schema, stock_id => $new->stock_id,
        mother_accession => $mother->uniquename, father_accession => $father->uniquename,
        main_production_site_url => 'http://localhost:3010');
    is($accession->store, $new->stock_id, 'real Accession::store succeeds');
    is(relationships($new)->search({type_id => $types{female}})->first->subject_id, $mother->stock_id, 'female relationship direction unchanged');
    is(relationships($new)->search({type_id => $types{female}})->first->value, 'biparental', 'legacy BrAPI maternal type retained');
    is(relationships($new)->search({type_id => $types{male}})->first->subject_id, $father->stock_id, 'male relationship direction unchanged');
    is(relationships($new)->search({type_id => $types{male}})->first->value, undef, 'BrAPI model does not duplicate cross type');
};

sub pedigree {
    my ($target, $female, $male, $type) = @_;
    return CXGN::Pedigree::AddPedigrees->new(schema => $schema)->generate_pedigrees([{
        'progeny name' => $target->uniquename, 'female parent accession' => $female,
        'male parent accession' => $male, type => $type,
    }])->[0];
}
subtest 'explicit upload overwrite replaces both roles and rejects malformed batches' => sub {
    my $new = stock('upload');
    $new->add_parents($mother->uniquename, $father->uniquename, 'biparental');
    my $open = pedigree($new, $mother->uniquename, '', 'open');
    my $writer = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => [$open]);
    ok(!$writer->add_pedigrees(1)->{error}, 'overwrite to mother-only open');
    is(relationships($new)->search({type_id => $types{male}})->count, 0, 'old father is removed');
    my $both = pedigree($new, $mother->uniquename, $father->uniquename, 'biparental');
    ok(!CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => [$both])->add_pedigrees(1)->{error}, 'overwrite back to two parents');
    my $before = snapshot($new);
    for my $bad (pedigree($new, 'missing_parentage_female', '', 'open'), pedigree($new, $mother->uniquename, 'missing_parentage_male', 'biparental')) {
        my $r = CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => [$bad])->add_pedigrees(1);
        ok($r->{error}, 'missing parent rejects direct store without prior validation');
        is_deeply(snapshot($new), $before, 'existing pedigree survives rejected overwrite');
    }
    my $later = stock('later');
    my $bad = pedigree($later, 'missing_parentage_female', '', 'open');
    ok(CXGN::Pedigree::AddPedigrees->new(schema => $schema, pedigrees => [$open, $bad])->add_pedigrees(1)->{error}, 'later invalid row rejects batch');
    is_deeply(snapshot($new), $before, 'earlier change in the transaction is rolled back');
};

subtest 'copying cross pedigree clears absent father and rolls back all its progenies on error' => sub {
    my $cross = stock('open_cross', 'cross');
    raw_parent($cross, $mother, 'female', 'open');
    my $new = stock('cross_progeny');
    $new->add_parents($mother->uniquename, $father->uniquename, 'biparental');
    my $copy = CXGN::Pedigree::AddProgeniesExistingAccessions->new(chado_schema => $schema,
        cross_name => $cross->uniquename, progeny_names => [$new->uniquename]);
    ok(!$copy->add_progenies_existing_accessions(1)->{error}, 'copy open cross parents');
    is(relationships($new)->search({type_id => $types{male}})->count, 0, 'copy removes previous father');
    $new->add_parents($mother->uniquename, $father->uniquename, 'open');
    my $before = snapshot($new);
    my $bad = CXGN::Pedigree::AddProgeniesExistingAccessions->new(chado_schema => $schema,
        cross_name => $cross->uniquename, progeny_names => [$new->uniquename, 'missing_parentage_progeny']);
    ok($bad->add_progenies_existing_accessions(1)->{error}, 'missing later progeny raises transaction error');
    is_deeply(snapshot($new), $before, 'earlier progeny is unchanged after rollback');
};

my @ids = map { $_->stock_id } @created;
$schema->resultset('Stock::StockRelationship')->search({ -or => [object_id => {-in => \@ids}, subject_id => {-in => \@ids}] })->delete;
$_->delete for reverse @created;
$f->clean_up_db;
done_testing;
