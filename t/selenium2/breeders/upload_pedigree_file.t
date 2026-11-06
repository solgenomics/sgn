use strict;
use warnings;
use lib 't/lib';
use Test::More;
use SGN::Test::WWW::WebDriver;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use File::Temp qw(tempfile);
use File::Spec;
use Digest::SHA qw(sha256_hex);
use JSON qw(encode_json);
use Time::HiRes qw(time usleep);

# Retain rejection coverage for the original invalid fixture without changing
# its stocks or file. Store a separate owned acyclic fixture for success coverage.
my $f = SGN::Test::Fixture->new;
my $schema = $f->bcs_schema;
my $seed = $schema->resultset('Stock::Stock')->find({uniquename=>'test_accession1'});
my %types = map {$_=>SGN::Model::Cvterm->get_cvterm_row($schema,$_,'stock_type')->cvterm_id} qw(accession population);
my %roles = map {$_=>SGN::Model::Cvterm->get_cvterm_row($schema,$_.'_parent','stock_relationship')->cvterm_id} qw(female male);
my $synonym = SGN::Model::Cvterm->get_cvterm_row($schema,'stock_synonym','stock_property')->cvterm_id;
my $original_path = File::Spec->catfile($f->config->{basepath}, 't', 'data', 'pedigree_upload',
    'upload_accession_selenium_test.txt');
sub original_file_hash {
    open my $fh, '<', $original_path or die "Cannot read original pedigree fixture: $!";
    my $bytes = do {local $/; <$fh>}; close $fh;
    return sha256_hex($bytes);
}
my $original_hash = original_file_hash();
my @original_ids = map {$_->stock_id} $schema->resultset('Stock::Stock')->search({
    type_id=>$types{accession}, uniquename=>{-in=>[map {'test_accession'.$_} 1..5]}})->all;
