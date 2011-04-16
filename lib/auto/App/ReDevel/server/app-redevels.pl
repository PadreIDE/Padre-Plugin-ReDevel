package main;

use strict;
use FindBin qw($RealBin);

use lib "$RealBin/libcpan";
use lib "$RealBin/lib";
use lib "$RealBin/libdist";

use App::ReDevelS::SSH::RPC::Shell;


my $ver = $ARGV[0] || 2;

my $server = App::ReDevelS::SSH::RPC::Shell->new( $ver );
$server->run();
