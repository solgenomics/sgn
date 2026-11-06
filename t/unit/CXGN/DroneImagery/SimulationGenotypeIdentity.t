use strict;
use warnings;
use Test::More;
use File::Temp qw(tempfile);
use Text::CSV;
use CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation;

sub boundary_error {
    my ($plots)=@_;
    # Actual public positional interface: engine7, physical plot metadata30.
    # No model/schema/output arguments are supplied: the identity boundary
    # must reject ambiguous known IDs before any model work is attempted.
    my @args=(undef)x79;
    $args[7]='sommer_grm_spatial_genetic_blups';
    $args[30]=$plots;
    eval {CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::perform_drone_imagery_analytics(@args)};
    return "$@";
}

like(boundary_error({P1=>{germplasm_stock_id=>101,germplasm_name=>'Shared'},P2=>{germplasm_stock_id=>102,germplasm_name=>'Shared'}}),
    qr/name maps to multiple known germplasm IDs/,'actual Simulation refuses two known identities that its name-keyed output would merge');
like(boundary_error({P1=>{germplasm_stock_id=>101,germplasm_name=>'Old'},P2=>{germplasm_stock_id=>101,germplasm_name=>'New'}}),
    qr/ID maps to multiple genotype names/,'actual Simulation refuses inconsistent names for one known identity');
like(boundary_error({P1=>{germplasm_stock_id=>101,germplasm_name=>'0'},P2=>{germplasm_stock_id=>102,germplasm_name=>'0'}}),
    qr/name maps to multiple known germplasm IDs/,'literal name zero remains a real known identity label');
like(boundary_error({P1=>{germplasm_stock_id=>101,germplasm_name=>'Shared'},P2=>{germplasm_stock_id=>101,germplasm_name=>'Shared'}}),
    qr/Select one field trial/,'repeated observations of the same known identity pass the name boundary and reach the next actual prerequisite');
like(boundary_error({P1=>{germplasm_name=>'Shared'},P2=>{germplasm_name=>'Shared'}}),
    qr/Select one field trial/,'legacy unknown-ID rows do not manufacture a known-identity conflict');

my ($out,$path)=tempfile(UNLINK=>1);
CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::_write_model_csv_row($out,['P1','Shared',101]);
CXGN::DroneImagery::DroneImageryAnalyticsRunSimulation::_write_model_csv_row($out,['P2','Shared',102]);
close($out);
open(my $in,'<:encoding(UTF-8)',$path)or die$!;
my $csv=Text::CSV->new({binary=>1});
is_deeply($csv->getline($in),['P1','Shared',101],'plot-only producer retains the first physical identity without a broad name restriction');
is_deeply($csv->getline($in),['P2','Shared',102],'plot-only producer retains the other known identity separately');
close($in);
done_testing;