is(scalar(@original_ids), 5, 'all original shared pedigree targets are present');
sub original_pedigree_snapshot {
    return [map {[$_->stock_relationship_id,$_->object_id,$_->subject_id,$_->type_id,$_->value,$_->rank]}
        $schema->resultset('Stock::StockRelationship')->search({object_id=>{-in=>\@original_ids},
            type_id=>{-in=>[values %roles]}},{order_by=>'stock_relationship_id'})->all];
}
my $original_pedigree = original_pedigree_snapshot();
my $prefix = sprintf('pedigree_ui_%d_%d', time, $$);
my (@owned, $path, $t, $cleaned);
sub stock {
    my ($suffix,$type) = @_;
    my $name = $prefix.'_'.$suffix;
    my $row = $schema->resultset('Stock::Stock')->create({name=>$name,uniquename=>$name,
        organism_id=>$seed->organism_id,type_id=>$types{$type||'accession'}});
    push @owned,$row; return $row;
}
sub cleanup_owned {
    return if $cleaned;
    unlink $path if defined($path) && -f $path;
    my @ids = map {$_->stock_id} @owned;
    if (@ids) {
        $f->phenome_schema->resultset('StockOwner')->search({stock_id=>{-in=>\@ids}})->delete;
        $schema->resultset('Stock::StockRelationship')->search({-or=>[object_id=>{-in=>\@ids},subject_id=>{-in=>\@ids}]})->delete;
        for my $id (reverse @ids) {
            my $row = $schema->resultset('Stock::Stock')->find($id);
            $row->delete if $row;
        }
    }
    $f->clean_up_db;
    $cleaned=1;
}
sub wait_until {
    my ($check,$description) = @_;
    my $end = time+30;
    while (time < $end) {
        my $result = eval {$check->()};
        return $result if $result;
        my $alert = eval {$t->driver->get_alert_text};
        if (defined($alert) && length($alert)) {
            eval {$t->driver->accept_alert};
            die "$description failed: $alert\n";
        }
        usleep(100_000);
    }
    my $state = eval {$t->driver->execute_script(q{
        var ids=['upload_pedigrees_dialog','upload_pedigrees_validate_display',
            'upload_pedigrees_error_display','pedigrees_upload_success_dialog_message','working_modal'];
        var state={readyState:document.readyState,modals:{}};
        ids.forEach(function(id) {
            var e=document.getElementById(id);
            state.modals[id]=e ? {className:e.className,display:window.getComputedStyle(e).display,
                rects:e.getClientRects().length} : null;
        });
        return state;
    })};
    my $detail = ref($state) eq 'HASH' ? encode_json($state) : 'unavailable';
    die "Timed out waiting for $description. UI state: $detail\n";
}
sub modal_visible {
    my ($id) = @_;
    return $t->driver->execute_script("var e=document.getElementById('$id'); return !!e && !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);");
}
sub open_upload_dialog {
    my ($description) = @_;
    wait_until(sub {$t->driver->execute_script('return document.readyState === "complete";')}, 'completed page load');
    my $last_click = 0;
    wait_until(sub {
        return 1 if modal_visible('upload_pedigrees_dialog');
        # The DOM link can exist before its ready callback is bound. Retry only
        # the real idempotent open action; never change product modal state.
        if (time-$last_click >= 0.5) {
            my $link = $t->find_element('upload_pedigrees_link','id');
            my $visible = $t->driver->execute_script(
                'var e=arguments[0]; return !!(e.offsetWidth || e.offsetHeight || e.getClientRects().length);', $link);
            if ($visible) { $last_click=time; $link->click; }
        }
        return modal_visible('upload_pedigrees_dialog');
    }, $description);
    ok(modal_visible('upload_pedigrees_dialog'), $description.' opens through its real link');
}
my $error;
eval {
    my ($mother,$father) = (stock('mother'),stock('father'));
    my $population = stock('population','population');
    my @children = map {stock('child'.$_)} 1..5;
    my ($mother_alias,$father_alias) = ($prefix.'_mother_alias',$prefix.'_father_alias');
    for my $pair ([$mother,$mother_alias],[$father,$father_alias]) {
        $pair->[0]->create_related('stockprops',{type_id=>$synonym,value=>$pair->[1],rank=>0});
    }
    ok($mother->stock_id != $father->stock_id,'two biparental labels identify distinct parent records');
    my @rows = (
        [$children[0],$mother->uniquename,$father->uniquename,'biparental',$mother->stock_id,$father->stock_id],
        [$children[1],$children[0]->uniquename,'','open',$children[0]->stock_id,undef],
        [$children[2],$mother->uniquename,$population->uniquename,'open',$mother->stock_id,$population->stock_id],
        [$children[3],$mother_alias,$mother_alias,'self',$mother->stock_id,$mother->stock_id],
        [$children[4],$mother_alias,$father_alias,'biparental',$mother->stock_id,$father->stock_id],
    );
    my $directory = File::Spec->catdir($f->config->{basepath},'t','data','pedigree_upload');
    my $fh;
    ($fh,$path) = tempfile($prefix.'_XXXXXX',DIR=>$directory,SUFFIX=>'.txt',UNLINK=>0);
    chmod 0644,$path or die "Cannot make the owned input readable by Selenium: $!";
    print {$fh} "progeny name\tfemale parent accession\tmale parent accession\ttype\n";
    print {$fh} join("\t",$_->[0]->uniquename,@$_[1..3])."\n" for @rows;
    close $fh or die "Cannot finish owned pedigree upload input: $!";
    $t = SGN::Test::WWW::WebDriver->new;
    $t->while_logged_in_as('submitter',sub {
        $t->get_ok('/breeders/accessions');
        open_upload_dialog('initial upload dialog');
        my $original_input = $t->find_element_ok('pedigrees_uploaded_file','id','original pedigree input');
        $t->driver->upload_file($original_path);
        $original_input->send_keys($original_path);
        $t->find_element_ok('upload_pedigrees_dialog_submit','id','validate original invalid pedigrees')->click;
        wait_until(sub {modal_visible('upload_pedigrees_error_display') || modal_visible('upload_pedigrees_validate_display')}, 'original verification result');
        ok(modal_visible('upload_pedigrees_error_display'), 'invalid original input opens the fatal validation modal');
        my $original_error = $t->driver->execute_script("return document.querySelector('#upload_pedigrees_error_display tbody').textContent;");
        like($original_error, qr/parents cannot be the same.*biparental/is, 'fatal modal explains the same-ID biparental pair');
        ok(!modal_visible('upload_pedigrees_validate_display'), 'invalid input does not open the Store modal');
        my $store_visible = $t->driver->execute_script("var x=document.getElementById('upload_pedigrees_store'); return !!x && !!x.offsetParent;");
        ok(!$store_visible, 'Store remains hidden after fatal validation');
        is_deeply(original_pedigree_snapshot(), $original_pedigree, 'rejected original upload preserves saved parent relationships');
        is(original_file_hash(), $original_hash, 'rejected upload preserves the original file bytes');
        $t->find_element_ok('//div[@id="upload_pedigrees_error_display"]//div[@class="modal-footer"]/button[@data-dismiss="modal"]',
            'xpath', 'close the observed validation error modal')->click;
        wait_until(sub {$t->driver->execute_script("var x=document.getElementById('upload_pedigrees_error_display'); return window.getComputedStyle(x).display==='none' && !document.querySelector('.modal-backdrop');")}, 'error modal and backdrop dismissal');
        open_upload_dialog('upload dialog after rejection');
        my $input = $t->find_element_ok('pedigrees_uploaded_file','id','owned pedigree input');
        $input->clear;
        $t->driver->upload_file($path);
        $input->send_keys($path);
        $t->find_element_ok('upload_pedigrees_dialog_submit','id','validate owned acyclic pedigrees')->click;
        wait_until(sub {modal_visible('upload_pedigrees_validate_display') || modal_visible('upload_pedigrees_error_display')},'verification result');
        my $validation_error = $t->driver->execute_script("return document.querySelector('#upload_pedigrees_error_display tbody').textContent;");
        ok(modal_visible('upload_pedigrees_validate_display'),'valid input opens the Store dialog') or diag($validation_error);
        die "Owned valid pedigree input was rejected: $validation_error\n" unless modal_visible('upload_pedigrees_validate_display');
        $t->find_element_ok('upload_pedigrees_store','id','store validated pedigree batch')->click;
        wait_until(sub {modal_visible('pedigrees_upload_success_dialog_message')},'successful pedigree store');
        ok(1,'successful store is confirmed by the visible completion dialog');
        for my $row (@rows) {
            my @female = $schema->resultset('Stock::StockRelationship')->search({object_id=>$row->[0]->stock_id,type_id=>$roles{female}})->all;
            my @male = $schema->resultset('Stock::StockRelationship')->search({object_id=>$row->[0]->stock_id,type_id=>$roles{male}})->all;
            is(scalar(@female),1,$row->[0]->uniquename.' has one female link');
            if (@female==1) {
                is($female[0]->subject_id,$row->[4],'female link has the recorded parent ID');
                is($female[0]->value,$row->[3],'cross type is stored on the female link');
            }
            is(scalar(@male),defined($row->[5])?1:0,'male link cardinality matches explicit input');
            if (@male==1 && defined($row->[5])) {
                is($male[0]->subject_id,$row->[5],'male link has the recorded parent ID');
                is($male[0]->value,undef,'male link carries no duplicate cross type');
            }
        }
        is_deeply(original_pedigree_snapshot(), $original_pedigree, 'successful owned upload does not alter original pedigrees');
        is(original_file_hash(), $original_hash, 'successful owned upload does not overwrite the original file');
        $t->find_element_ok('pedigrees_upload_success_dismiss','id','dismiss confirmed success')->click;
        wait_until(sub {!modal_visible('pedigrees_upload_success_dialog_message')},'success dialog dismissal');
    });
    1;
} or $error=$@;
eval {$t->driver->quit} if $t;
$t=undef;
cleanup_owned();
is_deeply(original_pedigree_snapshot(), $original_pedigree, 'cleanup preserves original pedigree rows');
is(original_file_hash(), $original_hash, 'cleanup preserves original input file');
undef $f;
die $error if $error;
done_testing;
END {
    eval {$t->driver->quit} if $t;
    if (!$cleaned && $schema) {
        eval {cleanup_owned()};
        warn "Could not clean owned pedigree UI fixture: $@" if $@;
    }
    undef $f;
}
