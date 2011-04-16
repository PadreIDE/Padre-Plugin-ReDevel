use strict;
use warnings;
use Test::More tests => 4;

use lib 'dist/_base/lib';
use lib 'dist/_base/libcpan';

BEGIN {
    use_ok 'Data::Dumper';

    # RPC shell (App::ReDevelS server).
    # Based on
    # * SSH::RPC::Shell::PP::JSON
    # * SSH::RPC::Shell::PP::Base
    use_ok 'SSH::RPC::Shell::PP::TestCmds';

    # Base for commands.
    use_ok 'SSH::RPC::Shell::PP::Cmd::BaseJSON';
    use_ok 'SSH::RPC::Shell::PP::Cmd::Base';

    # This can't be tested without dist libraries.
    # Tested in t/dist/*.
    # use_ok 'App::ReDevelS::SSH::RPC::Shell';
}
