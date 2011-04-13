use strict;
use warnings;

use Test::More tests => 2;

use lib 'lib';

BEGIN {
    use_ok('Padre::Plugin::ReDevel');
    use_ok('Padre::Plugin::ReDevel::SSH');
}
