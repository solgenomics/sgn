#!/usr/bin/env perl

=head1 Usage

Usage: ./run_all_patches.pl -u <dbuser> -p <dbpassword> -h <dbhost> -d <dbname> -e <editinguser> [-s <startfrom>] [--test]

-u, --user=         database login username   
-p, --pass=         database login pasword    
-h, --host=         database host
-d, --db=           database name
-e, --editinguser=  user to write as patch executor
-s, --startfrom=0   start patches from folder # (Default: 0)
-t, --test          Do not make permanent changes.      

e.g. `./run_all_patches.pl -u postgres -p postgres -h localhost -d fixture -e janedoe -s 00085 -t`

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
my $db;
my $editinguser;
my $startfrom = 0;
my $test;

GetOptions(
    "user=s"        => \$dbuser,
    "pass=s"        => \$dbpass,
    "host=s"        => \$host,
    "db=s"          => \$db,
    "editinguser=s" => \$editinguser,
    "startfrom:i"   => \$startfrom,
    "test"          => \$test
);

my $db_patch_path = dirname(abs_path($0));
chdir($db_patch_path);

my @folders = grep /[0-9]{5}/, (split "\n", `ls -d */`);
my $cmd = "PGPASSWORD=$dbpass psql -h $host -U $dbuser -t -c \"select patch_name from Metadata.md_dbversion\" -d $db";
my @installed = grep {!/^$/} map {s/^\s+|\s+$//gr} `$cmd`;

for (my $i = 0; $i < (scalar @folders); $i++) {
    if (($folders[$i] =~ s/\/$//r) >= $startfrom) {
        chdir($db_patch_path);
        chdir($folders[$i]);
        my @patches = grep {!($_ ~~ @installed)} map {s/.pm//r} (split "\n", `ls`);
        for (my $j = 0; $j < (scalar @patches); $j++) {
            my $patch = $patches[$j];

            if ($patch =~ /\~$/) {
                print STDERR "Ignoring $patch...\n";
                next;
            }

            my $cmd = "echo -ne \"$dbuser\\n$dbpass\" | mx-run $patch -H $host -D $db -u $editinguser" . ($test ? ' -t' : '');
            print STDERR $cmd . "\n";
            system("bash -c '$cmd'");

            if (($? >> 8) == 255) { #execution error
                die "Failed executing patch: $patch";
            }

            print STDERR "\n\n\n";
        }
    }
}

print STDERR "DB patching complete, database is up to date\n";
