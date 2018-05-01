#!/usr/bin/env perl

=head1 Usage

Usage: ./run_fixture_and_db_patches.pl -u <dbuser> -p <dbpassword> -h <dbhost> -d <dbname> -e <editinguser> [-s <startfrom>] [--test]

-u, --user=         database login username   
-p, --pass=         database login pasword    
-h, --host=         database host
-d, --db=           database name
-e, --editinguser=  user to write as patch executor
-s, --startfrom=0   start patches from folder # (Default: 0)
-t, --test          Do not make permanent changes.      

e.g. `./run_fixture_and_db_patches.pl -u postgres --p postgres -h localhost -d fixture -e janedoe -s 00085 -t`

=cut

use strict;
use warnings;

use Getopt::Long;
use Data::Dumper;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $dbuser;
my $dbpass;
my $host;
my $dbport = "5432";
my $db;
my $editinguser;
my $startfrom = 0;
my $test;

GetOptions(
    "user=s" => \$dbuser,
    "pass=s" => \$dbpass,
    "host=s" => \$host,
    "Port=s" => \$dbport,
    "db=s" => \$db,
    "editinguser=s" => \$editinguser,
    "startfrom:i" => \$startfrom,
    "test" => \$test
);

my $fxtr_patch_path = dirname(abs_path($0));
chdir($fxtr_patch_path);
my $db_patch_path = abs_path('../../../../db/');
print STDERR "\nDIR: ".$db_patch_path."\n";

my $cmd = "echo -ne \"$dbpass\n\" | psql --port $dbport -h $host -U $dbuser -t -c \"select patch_name from Metadata.md_dbversion\" -d $db";
my @installed = grep { !/^$/ } map { s/^\s+|\s+$//gr } `$cmd`;

chdir($db_patch_path);
my @dbfolders = grep /[0-9]{5}/, (split "\n", `ls -d */`);
chdir($fxtr_patch_path);
my @fxtrfolders = grep /[0-9]{5}/, (split "\n", `ls -d */`);

my $dbindex = 0;

# run each fixture patch
for (my $i = 0; $i < (scalar @fxtrfolders); $i++) {
    if (($fxtrfolders[$i]=~s/\/$//r)>=$startfrom){
        # run any db patches which come before the number of the fixture patch folder
        while ($dbindex < (scalar @dbfolders)
                && ($dbfolders[$dbindex]=~s/\/$//r) <= ($fxtrfolders[$i]=~s/\/$//r)){
            if (($dbfolders[$dbindex]=~s/\/$//r)>=$startfrom){
                chdir($db_patch_path);
                chdir($dbfolders[$dbindex]);
                run_patches();
            }
            $dbindex += 1;
        }
        #run patches in each sub-folder within the fixture patch folder
        chdir($fxtr_patch_path);
        chdir($fxtrfolders[$i]);
        my @sub_folders = grep /[0-9]{5}/, (split "\n", `ls -d */`);
        for (my $j = 0; $j < (scalar @sub_folders); $j++) {
            chdir($fxtr_patch_path);
            chdir($fxtrfolders[$i]);
            chdir($sub_folders[$j]);
            run_patches();
        }
    }
}

#run any remaining db patches
for (my $i = $dbindex; $i < (scalar @dbfolders); $i++) {
    chdir($db_patch_path);
    chdir($dbfolders[$i]);
    run_patches();
}

sub run_patches {
    my @patches = grep {!($_ ~~ @installed)} map { s/.pm//r } (split "\n", `ls`);
    for (my $j = 0; $j < (scalar @patches); $j++) {
        my $patch = $patches[$j];
        my $cmd = "echo -ne \"$dbuser\\n$dbpass\" | mx-run $patch -p $dbport -H $host -D $db -u $editinguser".($test?' -t':'');
        print STDERR $cmd."\n";
        system("bash -c '$cmd'");
        print STDERR "\n\n\n";
    }
}
