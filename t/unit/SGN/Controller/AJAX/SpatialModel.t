use strict;
use warnings;
use utf8;
use Test::More;
use File::Path qw(make_path);
use File::Slurp qw(read_file write_file);
use Storable qw(nstore);
use File::Temp qw(tempdir);
use JSON::Any;
use SGN::Controller::AJAX::SpatialModel;

my ($rscript) = grep {-x $_} map {"$_/Rscript"} split /:/, $ENV{PATH};
plan skip_all => 'Rscript is not installed' unless $rscript;
my $prerequisites=system($rscript,'-e','quit(status=if(all(vapply(c("SpATS","spdep","dplyr"),requireNamespace,logical(1),quietly=TRUE)))0 else 1)');
plan skip_all => 'Spatial R packages are not installed' if $prerequisites;
my $base=tempdir('sgn-spatial-boundary-XXXXXX',TMPDIR=>1,CLEANUP=>1);
my @source=("colNumber\trowNumber\tobservationUnitName\tgermplasmName\treplicate\tblockNumber\tplotNumber\tYield\n");
for my $row (1..8) { for my $col (1..8) {
    my $plot=($row-1)*8+$col;
    my $genotype=(($col+3*$row)%8)+1;
    my $value=50+$genotype*1.8+$row*1.2+sin($col)*2+cos($plot*1.91)*1.5;
    push @source,join("\t",$col,$row,"P$plot","G$genotype",$row,$row,$plot,$value)."\n";
}}
{
    package SpatialBoundaryReq;
    sub param {return $_[0]->{$_[1]}}
    package SpatialBoundaryPerson;
    sub get_sp_person_id {return 41}
    sub get_first_name {return 'Test'}
    sub get_last_name {return 'Operator'}
    package SpatialBoundaryUser;
    sub get_object {return bless {},'SpatialBoundaryPerson'}
    package SpatialBoundaryCv;
    sub cvterm_id {return 777}
    package SpatialBoundaryResultset;
    sub find {return bless {},'SpatialBoundaryCv'}
    package SpatialBoundarySchema;
    sub resultset {return bless {},'SpatialBoundaryResultset'}
    package SpatialBoundaryContext;
    sub req {return $_[0]->{req}}
    sub config {return $_[0]->{config}}
    sub stash {return $_[0]->{stash}}
    sub user {return bless {},'SpatialBoundaryUser'}
    sub dbic_schema {return bless {},'SpatialBoundarySchema'}
    package SpatialBoundaryRunner;
    sub run_cluster {}
    sub alive {return 0}
}
my $controller=SGN::Controller::AJAX::SpatialModel->new;
for my $case ('ascii','spaces','unicode') {
    my $wd="$base/$case";
    make_path("$wd/context/static/documents/tempfiles/spatial_model_files");
    my $pheno="$wd/phenotype.tsv";
    my @lines=@source;
    for my $line (@lines[1..$#lines]) {
        chomp($line);
        my @fields=split /\t/,$line,-1;
        if ($case eq 'spaces') { $fields[2]='Plot '.$fields[2]; $fields[3]='Accession '.$fields[3]; }
        if ($case eq 'unicode') { $fields[2]='Ділянка '.$fields[2]; $fields[3]='Зразок '.$fields[3]; }
        $line=join("\t",@fields)."\n";
    }
    my $alias=$case eq 'unicode'?'Висота_CO_343_0000001':'Yield';
    $lines[0]=~s/Yield/$alias/;
    write_file($pheno.'.clean',{binmode=>':encoding(UTF-8)'},join('',@lines));
    write_file($pheno.'.clean.spatial_correlation_summary',{binmode=>':encoding(UTF-8)'},"trait\tquality\tMoran_pvalue\tspatial_correction_needed\n$alias\tgood data\t0.01\tYES\n");
    nstore({$alias=>($case eq 'unicode'?'Висота|CO_343:0000001':'Yield|CO_343:0000001')},$pheno.'.clean.trait_hash');
    my $status=system($rscript,'R/Spatial_Correction.R',$pheno.'.clean',$pheno.'.clean.spatial_correlation_summary',1,0,.5,'trait,quality,Moran_pvalue,spatial_correction_needed');
    is($status,0,"actual SpATS entrypoint produces $case output");
    my %expected;
    my @output=read_file($pheno.'.clean.spatially_corrected',binmode=>':encoding(UTF-8)');
    shift @output;
    for my $line (@output) { chomp($line);my @f=split /\t/,$line,-1;$expected{$f[0]}=$f[9]; }
    my $ctx=bless {config=>{basepath=>"$wd/context",cluster_shared_tempdir=>$wd,backend=>'local',cluster_host=>'localhost'},stash=>{},req=>bless({pheno_filepath=>$pheno,phenotype_file=>$pheno.'.clean',include_rc_random=>1,genotype_as_random=>0,nseg_degree=>.5,dataTableData=>[['Yield','good data',.01,'YES']],headers=>[{title=>'trait'}]},'SpatialBoundaryReq')},'SpatialBoundaryContext';
    {
        no warnings 'redefine';
        local *CXGN::Tools::Run::new=sub{return bless {},'SpatialBoundaryRunner'};
        $controller->correct_spatial($ctx);
    }
    ok(!$ctx->stash->{rest}{error},"actual SpatialModel parses $case trait headers");
    if($ctx->stash->{rest}{error}) {diag($ctx->stash->{rest}{error});next;}
    my $transport=JSON::Any->decode(JSON::Any->encode($ctx->stash->{rest}));
    my $actual=JSON::Any->decode($transport->{projectprop_data});
    is_deeply([sort keys %$actual],[sort keys %expected],"actual SpatialModel parser retains all $case plot IDs for map storage");
    my $values_match=1;
    for my $plot (keys %expected) {
        $values_match=0 if !exists($actual->{$plot}) || !defined($actual->{$plot}{777}) || abs($actual->{$plot}{777}-$expected{$plot})>1e-8;
    }
    ok($values_match,"actual SpatialModel parser attaches each $case adjustment to its own plot/trait");
}
done_testing;
