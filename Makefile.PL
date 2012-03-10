use strict;
use warnings;
use inc::Module::Install;

name           'Padre-Plugin-ReDevel';
license        'perl';
author         'Michal Jurosz <mj@mj41.cz>';

all_from       'lib/Padre/Plugin/ReDevel.pm';

requires       'Padre'                           => '0.91';
requires       'Net::OpenSSH'                    => '0.55';

test_requires 'Test::More' => '0.47';
tests 't/*.t t/*/*.t';

no_index 'directory'       => qw{ t docs temp utils };

homepage       'http://padre.perlide.org/trac/wiki/PadrePluginReDevel';
bugtracker     'https://github.com/mj41/Padre-Plugin-ReDevel/issues';
repository     'git://github.com/mj41/Padre-Plugin-ReDevel.git';

install_script 'script/redevel';

WriteAll;
