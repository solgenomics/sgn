#!/usr/bin/perl

use strict;
use Mail::Sendmail;

my $file = shift;
my $host = shift;

if (!$host) { die "Need file and host as arguments\n"; }
    
open(my $F, "< :encoding(UTF8)", $file) || die "Can't open file $file";

while (<$F>) {
    chomp;
    my ($first_name, $last_name, $username, $email, $password) = split /\t/;

    my $message_text = "Dear $first_name $last_name\n\nYour account on $host has been created. The username is $username and the password is $password\n\nBest regards,\n\nBreedbase";

    print STDERR "Sending message: $message_text... ";

    my %mail = ( To      => $email,
		 From    => 'production@breedbase.org',
		 Subject => "Your Breedbase Account",
                 Message => $message_text
               );

    sendmail(%mail) or die $Mail::Sendmail::error;
    print STDERR "Done!\n";
}
