use strict;
use warnings;
use Test::More tests => 4;

use lib 'lib';
use lib 'libext';

BEGIN {
    use_ok 'App::ReDevel::Base';
    use_ok 'App::ReDevel::SSHRPCClient';
    use_ok 'App::ReDevel::Util::Cmd';
    use_ok 'App::ReDevel';
}
