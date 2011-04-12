use strict;
use warnings;
use Test::More tests => 4;

use lib 'lib';
use lib 'libext';

BEGIN {
    use_ok 'Carp';
    use_ok 'File::Spec::Functions';
    use_ok 'Net::OpenSSH';
    use_ok 'Data::Dumper';
}
