use strict;
use warnings;
use lib 't/lib';
use Test::More;
use Test::WWW::Mechanize;
use JSON;
use File::Temp qw(tempfile);
use IO::Handle;
use POSIX qw(_exit);
use Time::HiRes qw(time usleep);
use CXGN::Pedigree::Parentage;
use Bio::Chado::Schema;
use SGN::Test::Fixture;
use SGN::Model::Cvterm;
use CXGN::Stock;
use CXGN::Pedigree::AddPedigrees;
use CXGN::Pedigree::AddProgeniesExistingAccessions;
use CXGN::Pedigree::ParseUpload;

my $f = SGN::Test::Fixture->new;
my $s = $f->bcs_schema;
my $seed = $s->resultset('Stock::Stock')->find({uniquename => 'test_accession1'});
my %types = map {$_ => SGN::Model::Cvterm->get_cvterm_row($s, $_.'_parent', 'stock_relationship')->cvterm_id} qw(female male);
my (@made, %facts);
sub row {
    my ($name, $type, $full_name) = @_;
    my $t = SGN::Model::Cvterm->get_cvterm_row($s, $type || 'accession', 'stock_type')->cvterm_id;
    my $r = $s->resultset('Stock::Stock')->create({uniquename => $full_name || 'edgeaudit_'.$name,
        name => $full_name || 'edgeaudit_'.$name, type_id => $t, organism_id => $seed->organism_id});
    push @made, $r;
    return $r;
}
sub model { CXGN::Stock->new(schema => $s, stock_id => $_[0]->stock_id) }
sub snapshot {
    return [map { {role => $_->type->name, parent => $_->subject->uniquename, value => $_->value} }
        $s->resultset('Stock::StockRelationship')->search({object_id => $_[0]->stock_id, type_id => {-in => [values %types]}}, {order_by => 'stock_relationship_id'})->all];
}
my ($ma,$fa,$mb,$fb) = map {row($_)} qw(mother_a father_a mother_b father_b);
sub entry {
    my ($child,$mother,$father,$type)=@_;
    return {'progeny name'=>$child->uniquename,'female parent accession'=>$mother->uniquename,
        'male parent accession'=>$father ? $father->uniquename : '',type=>$type};
}
sub store {
    my ($rows,$overwrite)=@_;
    my $p=CXGN::Pedigree::AddPedigrees->new(schema=>$s)->generate_pedigrees($rows);
    return CXGN::Pedigree::AddPedigrees->new(schema=>$s,pedigrees=>$p)->add_pedigrees($overwrite);
}
sub http_store {
    my ($mech,$rows,$overwrite)=@_;
    $mech->post('http://localhost:3010/ajax/pedigrees/upload_store',[
        pedigree_data=>encode_json({pedigrees=>$rows}),overwrite_pedigrees=>$overwrite]);
    return eval {decode_json($mech->content)} || {http_status=>$mech->status};
}
subtest 'store endpoint independently enforces pedigree permissions' => sub {
    my $c=row('anonymous');
    my $anon=Test::WWW::Mechanize->new;
    $anon->post('http://localhost:3010/ajax/stock/add_stock_parents',[
        stock_id=>$c->stock_id,female_parent=>$ma->uniquename,male_parent=>$fa->uniquename,cross_type=>'biparental']);
    ok(decode_json($anon->content)->{error},'control: new paired action rejects anonymous writes');
    my $r=http_store($anon,[entry($c,$ma,$fa,'biparental')],'true');
    $facts{anonymous_store}={response=>$r,rows=>snapshot($c)};
    ok(!$r->{success} && scalar(@{snapshot($c)})==0,'anonymous store cannot write parental relationships');
    my $basic=Test::WWW::Mechanize->new;
    $basic->post('http://localhost:3010/brapi/v1/token',[username=>'freddy',password=>'atgc',grant_type=>'password']);
    my $login=eval {decode_json($basic->content)} || {};
    ok(grep({($_->{message}||'') eq 'Login Successfull'} @{$login->{metadata}{status}||[]}), 'basic fixture user login succeeds');
    my $d=row('basic_user');
    $r=http_store($basic,[entry($d,$ma,$fa,'biparental')],'true');
    $facts{basic_user_store}={response=>$r,rows=>snapshot($d)};
    ok(!$r->{success} && scalar(@{snapshot($d)})==0,'read-only user cannot store pedigree');
};
subtest 'false overwrite never adds competing parents' => sub {
    my $c=row('no_overwrite');
    is(model($c)->add_parents($ma->uniquename,$fa->uniquename,'biparental'),undef,'initial pair saved');
    my $before=snapshot($c);
    my $r=store([entry($c,$mb,$fb,'biparental')],0);
    $facts{add_pedigrees_no_overwrite}={result=>$r,before=>$before,after=>snapshot($c)};
    is_deeply(snapshot($c),$before,'overwrite=false preserves a saved pedigree without duplicate roles');
    my $cross=row('copy_source','cross');
    $s->resultset('Stock::StockRelationship')->create({object_id=>$cross->stock_id,subject_id=>$mb->stock_id,type_id=>$types{female},value=>'open'});
    my $target=row('copy_no_overwrite');
    model($target)->add_parents($ma->uniquename,$fa->uniquename,'biparental');
    $before=snapshot($target);
    $r=CXGN::Pedigree::AddProgeniesExistingAccessions->new(chado_schema=>$s,cross_name=>$cross->uniquename,
        progeny_names=>[$target->uniquename])->add_progenies_existing_accessions(0);
    $facts{copy_no_overwrite}={result=>$r,before=>$before,after=>snapshot($target)};
    is_deeply(snapshot($target),$before,'copy without overwrite does not append a different mother');
};
subtest 'import rejects a direct self-parent cycle' => sub {
    my $c=row('import_cycle');
    my $r=store([entry($c,$c,$c,'self')],1);
    $facts{import_cycle}={result=>$r,rows=>snapshot($c)};
    ok($r->{error} && scalar(@{snapshot($c)})==0,'import cannot make a stock its own parent');
};
subtest 'different names for one child cannot silently overwrite each other' => sub {
    my $c=row('alias_child');
    my $alias='edgeaudit_alias_for_same_child';
    my $st=SGN::Model::Cvterm->get_cvterm_row($s,'stock_synonym','stock_property')->cvterm_id;
    $s->resultset('Stock::Stockprop')->create({stock_id=>$c->stock_id,type_id=>$st,value=>$alias});
    my ($fh,$path)=tempfile(SUFFIX=>'.tsv',UNLINK=>1);
    print $fh "progeny name\tfemale parent accession\ttype\tmale parent accession\n";
    print $fh join("\t",$c->uniquename,$ma->uniquename,'biparental',$fa->uniquename)."\n";
    print $fh join("\t",$alias,$mb->uniquename,'biparental',$fb->uniquename)."\n";
    close $fh;
    my $parser=CXGN::Pedigree::ParseUpload->new(chado_schema=>$s,filename=>$path);
    $parser->load_plugin('PedigreesGeneric');
    my $parsed=$parser->parse;
    $facts{alias_duplicate}={parser_accepted=>$parsed?1:0,parser_data=>$parsed};
    ok(!$parsed || $parsed->{pedigree_check},'verification identifies duplicate effective child IDs');
    my @rows=(entry($c,$ma,$fa,'biparental'),entry($c,$mb,$fb,'biparental'));
    $rows[1]{'progeny name'}=$alias;
    my $r=store(\@rows,1);
    $facts{alias_duplicate}{store_result}=$r;
    $facts{alias_duplicate}{after}=snapshot($c);
    ok($r->{error},'store rejects two conflicting pedigrees for the same accession ID');
};
subtest 'existing parent identity survives a duplicate name in another stock type' => sub {
    my $name='edgeaudit_shared_parent_name';
    my $m=row('duplicate_mother','accession',$name);
    my $c=row('duplicate_name_child');
    model($c)->add_parents($name,'','open');
    my $other;
    my $ok=eval {$other=row('duplicate_population','population',$name);1};
    if (!$ok) { $facts{duplicate_name}={schema_rejected=>"$@"}; pass('schema globally prevents duplicate names'); return; }
    my $r=model($c)->add_parents($name,$fa->uniquename,'open');
    $facts{duplicate_name}={error=>$r,existing_parent_id=>$m->stock_id,other_stock_id=>$other->stock_id,after=>snapshot($c)};
    is($r,undef,'known read-only parent is resolved by its saved identity');
};
subtest 'concurrent edits of different children share graph validation' => sub {
    my ($a,$b,$c,$d)=map {row('cycle_'.$_)} qw(a b c d);
    model($a)->add_parents($d->uniquename,'','open');
    model($c)->add_parents($b->uniquename,'','open');
    $s->txn_begin;
    CXGN::Pedigree::Parentage->lock($s);
    my @workers;
    for my $pair ([$b,$a],[$d,$c]) {
        pipe(my $reader,my $writer) or die $!;
        my $pid=fork;
        die 'fork failed' unless defined $pid;
        if (!$pid) {
            close $reader; $writer->autoflush(1);
            my $cfg=$f->config;
            my $ws=Bio::Chado::Schema->connect('dbi:Pg:dbname='.$cfg->{dbname}.';host='.$cfg->{dbhost},$cfg->{dbuser},$cfg->{dbpass});
            my ($backend)=$ws->storage->dbh->selectrow_array('SELECT pg_backend_pid()');
            print $writer "$backend\n";
            my $error=CXGN::Stock->new(schema=>$ws,stock_id=>$pair->[0]->stock_id)->add_parents($pair->[1]->uniquename,'','open');
            $ws->storage->disconnect;
            print $writer encode_json({error=>$error})."\n";
            close $writer;
            _exit(0);
        }
        close $writer;
        push @workers,{pid=>$pid,reader=>$reader};
    }
    my @backends;
    for my $worker (@workers) {my $read=$worker->{reader};my $pid=<$read>;chomp $pid;push @backends,$pid}
    my $waiting=0;
    my $deadline=time+5;
    while(time<$deadline) {
        my ($count)=$f->dbh->selectrow_array(q{SELECT count(*) FROM pg_stat_activity WHERE pid IN (?,?) AND wait_event_type='Lock'},undef,@backends);
        if ($count==2) {$waiting=1;last}
        usleep(50000);
    }
    ok($waiting,'both separate-child writers wait for the common graph guard');
    $s->txn_commit;
    my @outcomes;
    for my $worker (@workers) {
        my $read=$worker->{reader};my $line=<$read>;close $read;
        waitpid $worker->{pid},0;
        push @outcomes,eval {decode_json($line)}||{error=>'worker failed'};
    }
    is(scalar(grep {!$_->{error}} @outcomes),1,'one update succeeds and the cycle-closing update rejects');
    my ($rejected)=grep {$_->{error}} @outcomes;
    like($rejected->{error},qr/own ancestor/,'rejected update reports a cycle rather than a deadlock');
    my $cycle=model($a)->_parent_would_create_cycle($d->stock_id,\%types);
    $facts{concurrent_cycle}={outcomes=>\@outcomes,cycle_present=>$cycle?1:0};
    ok(!$cycle,'committed concurrent parent additions leave the pedigree acyclic');
};

if ($ENV{PARENTAGE_EDGE_REPORT}) {
    open my $out,'>',$ENV{PARENTAGE_EDGE_REPORT} or die $!;
    print $out JSON->new->canonical->pretty->encode(\%facts);
    close $out;
}
my @ids=map {$_->stock_id} @made;
$s->resultset('Stock::StockRelationship')->search({-or=>[object_id=>{-in=>\@ids},subject_id=>{-in=>\@ids}]})->delete;
$_->delete for reverse @made;
$f->clean_up_db;
done_testing;
