use strict;
use warnings;

# Testing SSH connect.
# You should have ssh keys configured. This is test without password.

use Net::OpenSSH;

my $host = $ARGV[0] || 'tapir1.ro.vutbr.cz';
my $user = $ARGV[1] || 'root';

my $ssh = Net::OpenSSH->new( $host, user => $user );
$ssh->error and die "Couldn't establish SSH connection: ". $ssh->error;

my ($out, $err) = $ssh->capture2('hostname');
$ssh->error and die "remote 'hostname' command failed: " . $ssh->error;

my $hostname = $out;
chomp($hostname);

print "got hostname '$hostname' - ";
if ( $hostname eq $host ) {
    print "OK";
} else {
    print "ERROR (expected '$host')"
}
print "\n";

undef $ssh;
