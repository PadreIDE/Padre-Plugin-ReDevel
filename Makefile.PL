use strict;
use inc::Module::Install;


name           'Padre-Plugin-ReDevel';
license        'perl';
author         'Michal Jurosz <mj@mj41.cz>';
all_from       'lib/Padre/Plugin/ReDevel.pm';

requires       'Padre'                           => '0.85';
requires       'Net::OpenSSH'                    => '0.49';

test_requires  'Test::More'              => '0.47';

no_index       'directory'               => qw{ t };

homepage       'http://padre.perlide.org/';
bugtracker     'http://padre.perlide.org/';
repository     'git://github.com/mj41/Padre-Plugin-ReDevel.git';

is_padre_plugin; # authors: Install Module::Install::PadrePlugin

WriteAll;
